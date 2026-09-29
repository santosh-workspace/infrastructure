variable "aws_region" {
  description = "AWS region to deploy into (e.g. eu-central-1). Never hardcoded; passed via tfvars or env var."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real AWS region (e.g. us-east-1, eu-central-1)."
  }
}

variable "project_name" {
  description = "Project name used as a prefix for IAM names and the Project tag."
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
  description = "Extra tags merged into every taggable IAM resource."
  type        = map(string)
  default     = {}
}

variable "eks_cluster_role_name" {
  description = "Name of the EKS cluster service role. Empty = derive \"<project>-<environment>-eks-cluster-role\"."
  type        = string
  default     = ""
}

variable "eks_node_role_name" {
  description = "Name of the EKS worker-node role. Empty = derive \"<project>-<environment>-eks-node-role\"."
  type        = string
  default     = ""
}

variable "github_owner" {
  description = "GitHub organization/user owning the application repo. REQUIRED — set your real value in terraform.tfvars."
  type        = string
}

variable "github_repository" {
  description = "Application repository allowed to assume the deploy role. REQUIRED — set your real value in terraform.tfvars."
  type        = string
}

variable "github_ref" {
  description = "Git ref allowed to assume the role (matched as repo:<owner>/<repo>:ref:<ref>). Ignored when github_environment is set."
  type        = string
  default     = "refs/heads/main"
}

variable "github_environment" {
  description = "Optional GitHub environment name; when set, trust uses the environment subject (supports approval gates)."
  type        = string
  default     = ""
}

variable "github_additional_subjects" {
  description = "Extra full \"repo:<owner>/<repo>:...\" subject claims to trust."
  type        = list(string)
  default     = []
}

variable "github_actions_role_name" {
  description = "Name of the GitHub Actions deploy role. Empty = derive a default."
  type        = string
  default     = ""
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false with existing_github_oidc_provider_arn when one already exists."
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "ARN of the pre-existing GitHub OIDC provider (only when create_github_oidc_provider is false)."
  type        = string
  default     = ""
}

variable "ecr_repository_name" {
  description = "Target ECR repository name (Phase 3 will create it). Used to scope the push policy when ecr_repository_arn is empty."
  type        = string
  default     = ""
}

variable "ecr_repository_arn" {
  description = "Full ECR repository ARN (Phase 3 output). Takes precedence over ecr_repository_name. One of the two is required."
  type        = string
  default     = ""
}

variable "aws_load_balancer_controller_version" {
  description = "Pinned controller release for the official IAM policy (e.g. v3.5.0)."
  type        = string
  default     = "v3.5.0"
}

variable "load_balancer_controller_role_name" {
  description = "Name of the controller IRSA role. Empty = derive a default."
  type        = string
  default     = ""
}

variable "load_balancer_controller_namespace" {
  description = "Kubernetes namespace of the controller ServiceAccount."
  type        = string
  default     = "kube-system"
}

variable "load_balancer_controller_service_account" {
  description = "Kubernetes ServiceAccount name of the controller."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "eks_cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL (Phase 4 output). Leave empty until the cluster exists."
  type        = string
  default     = ""
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS cluster IAM OIDC provider (Phase 4 output). Leave empty until the cluster exists."
  type        = string
  default     = ""
}

variable "administrator_role_arn" {
  description = "ARN of your existing human/admin role for Phase 4 EKS access entries. Empty = skip. Never invent a value."
  type        = string
  default     = ""
}
