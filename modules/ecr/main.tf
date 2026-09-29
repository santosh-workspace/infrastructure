# ------------------------------------------------------------------------------
# ECR module: one private repository, lifecycle policy, optional pull-only
# cross-account repository policy. Phase 3 only — no EKS, IAM changes,
# load balancers, DNS, or monitoring resources are created here.
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# "existing" mode: read-only reference. Plan fails loudly here (not at apply)
# if the repository does not actually exist — that failure IS the existence
# check. Nothing about the repository itself is modified by the data source.
data "aws_ecr_repository" "existing" {
  count = var.repository_management_mode == "existing" ? 1 : 0
  name  = var.repository_name
}

locals {
  base_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Phase       = "phase-3-ecr"
    },
    var.common_tags
  )

  # Single set of locals regardless of mode, so lifecycle/repository-policy
  # attachments and outputs never branch.
  repository_name = var.repository_management_mode == "create" ? aws_ecr_repository.this[0].name : data.aws_ecr_repository.existing[0].name
  repository_arn  = var.repository_management_mode == "create" ? aws_ecr_repository.this[0].arn : data.aws_ecr_repository.existing[0].arn
  repository_url  = var.repository_management_mode == "create" ? aws_ecr_repository.this[0].repository_url : data.aws_ecr_repository.existing[0].repository_url
  registry_id     = var.repository_management_mode == "create" ? aws_ecr_repository.this[0].registry_id : data.aws_ecr_repository.existing[0].registry_id

  registry_url = "${local.registry_id}.dkr.ecr.${var.aws_region}.${data.aws_partition.current.dns_suffix}"

  # Lifecycle rules, in priority order (ECR evaluates lowest number first and
  # a matching rule protects the image from later rules):
  #  1. Keep the N most recent release-tagged images; expire older ones.
  #     Only tagPrefixList prefixes are ever expired by count — commit-SHA
  #     tags, "latest", and any other tags are NOT matched and are safe.
  #  2. Expire untagged images after M days. Untagged manifests are dangling
  #     layers from overwritten tags; they can never be pulled by a
  #     deployment, so deleting them cannot break running workloads.
  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the ${var.retain_release_images} most recent release images."
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = var.release_tag_prefixes
          countType     = "imageCountMoreThan"
          countNumber   = var.retain_release_images
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than ${var.expire_untagged_after_days} days."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.expire_untagged_after_days
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Cross-variable guard (variable validation blocks cannot reference siblings).
resource "terraform_data" "input_validation" {
  input = {
    cross_account = var.cross_account_access_enabled
    account_count = length(var.allowed_cross_account_ids)
  }

  lifecycle {
    precondition {
      condition     = !var.cross_account_access_enabled || length(var.allowed_cross_account_ids) > 0
      error_message = "cross_account_access_enabled is true, so allowed_cross_account_ids must list at least one 12-digit account ID."
    }
  }
}

# --- A. Repository (private; default AES-256 encryption; no custom KMS) --------

resource "aws_ecr_repository" "this" {
  count = var.repository_management_mode == "create" ? 1 : 0

  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(local.base_tags, { Name = var.repository_name })
}

# --- B. Lifecycle policy (valid ECR lifecycle JSON via jsonencode) -------------
# In "existing" mode this attaches (or replaces) the policy on the referenced
# repository — the one in-scope modification. Disable with
# lifecycle_policy_enabled = false to leave existing policies untouched.

resource "aws_ecr_lifecycle_policy" "this" {
  count = var.lifecycle_policy_enabled ? 1 : 0

  repository = local.repository_name
  policy     = local.lifecycle_policy
}

# --- C. Repository policy (same-account needs none; cross-account pull-only) ---
# Same-account GitHub pushes and EKS pulls are authorized by IAM identity
# policies (Phase 2: push policy on the GitHub role, ContainerRegistryReadOnly
# on the node role), so no repository policy is created by default and nothing
# is ever public. The optional cross-account policy grants pull-only actions
# (no Push, no admin) to the listed account roots.

resource "aws_ecr_repository_policy" "cross_account_pull" {
  count = var.cross_account_access_enabled ? 1 : 0

  repository = local.repository_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CrossAccountPullOnly"
      Effect = "Allow"
      Principal = {
        AWS = [for id in var.allowed_cross_account_ids : "arn:${data.aws_partition.current.partition}:iam::${id}:root"]
      }
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ]
    }]
  })
}

# --- D. Registry configuration: intentionally absent ---
# No aws_ecr_registry_policy, replication, or scanning-configuration resources:
# registry settings are account-wide, and changing them here could surprise
# other workloads. Revisit only with an explicit requirement.
