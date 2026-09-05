output "vpc_id" {
  description = "ID of the Baba App development VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the Baba App development VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = module.vpc.internet_gateway_id
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = module.vpc.public_route_table_id
}

output "private_route_table_id" {
  description = "Private route table ID"
  value       = module.vpc.private_route_table_id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = module.vpc.nat_gateway_id
}

output "nat_eip" {
  description = "Elastic IP address of the NAT Gateway"
  value       = module.vpc.nat_eip
}

output "internal_app_security_group_id" {
  description = "Internal Baba App security group ID"
  value       = module.security.internal_app_security_group_id
}

output "frontend_ecr_repository_url" {
  description = "Frontend ECR repository URL"
  value       = module.ecr.frontend_repository_url
}

output "backend_ecr_repository_url" {
  description = "Backend ECR repository URL"
  value       = module.ecr.backend_repository_url
}

output "frontend_ecr_repository_arn" {
  description = "Frontend ECR repository ARN"
  value       = module.ecr.frontend_repository_arn
}

output "backend_ecr_repository_arn" {
  description = "Backend ECR repository ARN"
  value       = module.ecr.backend_repository_arn
}

output "eks_cluster_name" {
  description = "Name of the Baba App EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the Baba App EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "eks_node_group_name" {
  description = "Name of the Baba App EKS managed node group"
  value       = module.eks.node_group_name
}

# -----------------------------------------------------------------------------
# CI/CD IAM outputs
# -----------------------------------------------------------------------------

output "github_actions_cicd_role_arn" {
  description = "IAM role ARN used by GitHub Actions through OIDC."
  value       = module.cicd_iam.github_actions_role_arn
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN."
  value       = module.cicd_iam.github_oidc_provider_arn
}
