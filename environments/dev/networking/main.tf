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
  #   key            = "dev/phase-1-networking/terraform.tfstate"
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
        Phase       = "phase-1-networking"
      },
      var.common_tags
    )
  }
}

module "networking" {
  source = "../../../modules/networking"

  project_name            = var.project_name
  environment             = var.environment
  vpc_cidr                = var.vpc_cidr
  availability_zone_count = var.availability_zone_count
  nat_gateway_mode        = var.nat_gateway_mode
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  common_tags             = var.common_tags
}
