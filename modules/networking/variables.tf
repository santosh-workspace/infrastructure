variable "project_name" {
  description = "Project name used as a prefix for resource names and the Project tag."
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a private range large enough for subnets (recommended /16 for EKS growth)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 24
    error_message = "vpc_cidr must be a valid CIDR with a prefix length between /16 and /24 (e.g. 10.0.0.0/16)."
  }
}

variable "availability_zone_count" {
  description = "Number of Availability Zones to use (one public + one private subnet per AZ). Must be >= 2 for EKS HA."
  type        = number
  default     = 2

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 4 && floor(var.availability_zone_count) == var.availability_zone_count
    error_message = "availability_zone_count must be an integer between 2 and 4."
  }
}

variable "nat_gateway_mode" {
  description = "NAT Gateway strategy: \"single\" (one shared NAT GW, cheaper) or \"multi_az\" (one NAT GW per AZ, more resilient)."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "multi_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be either \"single\" or \"multi_az\"."
  }
}

variable "public_subnet_cidrs" {
  description = "Optional explicit CIDRs for public subnets. Leave empty ([]) to derive safely from vpc_cidr. If set, length must equal availability_zone_count."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in public_subnet_cidrs must be a valid CIDR block."
  }
}

variable "private_subnet_cidrs" {
  description = "Optional explicit CIDRs for private subnets. Leave empty ([]) to derive safely from vpc_cidr. If set, length must equal availability_zone_count."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.private_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in private_subnet_cidrs must be a valid CIDR block."
  }
}

variable "common_tags" {
  description = "Extra tags merged into every taggable resource (Project/Environment/Name are added automatically)."
  type        = map(string)
  default     = {}
}
