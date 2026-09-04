output "internal_app_security_group_id" {
  description = "ID of the internal Baba App security group"
  value       = aws_security_group.internal_app.id
}