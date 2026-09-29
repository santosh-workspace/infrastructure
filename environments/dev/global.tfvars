# Single dev var file for every stack under environments/dev/.
# Each stack loads only this file, e.g. from environments/dev/ec2/:
#   terraform plan -var-file=../global.tfvars -out=tfplan
#
# Tracked in git intentionally — keep SECRETS out (use env vars or a
# gitignored terraform.tfvars override for anything sensitive).

# Change to your region. Must match the AWS provider region you use.
aws_region = "eu-central-1"

project_name = "smart-finance-calculator"

# --- EC2 ---

instance_type = "t3.micro"
instance_name = "smart-finance-dev"
