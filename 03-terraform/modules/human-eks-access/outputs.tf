output "namespace_admin_role_arn" {
  description = "IAM role mapped to the Baba App namespace administrator group."
  value       = aws_iam_role.eks_namespace_admin.arn
}

output "developer_role_arn" {
  description = "IAM role mapped to the Baba App developer group."
  value       = aws_iam_role.eks_developer.arn
}

output "readonly_role_arn" {
  description = "IAM role mapped to the Baba App read-only group."
  value       = aws_iam_role.eks_readonly.arn
}