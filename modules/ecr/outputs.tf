output "repository_name" {
  description = "Name of the ECR repository (created or referenced)."
  value       = local.repository_name
}

output "repository_arn" {
  description = "ARN of the ECR repository. Feed back into Phase 2 ecr_repository_arn for an exact push-policy scope."
  value       = local.repository_arn
}

output "repository_url" {
  description = "URL of the ECR repository (registry/repo). The CI workflow tags and pushes to this URL; Phase 4 pulls from it."
  value       = local.repository_url
}

output "registry_id" {
  description = "AWS account (registry) ID owning the repository."
  value       = local.registry_id
}

output "registry_url" {
  description = "Registry base URL used for docker login (<account>.dkr.ecr.<region>.<suffix>)."
  value       = local.registry_url
}

output "aws_region" {
  description = "Echo of the region input for Phase 4 wiring."
  value       = var.aws_region
}

output "repository_managed_by_terraform" {
  description = "True in \"create\" mode (Terraform owns the repository); false in \"existing\" mode (read-only reference)."
  value       = var.repository_management_mode == "create"
}

output "image_tag_mutability" {
  description = "Effective tag mutability of the repository (from the resource in create mode, from the data source in existing mode)."
  value       = var.repository_management_mode == "create" ? aws_ecr_repository.this[0].image_tag_mutability : data.aws_ecr_repository.existing[0].image_tag_mutability
}
