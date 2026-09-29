variable "aws_region" {
  description = "AWS region to deploy into (e.g. eu-central-1). Never hardcoded; passed via tfvars or env var."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real AWS region (e.g. us-east-1, eu-central-1)."
  }
}

variable "project_name" {
  description = "Project name used for the Project tag."
  type        = string
  default     = "smart-finance-calculator"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 chars, lowercase alphanumeric with hyphens."
  }
}

variable "environment" {
  description = "Environment name. Fixed to dev in this stack."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "environment must be one of: dev, staging, prod, test."
  }
}

variable "common_tags" {
  description = "Extra tags merged into the repository tags."
  type        = map(string)
  default     = {}
}

variable "repository_name" {
  description = "ECR repository name. Must match Phase 2 ecr_repository_name so the push policy scope lines up. REQUIRED."
  type        = string
  default     = "smart-finance-calculator"
}

variable "repository_management_mode" {
  description = "create = Terraform owns the repository; existing = reference it read-only (see README for detection/import)."
  type        = string
  default     = "create"

  validation {
    condition     = contains(["create", "existing"], var.repository_management_mode)
    error_message = "repository_management_mode must be either \"create\" or \"existing\"."
  }
}

variable "image_tag_mutability" {
  description = "MUTABLE for dev convenience (latest can be overwritten); IMMUTABLE for prod-grade tag safety."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either \"MUTABLE\" or \"IMMUTABLE\"."
  }
}

variable "scan_on_push" {
  description = "Run ECR basic scanning on every pushed image."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow destroy of a repository that still holds images. Keep false unless you accept image loss on destroy."
  type        = bool
  default     = false
}

variable "lifecycle_policy_enabled" {
  description = "Attach the retention lifecycle policy."
  type        = bool
  default     = true
}

variable "retain_release_images" {
  description = "How many recent release-tagged images to keep."
  type        = number
  default     = 10
}

variable "release_tag_prefixes" {
  description = "Tag prefixes treated as releases by the retention rule."
  type        = list(string)
  default     = ["release-"]
}

variable "expire_untagged_after_days" {
  description = "Expire dangling untagged images after this many days."
  type        = number
  default     = 7
}

variable "cross_account_access_enabled" {
  description = "Grant pull-only repository access to other AWS accounts. Keep false for single-account dev."
  type        = bool
  default     = false
}

variable "allowed_cross_account_ids" {
  description = "Account IDs granted pull access when cross_account_access_enabled is true."
  type        = list(string)
  default     = []
}
