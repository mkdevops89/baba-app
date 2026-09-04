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