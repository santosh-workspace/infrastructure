terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
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
  #   key            = "dev/iam/terraform.tfstate"
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
        Phase       = "phase-2-iam"
      },
      var.common_tags
    )
  }
}

module "iam" {
  source = "../../../modules/iam"

  aws_region                               = var.aws_region
  project_name                             = var.project_name
  environment                              = var.environment
  common_tags                              = var.common_tags
  eks_cluster_role_name                    = var.eks_cluster_role_name
  eks_node_role_name                       = var.eks_node_role_name
  github_owner                             = var.github_owner
  github_repository                        = var.github_repository
  github_ref                               = var.github_ref
  github_environment                       = var.github_environment
  github_additional_subjects               = var.github_additional_subjects
  github_actions_role_name                 = var.github_actions_role_name
  create_github_oidc_provider              = var.create_github_oidc_provider
  existing_github_oidc_provider_arn        = var.existing_github_oidc_provider_arn
  ecr_repository_name                      = var.ecr_repository_name
  ecr_repository_arn                       = var.ecr_repository_arn
  aws_load_balancer_controller_version     = var.aws_load_balancer_controller_version
  load_balancer_controller_role_name       = var.load_balancer_controller_role_name
  load_balancer_controller_namespace       = var.load_balancer_controller_namespace
  load_balancer_controller_service_account = var.load_balancer_controller_service_account
  eks_cluster_oidc_issuer_url              = var.eks_cluster_oidc_issuer_url
  eks_oidc_provider_arn                    = var.eks_oidc_provider_arn
  administrator_role_arn                   = var.administrator_role_arn
}
