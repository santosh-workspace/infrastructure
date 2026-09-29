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

Requirements: Terraform `>= 1.5.0`, AWS credentials
(`aws sts get-caller-identity` must succeed first), and an account default
VPC (`plan` will tell you if none exists).

## Cleanup

```bash
terraform destroy -var-file=../global.tfvars
```
