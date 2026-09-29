variable "aws_region" {
  description = "AWS region the repository lives in. Echoed in outputs for Phase 4 wiring. Must match the provider region."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real AWS region (e.g. us-east-1, eu-central-1)."
  }
}

variable "project_name" {
  description = "Project name used for the Project tag on the repository."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 chars, lowercase alphanumeric with hyphens (e.g. smart-finance-calculator)."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod). Used for the Environment tag."
  type        = string

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
  description = "ECR repository name (e.g. smart-finance-calculator). Must match the name Phase 2 trusts in its push policy. REQUIRED: there is no safe default."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*(/[a-z0-9]+(?:[._-][a-z0-9]+)*)*$", var.repository_name))
    error_message = "repository_name must be a valid ECR name (lowercase alphanumeric with . _ - separators, slashes allowed for namespaces)."
  }
}

variable "repository_management_mode" {
  description = "How to handle the repository: \"create\" makes Terraform own it; \"existing\" only reads it via a data source (lifecycle/cross-account attachments still apply when enabled)."
  type        = string
  default     = "create"

  validation {
    condition     = contains(["create", "existing"], var.repository_management_mode)
    error_message = "repository_management_mode must be either \"create\" or \"existing\"."
  }
}

variable "image_tag_mutability" {
  description = "Tag mutability: MUTABLE (tags can be overwritten, convenient for dev \"latest\") or IMMUTABLE (a tag can never be reused, strongest for prod)."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either \"MUTABLE\" or \"IMMUTABLE\"."
  }
}

variable "scan_on_push" {
  description = "Run ECR basic image scanning on every push (currently supported repository-level setting)."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow terraform destroy to delete a repository that still contains images. Keep false (safe default) so images are never wiped by accident."
  type        = bool
  default     = false
}

variable "lifecycle_policy_enabled" {
  description = "Attach the lifecycle policy (expire untagged images, cap release-tagged images). Disable only to leave policy management fully manual."
  type        = bool
  default     = true
}

variable "retain_release_images" {
  description = "Number of most-recent images with a release tag prefix to keep. Older release-tagged images expire."
  type        = number
  default     = 10

  validation {
    condition     = var.retain_release_images >= 1 && var.retain_release_images <= 1000 && floor(var.retain_release_images) == var.retain_release_images
    error_message = "retain_release_images must be an integer between 1 and 1000."
  }
}

variable "release_tag_prefixes" {
  description = "Tag prefixes counted as release images by the retention rule (e.g. release-, v). Only these prefixes are ever expired by count; SHA and latest tags are never touched."
  type        = list(string)
  default     = ["release-"]

  validation {
    condition     = length(var.release_tag_prefixes) >= 1 && alltrue([for p in var.release_tag_prefixes : length(p) > 0])
    error_message = "release_tag_prefixes must contain at least one non-empty prefix."
  }
}

variable "expire_untagged_after_days" {
  description = "Expire untagged (dangling) images pushed more than this many days ago. These are never serving traffic."
  type        = number
  default     = 7

  validation {
    condition     = var.expire_untagged_after_days >= 1 && var.expire_untagged_after_days <= 3650 && floor(var.expire_untagged_after_days) == var.expire_untagged_after_days
    error_message = "expire_untagged_after_days must be an integer between 1 and 3650."
  }
}

variable "cross_account_access_enabled" {
  description = "Attach a repository policy granting pull-only access to other AWS accounts. Keep false for single-account dev."
  type        = bool
  default     = false
}

variable "allowed_cross_account_ids" {
  description = "AWS account IDs granted pull access when cross_account_access_enabled is true. REQUIRED in that case; ignored otherwise."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.allowed_cross_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "Every entry in allowed_cross_account_ids must be a 12-digit AWS account ID."
  }
}
