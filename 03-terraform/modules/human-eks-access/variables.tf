variable "project_name" {
  description = "Project name used for resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster receiving the human access entries."
  type        = string
}