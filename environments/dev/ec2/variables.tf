variable "aws_region" {
  description = "AWS region to launch the instance in."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like a real AWS region (e.g. us-east-1, eu-central-1)."
  }
}

variable "project_name" {
  description = "Project name used for the Project tag."
  type        = string
  default     = "smart-finance-calculator"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance."
  type        = string
  default     = "smart-finance-dev"
}
