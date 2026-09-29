output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster service role (Phase 4: aws_eks_cluster role_arn)."
  value       = module.iam.eks_cluster_role_arn
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster service role."
  value       = module.iam.eks_cluster_role_name
}

output "eks_node_role_arn" {
  description = "ARN of the EKS worker-node role (Phase 4: node group node_role_arn)."
  value       = module.iam.eks_node_role_arn
}

output "eks_node_role_name" {
  description = "Name of the EKS worker-node role."
  value       = module.iam.eks_node_role_name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider (created or reused)."
  value       = module.iam.github_oidc_provider_arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions deploy role (role-to-assume in workflows)."
  value       = module.iam.github_actions_role_arn
}

output "github_trusted_subjects" {
  description = "OIDC subject claims trusted by the GitHub Actions role."
  value       = module.iam.github_trusted_subjects
}

output "ecr_publish_policy_arn" {
  description = "ARN of the ECR image-publishing policy."
  value       = module.iam.ecr_publish_policy_arn
}

output "ecr_repository_arn" {
  description = "ECR repository ARN the push policy is scoped to."
  value       = module.iam.ecr_repository_arn
}

output "lb_controller_policy_arn" {
  description = "ARN of the official AWS Load Balancer Controller IAM policy."
  value       = module.iam.lb_controller_policy_arn
}

output "lb_controller_policy_version" {
  description = "Pinned controller release the policy was fetched from."
  value       = module.iam.lb_controller_policy_version
}

output "lb_controller_role_arn" {
  description = "ARN of the controller IRSA role (empty until cluster OIDC inputs are set)."
  value       = module.iam.lb_controller_role_arn
}

output "lb_controller_service_account_annotation" {
  description = "Value for the controller ServiceAccount eks.amazonaws.com/role-arn annotation."
  value       = module.iam.lb_controller_service_account_annotation
}

output "administrator_role_arn" {
  description = "Echo of the admin role ARN input for Phase 4 access entries."
  value       = module.iam.administrator_role_arn
}

output "account_id" {
  description = "AWS account ID the stack is deployed into."
  value       = module.iam.account_id
}
