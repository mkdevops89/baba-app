output "terraform_state_bucket_name" {
  description = "Name of the Terraform remote state bucket"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform remote state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}