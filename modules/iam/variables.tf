variable "aws_region" {
  description = "AWS region to deploy into. Used to construct the ECR repository ARN when only ecr_repository_name is given. Must match the provider region."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real AWS region (e.g. us-east-1, eu-central-1)."
  }
}

variable "project_name" {
  description = "Project name used as a prefix for IAM role/policy names and the Project tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 chars, lowercase alphanumeric with hyphens (e.g. smart-finance-calculator)."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod). Used in names and the Environment tag."
  type        = string

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

# --- EKS role names (empty = derive "<project>-<environment>-<suffix>") ----------

variable "eks_cluster_role_name" {
  description = "Name of the EKS cluster service role. Leave empty to derive \"<project>-<environment>-eks-cluster-role\"."
  type        = string
  default     = ""

  validation {
    condition     = var.eks_cluster_role_name == "" || can(regex("^[\\w+=,.@-]{1,64}$", var.eks_cluster_role_name))
    error_message = "eks_cluster_role_name must be empty or a valid IAM role name (1-64 chars: alphanumeric plus +=,.@-_)."
  }
}

variable "eks_node_role_name" {
  description = "Name of the EKS worker-node role. Leave empty to derive \"<project>-<environment>-eks-node-role\"."
  type        = string
  default     = ""

  validation {
    condition     = var.eks_node_role_name == "" || can(regex("^[\\w+=,.@-]{1,64}$", var.eks_node_role_name))
    error_message = "eks_node_role_name must be empty or a valid IAM role name (1-64 chars: alphanumeric plus +=,.@-_)."
  }
}

# --- GitHub Actions OIDC -------------------------------------------------------

variable "github_owner" {
  description = "GitHub organization or user that owns the application repository (e.g. my-org). REQUIRED: there is no safe default."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,38}$", var.github_owner))
    error_message = "github_owner must be a valid GitHub username/organization (alphanumeric and hyphens)."
  }
}

variable "github_repository" {
  description = "Application repository name that may assume the GitHub Actions role (e.g. smart-finance-calculator). REQUIRED."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{1,100}$", var.github_repository))
    error_message = "github_repository must be a valid GitHub repository name."
  }
}

variable "github_ref" {
  description = "Git ref allowed to assume the role, as matched after \"repo:<owner>/<repo>:ref:\" (e.g. refs/heads/main). Used when github_environment is empty."
  type        = string
  default     = "refs/heads/main"

  validation {
    condition     = can(regex("^refs/(heads|tags)/[A-Za-z0-9_./-]+$", var.github_ref)) || var.github_ref == "*"
    error_message = "github_ref must look like refs/heads/main, refs/tags/v1.0.0, or \"*\" (least privilege prefers an explicit ref)."
  }
}

variable "github_environment" {
  description = "Optional GitHub Environments name (e.g. production). When set, the trust policy uses subject \"repo:<owner>/<repo>:environment:<name>\" instead of the branch ref, so deployments can require manual approval."
  type        = string
  default     = ""

  validation {
    condition     = var.github_environment == "" || can(regex("^[A-Za-z0-9_.-]{1,100}$", var.github_environment))
    error_message = "github_environment must be empty or a valid GitHub environment name."
  }
}

variable "github_additional_subjects" {
  description = "Extra OIDC subject claims to trust (full \"repo:<owner>/<repo>:...\" strings), e.g. a release branch. Appended to the primary ref/environment subject."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for s in var.github_additional_subjects : startswith(s, "repo:")])
    error_message = "Every entry in github_additional_subjects must be a full subject claim starting with \"repo:\"."
  }
}

