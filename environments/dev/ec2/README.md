# EC2 (dev)

Single EC2 instance (`t3.micro`, Amazon Linux 2023) in the account's default
VPC. No custom networking, IAM, or extra resources.

## Usage (run from this dir)

```bash
# edit ../global.tfvars (region, instance type/name) as needed
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
terraform output public_ip
```

Requirements: Terraform `>= 1.10.0`, AWS credentials
(`aws sts get-caller-identity` must succeed first), and an account default
VPC (`plan` will tell you if none exists).

## Remote state (required for CI)

State lives in S3 with native locking so every runner shares one state file.
The bucket is managed by the `bootstrap/` stack — run that once first:

```bash
cd ../../../bootstrap
terraform init
terraform apply   # creates infra-terraform-state-<account>-<region>
```

Then return here and `terraform init` (add `-migrate-state` if a local state
file exists).
Locked runs leave a `.tflock` object next to the state; a stale lock from a
killed run is released with `terraform force-unlock <LOCK_ID>`.

## Cleanup

```bash
terraform destroy -var-file=../global.tfvars
```
