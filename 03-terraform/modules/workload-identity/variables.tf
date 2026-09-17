variable "project_name" {
  description = "Project name used for workload identity resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster that owns the Pod Identity association."
  type        = string
}