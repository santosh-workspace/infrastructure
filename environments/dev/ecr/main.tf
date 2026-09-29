terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state lives in the external Phase 0 backend (not in this repo).
  # Do NOT hardcode bucket/table names here. After Phase 0, either:
  #   1. Copy the backend block below with your real bucket/key/region, or
  #   2. Pass -backend-config="bucket=..." -backend-config="key=..." flags.
  # Default is local state so `terraform plan` works before the backend is wired.
  #
  # backend "s3" {
  #   bucket         = "REPLACE_WITH_PHASE0_STATE_BUCKET"
  #   key            = "dev/ecr/terraform.tfstate"
  #   region         = "REPLACE_WITH_AWS_REGION"
  #   encrypt        = true
  #   dynamodb_table = "REPLACE_WITH_PHASE0_LOCK_TABLE_IF_USED"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "terraform"
        Phase       = "phase-3-ecr"
      },
      var.common_tags
    )
  }
}

module "ecr" {
  source = "../../../modules/ecr"

  aws_region                   = var.aws_region
  project_name                 = var.project_name
  environment                  = var.environment
  common_tags                  = var.common_tags
  repository_name              = var.repository_name
  repository_management_mode   = var.repository_management_mode
  image_tag_mutability         = var.image_tag_mutability
  scan_on_push                 = var.scan_on_push
  force_delete                 = var.force_delete
  lifecycle_policy_enabled     = var.lifecycle_policy_enabled
  retain_release_images        = var.retain_release_images
  release_tag_prefixes         = var.release_tag_prefixes
  expire_untagged_after_days   = var.expire_untagged_after_days
  cross_account_access_enabled = var.cross_account_access_enabled
  allowed_cross_account_ids    = var.allowed_cross_account_ids
}
