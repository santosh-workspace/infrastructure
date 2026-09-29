# ------------------------------------------------------------------------------
# Customer-managed policies. The Load Balancer Controller policy is NOT
# hand-written: it is fetched verbatim from the official release artifact at
# plan/apply time, pinned to var.aws_load_balancer_controller_version.
# ------------------------------------------------------------------------------

# Official policy source (pinned):
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/<version>/docs/install/iam_policy.json
data "http" "lb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${var.aws_load_balancer_controller_version}/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }
}

# --- C. ECR image-publishing policy (GitHub Actions) ---
# Push-only. Deliberately separate from any EKS administration permissions.

resource "aws_iam_policy" "github_ecr_push" {
  name        = "${local.name_prefix}-github-ecr-push"
  description = "Allows GitHub Actions to authenticate and push images to ${local.ecr_repository_arn}. No EKS or admin rights."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthentication"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
        # Resource "*" is unavoidable here: GetAuthorizationToken is an
        # account-scoped call and supports no resource-level constraint.
      },
      {
        Sid    = "ECRImagePush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", # verify which layers already exist
          "ecr:InitiateLayerUpload",         # start a layer upload
          "ecr:UploadLayerPart",             # upload layer chunks
          "ecr:CompleteLayerUpload",         # finish layer uploads
          "ecr:PutImage"                     # push the image manifest
        ]
        Resource = local.ecr_repository_arn
      }
    ]
  })

  tags = merge(local.base_tags, { Name = "${local.name_prefix}-github-ecr-push" })
}

# --- D. AWS Load Balancer Controller policy (official, pinned) ---

resource "aws_iam_policy" "lb_controller" {
  name        = "${local.name_prefix}-aws-lb-controller"
  description = "Official AWS Load Balancer Controller policy ${var.aws_load_balancer_controller_version} (fetched verbatim from the release artifact)."

  policy = data.http.lb_controller_policy.response_body

  tags = merge(local.base_tags, { Name = "${local.name_prefix}-aws-lb-controller" })
}
