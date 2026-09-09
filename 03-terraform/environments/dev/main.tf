# -----------------------------------------------------------------------------
# VPC Foundation
# -----------------------------------------------------------------------------
# Creates the networking foundation used by all Baba App development workloads.
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# -----------------------------------------------------------------------------
# Container Registries
# -----------------------------------------------------------------------------
# Creates secure ECR repositories for frontend and backend container images.
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

# -----------------------------------------------------------------------------
# Amazon EKS
# -----------------------------------------------------------------------------
# Creates the Kubernetes control plane and managed worker-node foundation.
# Worker nodes use the private subnets created by the VPC module.
#
# Public API access is restricted to explicitly approved administrator CIDRs,
# while private API access remains enabled for in-VPC communication.
# EKS is intentionally optional in development so the higher-cost runtime can
# be shut down without removing the long-lived VPC, ECR, KMS, and CI/CD
# foundation.
module "eks" {
  count = var.enable_eks ? 1 : 0

  source = "../../modules/eks"

  project_name                = var.project_name
  environment                 = var.environment
  private_subnet_ids          = module.vpc.private_subnet_ids
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
  cluster_admin_principal_arn = var.eks_cluster_admin_principal_arn
}

# -----------------------------------------------------------------------------
# CI/CD IAM - GitHub Actions OIDC and ECR publishing
# -----------------------------------------------------------------------------

module "cicd_iam" {
  source = "../../modules/cicd-iam"

  project_name         = var.project_name
  environment          = var.environment
  github_owner         = "mkdevops89"
  github_owner_id      = "251259091"
  github_repository    = "baba-app"
  github_repository_id = "1355057456"

  ecr_repository_arns = [
    module.ecr.backend_repository_arn,
    module.ecr.frontend_repository_arn
  ]
}

# -----------------------------------------------------------------------------
# Infrastructure Automation IAM
# -----------------------------------------------------------------------------
# Provides GitHub Actions with a dedicated OIDC-backed identity for controlled
# Terraform and EKS lifecycle operations.
#
# This role is intentionally separate from the CI/CD ECR publishing role so
# artifact publication does not automatically grant infrastructure privileges.
module "automation_iam" {
  source             = "../../modules/automation-iam"
  github_environment = "infrastructure-dev"

  project_name         = var.project_name
  environment          = var.environment
  github_owner         = "mkdevops89"
  github_owner_id      = "251259091"
  github_repository    = "baba-app"
  github_repository_id = "1355057456"

  github_oidc_provider_arn = module.cicd_iam.github_oidc_provider_arn

  terraform_state_bucket_arn = "arn:aws:s3:::baba-app-dev-terraform-state-406312601212"
  terraform_state_key        = "environments/dev/terraform.tfstate"

  terraform_state_kms_key_arn = "arn:aws:kms:us-east-1:406312601212:key/6ebf8690-f47b-47d9-be76-8f76a9f70bc2"
}
