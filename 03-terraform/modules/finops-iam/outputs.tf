output "finops_readonly_role_arn" {
  description = "ARN of the dedicated FinOps read-only IAM role."
  value       = aws_iam_role.finops_readonly.arn
}

output "finops_readonly_policy_arn" {
  description = "ARN of the dedicated FinOps read-only IAM policy."
  value       = aws_iam_policy.finops_readonly.arn
}