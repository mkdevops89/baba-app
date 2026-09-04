variable "aws_region" {
  description = "AWS region used for Baba App infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile used for Terraform authentication"
  type        = string
  default     = "baba-admin"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "baba-app"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket used for Terraform remote state"
  type        = string
}