terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Shared remote state (S3 native locking — no DynamoDB needed).
  # NOTE: backend blocks accept NO variables; values below are static.
  # Create the bucket first (see README), then replace the placeholder.
  backend "s3" {
    bucket       = "REPLACE_WITH_STATE_BUCKET"
    key          = "dev/ec2/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# Latest Amazon Linux 2023 (x86_64, HVM, EBS) — no hardcoded AMI IDs.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# Launch into the account's default VPC — no networking resources created.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_instance" "main" {
  ami           = data.aws_ami.al2023.id
  instance_type = var.instance_type
  subnet_id     = data.aws_subnets.default.ids[0]

  # No key_name, no custom security group: the instance gets the default
  # security group (outbound open, no inbound). Add a key pair / SG only
  # when you actually need SSH access.

  tags = {
    Name = var.instance_name
  }
}
