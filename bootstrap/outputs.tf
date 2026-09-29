output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform remote state. Copy into backend \"s3\" blocks."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_region" {
  description = "Region of the state bucket."
  value       = var.aws_region
}
