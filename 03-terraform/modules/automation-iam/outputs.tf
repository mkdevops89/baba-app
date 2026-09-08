# -----------------------------------------------------------------------------
# Infrastructure automation identity outputs
# -----------------------------------------------------------------------------

output "github_actions_infrastructure_role_arn" {
  description = "ARN of the dedicated GitHub Actions infrastructure lifecycle role."
  value       = aws_iam_role.github_actions_infrastructure.arn
}

output "infrastructure_automation_policy_arn" {
  description = "ARN of the least-privilege infrastructure automation IAM policy."
  value       = aws_iam_policy.infrastructure_automation.arn
}