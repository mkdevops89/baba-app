variable "project_name" {
  description = "Project name used for audit resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "phase" {
  description = "Portfolio phase that owns the module resources."
  type        = string
}