# -----------------------------------------------------------------------------
# GitHub Actions CI/CD identity outputs
# -----------------------------------------------------------------------------

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions through OIDC."
  value       = aws_iam_role.github_actions_cicd.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OpenID Connect provider."
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "ecr_publish_policy_arn" {
  description = "ARN of the least-privilege ECR publishing policy attached to the GitHub Actions role."
  value       = aws_iam_policy.ecr_publish.arn
}
