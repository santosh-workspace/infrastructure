output "repository_name" {
  description = "Name of the ECR repository (Phase 4 image reference: <repository_url>:<tag>)."
  value       = module.ecr.repository_name
}

output "repository_arn" {
  description = "ARN of the ECR repository (feed back into Phase 2 ecr_repository_arn)."
  value       = module.ecr.repository_arn
}

output "repository_url" {
  description = "URL of the ECR repository. CI pushes here; EKS pulls from here."
  value       = module.ecr.repository_url
}

output "registry_id" {
  description = "AWS account (registry) ID owning the repository."
  value       = module.ecr.registry_id
}

output "registry_url" {
  description = "Registry base URL used for docker login."
  value       = module.ecr.registry_url
}

output "aws_region" {
  description = "Region of the repository."
  value       = module.ecr.aws_region
}

output "repository_managed_by_terraform" {
  description = "True when Terraform owns the repository; false when referencing an existing one."
  value       = module.ecr.repository_managed_by_terraform
}
