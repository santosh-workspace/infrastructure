# infrastructure

Minimal Terraform config: a single EC2 instance (`t3.micro`, Amazon Linux 2023)
in the account's default VPC. No custom networking, IAM, or extra resources.

## Layout

```text
infrastructure/
├── environments/
│   └── dev/
│       ├── global.tfvars         # shared dev values (region, project, EC2 settings)
│       └── ec2/                  # EC2 stack (thin config: main + variables + outputs)
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── README.md
├── .gitignore
└── README.md
```

Every stack loads the single shared var file (run from the stack dir):

```bash
terraform plan -var-file=../global.tfvars
```

`global.tfvars` is tracked dev config — keep secrets out (use env vars or a
gitignored `terraform.tfvars` override).

## Quick start

```bash
cd environments/dev/ec2
# edit ../global.tfvars (region, instance type/name) as needed
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
```

## Cleanup

```bash
terraform destroy -var-file=../global.tfvars
```

Requirements: Terraform `>= 1.5.0`, AWS credentials (`aws sts get-caller-identity`
must succeed first).
