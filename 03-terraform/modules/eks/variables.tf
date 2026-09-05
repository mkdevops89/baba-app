variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS cluster and managed node group"
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types used by the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "cluster_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS API endpoint"
  type        = list(string)

  validation {
    condition = alltrue([
      for cidr in var.cluster_public_access_cidrs :
      cidr != "0.0.0.0/0" && cidr != "::/0"
    ])

    error_message = "EKS public API access must not allow 0.0.0.0/0 or ::/0."
  }
}
