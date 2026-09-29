# Single dev var file for every stack under environments/dev/.
# Each stack loads only this file, e.g. from environments/dev/iam/:
#   terraform plan -var-file=../global.tfvars -out=tfplan
#
# NOTE: plans print "value for undeclared variable" warnings for entries a
# stack does not declare — harmless (Terraform ignores them). Add
# -compact-warnings to silence.
#
# Tracked in git intentionally — keep SECRETS out (use env vars or a
# gitignored terraform.tfvars override for anything sensitive).

# --- Common (region, project, env, tags) ---

# Change to your region. Must match the AWS provider region you use.
aws_region = "eu-central-1"

project_name = "smart-finance-calculator"
environment  = "dev"

common_tags = {
  Owner = "platform-team"
}

# --- Networking (Phase 1) ---

vpc_cidr                = "10.0.0.0/16"
availability_zone_count = 2

# Cost-conscious dev default: one shared NAT Gateway.
# Use "multi_az" for staging/prod-like resilience testing.
nat_gateway_mode = "single"

# Leave empty to auto-derive /24 subnets from vpc_cidr:
#   public:  10.0.0.0/24, 10.0.1.0/24, ...
#   private: 10.0.10.0/24, 10.0.11.0/24, ...
# Or uncomment and set exactly availability_zone_count entries:
# public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
# private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
public_subnet_cidrs  = []
private_subnet_cidrs = []

# --- IAM (Phase 2) ---

# REQUIRED: your GitHub application repository (no safe defaults).
github_owner      = "REPLACE_WITH_GITHUB_ORG_OR_USER"
github_repository = "REPLACE_WITH_APP_REPO_NAME"

# Trust pushes from main only. Alternatives:
#   github_ref = "refs/tags/v*.*.*"          # tag-based releases
#   github_environment = "production"        # approval-gated deployments
github_ref         = "refs/heads/main"
github_environment = ""

# --- ECR push scope (Phase 3 creates the repository) ---
# Option A (recommended once Phase 3 exists): paste its output ARN.
# ecr_repository_arn = "arn:aws:ecr:eu-central-1:123456789012:repository/smart-finance-calculator"
# Option B (pre-Phase-3): name only; the ARN is constructed from it.
ecr_repository_name = "smart-finance-calculator"
ecr_repository_arn  = ""

# --- GitHub OIDC provider ---
# First run in the account: true. If the provider already exists, set false
# and paste its ARN (see iam/README "Importing existing resources").
create_github_oidc_provider       = true
existing_github_oidc_provider_arn = ""

# --- AWS Load Balancer Controller (official policy, pinned release) ---
aws_load_balancer_controller_version = "v3.5.0"

# Pre-cluster: leave both empty -> only the IAM *policy* is created.
# After Phase 4: paste the cluster outputs to create the IRSA *role*.
eks_cluster_oidc_issuer_url = ""
eks_oidc_provider_arn       = ""

# --- Human administration (Phase 4 access entries) ---
# Paste your existing SSO/admin role ARN, or leave empty.
administrator_role_arn = ""

# --- ECR (Phase 3) ---

# Must match the IAM ecr_repository_name above so the OIDC push policy lines up.
repository_name = "smart-finance-calculator"

# First run: "create". If the repo already exists, see ecr/README first —
# use "existing" to reference it read-only, or "create" + terraform import.
repository_management_mode = "create"

# Dev convenience (overwritable "latest"); use IMMUTABLE for prod.
image_tag_mutability = "MUTABLE"
scan_on_push         = true

# Keep false: destroy must refuse while images exist (prevents wipeouts).
force_delete = false

# Retention: keep 10 recent release-* images, drop dangling manifests after 7d.
lifecycle_policy_enabled   = true
retain_release_images      = 10
release_tag_prefixes       = ["release-"]
expire_untagged_after_days = 7

# Single-account dev: no repository policy, no cross-account access.
cross_account_access_enabled = false
allowed_cross_account_ids    = []
