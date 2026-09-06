# -----------------------------------------------------------------------------
# GitHub repository identity
# -----------------------------------------------------------------------------

variable "github_owner" {
  description = "GitHub organization or user that owns the Baba App repository."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository name permitted to assume the CI/CD IAM role."
  type        = string
}

# -----------------------------------------------------------------------------
# AWS resource naming
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for consistent AWS resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment associated with the CI/CD role."
  type        = string
}

# -----------------------------------------------------------------------------
# Amazon ECR access
# -----------------------------------------------------------------------------

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the CI/CD role is permitted to publish images to."
  type        = list(string)
}
