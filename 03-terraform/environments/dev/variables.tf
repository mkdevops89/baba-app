variable "aws_region" {
  description = "AWS region for Baba App infrastructure"
  type        = string
  default     = "us-east-1"
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

variable "vpc_cidr" {
  description = "CIDR block for the development VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones for the development environment"
  type        = list(string)

  default = [
    "us-east-1a",
    "us-east-1b"
  ]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)

  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)

  default = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}

variable "cluster_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint"
  type        = list(string)

}

# -----------------------------------------------------------------------------
# EKS Lifecycle
# -----------------------------------------------------------------------------
# Controls whether the development EKS runtime is provisioned.
#
# This allows the environment to intentionally represent EKS as either present
# or absent without relying on targeted Terraform operations.
variable "enable_eks" {
  description = "Whether to provision the Baba App development EKS cluster and managed node group."
  type        = bool
  default     = false
}

variable "eks_cluster_admin_principal_arn" {
  description = "IAM role ARN granted administrative Kubernetes access to the development EKS cluster."
  type        = string
  default     = null
  nullable    = true
}