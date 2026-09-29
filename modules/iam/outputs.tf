output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster service role (Phase 4: role_arn of aws_eks_cluster)."
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster service role."
  value       = aws_iam_role.eks_cluster.name
}

output "eks_node_role_arn" {
  description = "ARN of the EKS worker-node role (Phase 4: node_role_arn of node groups)."
  value       = aws_iam_role.eks_node.arn
}

output "eks_node_role_name" {
  description = "Name of the EKS worker-node role."
  value       = aws_iam_role.eks_node.name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider (created or reused)."
  value       = local.github_oidc_provider_arn
}

output "github_oidc_provider_created" {
  description = "True when this stack created the OIDC provider; false when reusing a pre-existing one."
  value       = var.create_github_oidc_provider
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions deploy role (use as role-to-assume in the workflow)."
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions deploy role."
  value       = aws_iam_role.github_actions.name
}

output "github_trusted_subjects" {
  description = "OIDC subject claims trusted by the GitHub Actions role."
  value       = local.github_subjects
}

output "ecr_publish_policy_arn" {
  description = "ARN of the ECR image-publishing policy attached to the GitHub Actions role."
  value       = aws_iam_policy.github_ecr_push.arn
}

output "ecr_repository_arn" {
  description = "ECR repository ARN the push policy is scoped to (Phase 3 must create this repository)."
  value       = local.ecr_repository_arn
}

output "lb_controller_policy_arn" {
  description = "ARN of the official AWS Load Balancer Controller IAM policy (pinned version)."
  value       = aws_iam_policy.lb_controller.arn
}

output "lb_controller_policy_version" {
  description = "Pinned controller release the IAM policy was fetched from."
  value       = var.aws_load_balancer_controller_version
}

output "lb_controller_role_arn" {
  description = "ARN of the controller IRSA role, or empty string when the cluster OIDC inputs are not set yet (pre-Phase-4)."
  value       = local.lb_controller_role_enabled ? aws_iam_role.lb_controller[0].arn : ""
}

output "lb_controller_role_name" {
  description = "Name of the controller IRSA role, or empty string when not created yet."
  value       = local.lb_controller_role_enabled ? aws_iam_role.lb_controller[0].name : ""
}

output "lb_controller_service_account_annotation" {
  description = "Annotation value for the controller ServiceAccount (eks.amazonaws.com/role-arn) once the role exists."
  value       = local.lb_controller_role_enabled ? aws_iam_role.lb_controller[0].arn : ""
}

output "administrator_role_arn" {
  description = "Echo of the admin role ARN input for Phase 4 access entries (empty when not supplied)."
  value       = var.administrator_role_arn
}

output "account_id" {
  description = "AWS account ID the stack is deployed into (useful for Phase 3/4 wiring)."
  value       = data.aws_caller_identity.current.account_id
}
