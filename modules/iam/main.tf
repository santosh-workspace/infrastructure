# ------------------------------------------------------------------------------
# IAM module: EKS service roles, GitHub OIDC deploy role, LB Controller IAM.
# Phase 2 only — no ECR repositories, EKS cluster, access entries, ALB, DNS,
# certificates, users, or access keys are created here.
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  base_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Phase       = "phase-2-iam"
    },
    var.common_tags
  )

  eks_cluster_role_name = var.eks_cluster_role_name != "" ? var.eks_cluster_role_name : "${local.name_prefix}-eks-cluster-role"
  eks_node_role_name    = var.eks_node_role_name != "" ? var.eks_node_role_name : "${local.name_prefix}-eks-node-role"
  github_role_name      = var.github_actions_role_name != "" ? var.github_actions_role_name : "${local.name_prefix}-github-actions-ecr-push"
  lb_controller_role_name = (
    var.load_balancer_controller_role_name != "" ? var.load_balancer_controller_role_name : "${local.name_prefix}-aws-lb-controller"
  )

  # --- GitHub OIDC ---
  github_oidc_issuer = "https://token.actions.githubusercontent.com"

  # Never trust every repo: exactly one primary subject (environment beats ref
  # when both are configured) plus any explicitly listed extra subjects.
  github_primary_subject = var.github_environment != "" ? (
    "repo:${var.github_owner}/${var.github_repository}:environment:${var.github_environment}"
    ) : (
    "repo:${var.github_owner}/${var.github_repository}:ref:${var.github_ref}"
  )
  github_subjects = distinct(concat([local.github_primary_subject], var.github_additional_subjects))

  github_oidc_provider_arn = var.create_github_oidc_provider ? (
    aws_iam_openid_connect_provider.github[0].arn
  ) : var.existing_github_oidc_provider_arn

  # --- ECR publish scope: explicit ARN wins; otherwise build it from the name
  # --- (a data lookup would fail because Phase 3 has not created the repo yet).
  ecr_repository_arn = var.ecr_repository_arn != "" ? var.ecr_repository_arn : (
    "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
  )

  # --- Load Balancer Controller IRSA: role exists only once the cluster's ---
  # --- OIDC provider is known (Phase 4). The policy below is always created. ---
  lb_controller_role_enabled = var.eks_cluster_oidc_issuer_url != "" && var.eks_oidc_provider_arn != ""
  # "oidc.eks.<region>.amazonaws.com/id/<ID>" — the key prefix used in :sub/:aud conditions.
  lb_controller_issuer_hostpath = replace(var.eks_cluster_oidc_issuer_url, "https://", "")
}

# Cross-variable guards (variable validation blocks cannot reference siblings).
resource "terraform_data" "input_validation" {
  input = {
    create_oidc_provider = var.create_github_oidc_provider
    has_existing_oidc    = var.existing_github_oidc_provider_arn != ""
    has_ecr_arn          = var.ecr_repository_arn != ""
    has_ecr_name         = var.ecr_repository_name != ""
    has_eks_issuer       = var.eks_cluster_oidc_issuer_url != ""
    has_eks_provider     = var.eks_oidc_provider_arn != ""
  }

  lifecycle {
    precondition {
      condition     = var.create_github_oidc_provider || var.existing_github_oidc_provider_arn != ""
      error_message = "create_github_oidc_provider is false, so existing_github_oidc_provider_arn must be set (import the existing provider instead of duplicating it)."
    }

    precondition {
      condition     = var.ecr_repository_arn != "" || var.ecr_repository_name != ""
      error_message = "Set ecr_repository_arn (Phase 3 output) or ecr_repository_name so the ECR push policy can be scoped to one repository."
    }

    precondition {
      condition     = (var.eks_cluster_oidc_issuer_url == "") == (var.eks_oidc_provider_arn == "")
      error_message = "eks_cluster_oidc_issuer_url and eks_oidc_provider_arn must be set together (both empty pre-cluster, both set from Phase 4 outputs)."
    }
  }
}

# --- A. EKS cluster service role -----------------------------------------------
# Assumed by the EKS control plane (eks.amazonaws.com) to manage ENIs,
# security groups, and CloudWatch logs on your behalf. The cluster itself is
# created in Phase 4, which references this role's ARN.

resource "aws_iam_role" "eks_cluster" {
  name        = local.eks_cluster_role_name
  description = "Service role for the ${local.name_prefix} EKS control plane (Phase 4)."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EKSControlPlaneAssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.base_tags, { Name = local.eks_cluster_role_name })
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- B. EKS worker-node role ----------------------------------------------------
# Assumed by EC2 instances (ec2.amazonaws.com) backing EKS node groups.
# Kept strictly separate from the cluster role. No administrator rights.
# The node group itself is created in Phase 4.

resource "aws_iam_role" "eks_node" {
  name        = local.eks_node_role_name
  description = "Worker-node role for the ${local.name_prefix} EKS node groups (Phase 4)."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EC2AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.base_tags, { Name = local.eks_node_role_name })
}

resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- C. GitHub Actions OIDC ------------------------------------------------------
# Short-lived tokens from GitHub's OIDC issuer, exchanged via
# sts:AssumeRoleWithWebIdentity. No users, no access keys.

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url = local.github_oidc_issuer

  client_id_list = ["sts.amazonaws.com"]

  # Well-known DigiCert root thumbprint for token.actions.githubusercontent.com,
  # retained for compatibility (AWS now chains to the public CA).
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(local.base_tags, { Name = "${local.name_prefix}-github-oidc" })
}

resource "aws_iam_role" "github_actions" {
  name        = local.github_role_name
  description = "Assumed by GitHub Actions (OIDC) to push images for ${var.github_owner}/${var.github_repository}. No EKS admin rights."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "GitHubOIDCAssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = local.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.github_subjects
        }
      }
    }]
  })

  tags = merge(local.base_tags, { Name = local.github_role_name })
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_ecr_push.arn
}

# --- D. AWS Load Balancer Controller (IRSA) ---------------------------------------
# IRSA (not EKS Pod Identity) is used: no agent to install, supported on every
# cluster version Phase 4 may create, and the Helm chart consumes the role via
# serviceAccount.annotations. The controller Deployment/Helm release and any
# Pod Identity association are Phase 4+ concerns — only IAM exists here.

resource "aws_iam_role" "lb_controller" {
  count = local.lb_controller_role_enabled ? 1 : 0

  name        = local.lb_controller_role_name
  description = "IRSA role for the AWS Load Balancer Controller ${var.aws_load_balancer_controller_version} (ServiceAccount ${var.load_balancer_controller_namespace}/${var.load_balancer_controller_service_account})."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ControllerIRSATrust"
      Effect    = "Allow"
      Principal = { Federated = var.eks_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.lb_controller_issuer_hostpath}:aud" = "sts.amazonaws.com"
          "${local.lb_controller_issuer_hostpath}:sub" = "system:serviceaccount:${var.load_balancer_controller_namespace}:${var.load_balancer_controller_service_account}"
        }
      }
    }]
  })

  tags = merge(local.base_tags, { Name = local.lb_controller_role_name })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  count = local.lb_controller_role_enabled ? 1 : 0

  role       = aws_iam_role.lb_controller[0].name
  policy_arn = aws_iam_policy.lb_controller.arn
}
