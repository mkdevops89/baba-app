# -----------------------------------------------------------------------------
# GitHub identity
# -----------------------------------------------------------------------------

variable "github_oidc_provider_arn" {
  description = "ARN of the existing GitHub Actions OIDC provider."
  type        = string
}

variable "github_owner" {
  description = "GitHub repository owner."
  type        = string
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID used in the OIDC subject."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID used in the OIDC subject."
  type        = string
}

# -----------------------------------------------------------------------------
# Environment
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for AWS resource naming."
  type        = string
}

variable "environment" {
  description = "Environment controlled by the automation role."
  type        = string
}

variable "aws_region" {
  description = "AWS region containing the Baba App development environment."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Terraform backend
# -----------------------------------------------------------------------------

variable "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket containing the development Terraform state."
  type        = string
}

variable "terraform_state_key" {
  description = "S3 object key containing the development Terraform state."
  type        = string
}

variable "terraform_state_kms_key_arn" {
  description = "ARN of the KMS key encrypting the development Terraform state."
  type        = string
}

variable "github_environment" {
  description = "Protected GitHub Environment permitted to assume the infrastructure automation role."
  type        = string
}