variable "github_actions_role_name" {
  description = "Name of the GitHub Actions deploy role. Leave empty to derive \"<project>-<environment>-github-actions-ecr-push\"."
  type        = string
  default     = ""

  validation {
    condition     = var.github_actions_role_name == "" || can(regex("^[\\w+=,.@-]{1,64}$", var.github_actions_role_name))
    error_message = "github_actions_role_name must be empty or a valid IAM role name."
  }
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set false (and set existing_github_oidc_provider_arn) when the account already has one — AWS allows only one provider per issuer URL per account."
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "ARN of the pre-existing GitHub OIDC provider, used when create_github_oidc_provider is false. Leave empty otherwise."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_github_oidc_provider_arn == "" || can(regex("^arn:[a-z0-9-]+:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.existing_github_oidc_provider_arn))
    error_message = "existing_github_oidc_provider_arn must be empty or a valid GitHub OIDC provider ARN (arn:<partition>:iam::<account>:oidc-provider/token.actions.githubusercontent.com)."
  }
}

# --- ECR publish scope ---------------------------------------------------------

variable "ecr_repository_name" {
  description = "Target ECR repository name (created in Phase 3). Used to build the repository ARN when ecr_repository_arn is empty."
  type        = string
  default     = ""

  validation {
    condition     = var.ecr_repository_name == "" || can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*(/[a-z0-9]+(?:[._-][a-z0-9]+)*)*$", var.ecr_repository_name))
    error_message = "ecr_repository_name must be empty or a valid ECR repository name (lowercase, slashes allowed for namespaces)."
  }
}

variable "ecr_repository_arn" {
  description = "Full ARN of the target ECR repository (Phase 3 output). Takes precedence over ecr_repository_name. At least one of the two must be set."
  type        = string
  default     = ""

  validation {
    condition     = var.ecr_repository_arn == "" || can(regex("^arn:[a-z0-9-]+:ecr:[a-z0-9-]+:[0-9]{12}:repository/.+$", var.ecr_repository_arn))
    error_message = "ecr_repository_arn must be empty or a valid ECR repository ARN."
  }
}

# --- AWS Load Balancer Controller ----------------------------------------------

variable "aws_load_balancer_controller_version" {
  description = "Pinned AWS Load Balancer Controller release whose official iam_policy.json is fetched (e.g. v3.5.0). Requires Kubernetes >= 1.22 for the v3.x line."
  type        = string
  default     = "v3.5.0"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.aws_load_balancer_controller_version))
    error_message = "aws_load_balancer_controller_version must be a pinned release tag like v3.5.0 (never a branch)."
  }
}

variable "load_balancer_controller_role_name" {
  description = "Name of the controller IRSA role. Leave empty to derive \"<project>-<environment>-aws-lb-controller\"."
  type        = string
  default     = ""

  validation {
    condition     = var.load_balancer_controller_role_name == "" || can(regex("^[\\w+=,.@-]{1,64}$", var.load_balancer_controller_role_name))
    error_message = "load_balancer_controller_role_name must be empty or a valid IAM role name."
  }
}

variable "load_balancer_controller_namespace" {
  description = "Kubernetes namespace of the controller ServiceAccount trusted by the IRSA role."
  type        = string
  default     = "kube-system"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.load_balancer_controller_namespace))
    error_message = "load_balancer_controller_namespace must be a valid Kubernetes namespace name."
  }
}

variable "load_balancer_controller_service_account" {
  description = "Kubernetes ServiceAccount name of the controller trusted by the IRSA role (must match the Helm release)."
  type        = string
  default     = "aws-load-balancer-controller"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.load_balancer_controller_service_account))
    error_message = "load_balancer_controller_service_account must be a valid Kubernetes service account name."
  }
}

variable "eks_cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL (Phase 4 cluster output, https://...). Empty until the cluster exists; the controller role is created once this and eks_oidc_provider_arn are both set."
  type        = string
  default     = ""

  validation {
    condition     = var.eks_cluster_oidc_issuer_url == "" || can(regex("^https://oidc\\.eks\\.[a-z0-9-]+\\.amazonaws\\.com/id/[A-Za-z0-9]+$", var.eks_cluster_oidc_issuer_url))
    error_message = "eks_cluster_oidc_issuer_url must be empty or an EKS OIDC issuer URL (https://oidc.eks.<region>.amazonaws.com/id/<hex>)."
  }
}

variable "eks_oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (Phase 4 output). Empty until the cluster exists."
  type        = string
  default     = ""

  validation {
    condition     = var.eks_oidc_provider_arn == "" || can(regex("^arn:[a-z0-9-]+:iam::[0-9]{12}:oidc-provider/oidc\\.eks\\.[a-z0-9-]+\\.amazonaws\\.com/id/[A-Za-z0-9]+$", var.eks_oidc_provider_arn))
    error_message = "eks_oidc_provider_arn must be empty or a valid EKS OIDC provider ARN."
  }
}

# --- Human administration ------------------------------------------------------

variable "administrator_role_arn" {
  description = "ARN of the existing human/admin role (e.g. AWS SSO AdministratorAccess role) to be granted EKS access via access entries in Phase 4. Empty means no admin binding is prepared. NEVER invent a user name here."
  type        = string
  default     = ""

  validation {
    condition     = var.administrator_role_arn == "" || can(regex("^arn:[a-z0-9-]+:iam::[0-9]{12}:role/.+$", var.administrator_role_arn))
    error_message = "administrator_role_arn must be empty or a valid IAM role ARN (roles only, not users)."
  }
}
