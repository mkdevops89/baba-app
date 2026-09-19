output "backend_pod_identity_role_arn" {
  description = "IAM role assumed by the Baba App backend through EKS Pod Identity."
  value       = aws_iam_role.backend.arn
}

output "backend_config_secret_arn" {
  description = "Secrets Manager secret available to the Baba App backend."
  value       = aws_secretsmanager_secret.backend_config.arn
}