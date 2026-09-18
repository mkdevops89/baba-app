output "cloudtrail_name" {
  description = "Name of the account management-event CloudTrail."
  value       = aws_cloudtrail.management.name
}

output "audit_bucket_name" {
  description = "S3 bucket storing CloudTrail audit logs."
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_kms_key_arn" {
  description = "KMS key protecting the CloudTrail audit archive."
  value       = aws_kms_key.cloudtrail.arn
}