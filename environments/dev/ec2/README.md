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
One-time setup — create the bucket, then put its name in `main.tf`:

```bash
export AWS_REGION="ap-south-1"
BUCKET="smart-finance-tfstate-<account-id>"   # globally unique; use your account ID

aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Then `terraform init` (add `-migrate-state` if a local state file exists).
Locked runs leave a `.tflock` object next to the state; a stale lock from a
killed run is released with `terraform force-unlock <LOCK_ID>`.

## Cleanup

```bash
terraform destroy -var-file=../global.tfvars
```
