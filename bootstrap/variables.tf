variable "aws_region" {
  description = "AWS region for the state bucket. Must match the region in backend \"s3\" blocks."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real AWS region (e.g. ap-south-1)."
  }
}

variable "project_name" {
  description = "Project name used for the Project tag."
  type        = string
  default     = "smart-finance-calculator"
}

variable "state_bucket_name" {
  description = "Globally-unique S3 bucket name for Terraform state. Must match the static bucket in backend \"s3\" blocks."
  type        = string
  default     = "infra-terraform-state-614020738587-ap-south-1"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid, globally-unique S3 bucket name."
  }
}
