variable "aws_region" {
  description = "AWS region to deploy into (e.g. eu-central-1). Never hardcoded; passed via tfvars or env var."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real AWS region (e.g. us-east-1, eu-central-1)."
  }
}

variable "project_name" {
  description = "Project name used as a prefix for resource names and the Project tag."
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

variable "vpc_cidr" {
  description = "CIDR block for the dev VPC. 10.0.0.0/16 gives 65k IPs with room for EKS growth."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "vpc_cidr must be a valid CIDR with a prefix length between /16 and /24."
  }
}

variable "availability_zone_count" {
  description = "Number of AZs to span (one public + one private subnet per AZ). Minimum 2 for EKS HA."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 4 && floor(var.availability_zone_count) == var.availability_zone_count
    error_message = "availability_zone_count must be an integer between 2 and 4."
  }
}

variable "nat_gateway_mode" {
  description = "NAT strategy: \"single\" (one shared NAT GW, cheaper) or \"multi_az\" (one per AZ, more resilient). Dev default is \"single\"."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "multi_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be either \"single\" or \"multi_az\"."
  }
}

variable "public_subnet_cidrs" {
  description = "Optional explicit public subnet CIDRs. Leave empty to auto-derive /24s from vpc_cidr."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in public_subnet_cidrs must be a valid CIDR block."
  }
}

variable "private_subnet_cidrs" {
  description = "Optional explicit private subnet CIDRs. Leave empty to auto-derive /24s from vpc_cidr."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in private_subnet_cidrs must be a valid CIDR block."
  }
}

variable "common_tags" {
  description = "Extra tags merged into every taggable resource."
  type        = map(string)
  default     = {}
}
