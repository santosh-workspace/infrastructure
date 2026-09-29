# infrastructure

Terraform infrastructure for the **Smart Finance Calculator** application.

Target architecture:

```
GitHub Actions → Amazon ECR → Amazon EKS → AWS Load Balancer → Users
```

## Layout

```text
infrastructure/
├── modules/
│   ├── networking/               # Phase 1: reusable VPC/subnet/NAT module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── versions.tf
│   └── iam/                      # Phase 2: reusable EKS/OIDC/LB-controller IAM module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── policies.tf
│       └── versions.tf
│   └── ecr/                      # Phase 3: reusable private ECR repository module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
├── environments/
│   └── dev/
│       ├── global.tfvars         # shared dev values (region, project, env, tags)
│       ├── networking/           # Phase 1: dev stack (thin wrapper over the module)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── README.md
│       ├── iam/                  # Phase 2: dev stack (thin wrapper over the module)
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── README.md
│       └── ecr/                  # Phase 3: dev stack (thin wrapper over the module)
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── README.md
├── .gitignore
└── README.md
```

## Phases

| Phase | Scope | Status |
|---|---|---|
| 0 | Remote state backend (S3 + locks) | Maintained outside this repo — stacks default to local state; wire via the commented `backend "s3"` block or `-backend-config` flags |
| **1** | **Networking: VPC, subnets, IGW, NAT, route tables (dev)** | **Implemented (`environments/dev/networking/`)** |
| **2** | **IAM: EKS roles, GitHub OIDC, LB Controller policy (dev)** | **Implemented (`environments/dev/iam/`)** |
| 3 | ECR repositories | **Implemented (`environments/dev/ecr/`)** — consumes `github_actions_role_arn`, `ecr_repository_arn` from Phase 2 |
| 4 | EKS cluster + node groups in private subnets | Planned — consumes `vpc_id`, `private_subnet_ids`, `public_subnet_ids` (Phase 1) + `eks_cluster_role_arn`, `eks_node_role_arn`, `administrator_role_arn` (Phase 2) |
| 5 | Load balancer / ingress / DNS / certs | Planned — consumes `lb_controller_policy_arn`, `lb_controller_role_arn` (Phase 2) |

Phase 1 creates **only** networking resources. See
`environments/dev/networking/README.md` for architecture, usage,
verification, cost notes, and cleanup.

Phase 2 creates **only** IAM roles, policies, and the GitHub OIDC provider.
See `environments/dev/phase-2-iam/README.md` for the permission reference,
workflow setup, import instructions, and downstream outputs.

Phase 3 creates **only** the private ECR repository, its lifecycle policy,
and an optional pull-only cross-account repository policy. See
`environments/dev/ecr/README.md` for the tag strategy, existing-repo
handling, CI push docs, and outputs for Phase 4.

## Layout convention

Every stack loads the single shared var file (run from the stack dir):

```bash
terraform plan -var-file=../global.tfvars
```

(Plans warn about values a stack doesn't declare — harmless; add
`-compact-warnings` to silence.)
`global.tfvars` is tracked dev config — keep secrets out (use env vars or a
gitignored `terraform.tfvars` override).

## Quick start (Phase 1, dev)

```bash
cd environments/dev/networking
# edit ../global.tfvars (region, VPC settings) as needed
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
```

## Quick start (Phase 2, dev)

```bash
cd environments/dev/iam
# edit ../global.tfvars: set github_owner/github_repository at minimum
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
```

## Quick start (Phase 3, dev)

```bash
cd environments/dev/ecr
# edit ../global.tfvars (region, repository_name) as needed
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
```

Requirements: Terraform `>= 1.5.0`, AWS credentials with VPC/EC2 permissions
(`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` or SSO), no hardcoded secrets
in the repo.
