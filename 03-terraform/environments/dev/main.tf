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
# Application Network Security
# -----------------------------------------------------------------------------
# Creates security-group controls for internal frontend and backend workloads.
module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment

  vpc_id   = module.vpc.vpc_id
  vpc_cidr = module.vpc.vpc_cidr
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
module "eks" {
  source = "../../modules/eks"

  project_name                = var.project_name
  environment                 = var.environment
  private_subnet_ids          = module.vpc.private_subnet_ids
  cluster_public_access_cidrs = var.cluster_public_access_cidrs
}

# -----------------------------------------------------------------------------
# CI/CD IAM - GitHub Actions OIDC and ECR publishing
# -----------------------------------------------------------------------------

module "cicd_iam" {
  source = "../../modules/cicd-iam"

  project_name      = var.project_name
  environment       = var.environment
  github_owner      = "mkdevops89"
  github_repository = "baba-app"

  ecr_repository_arns = [
    module.ecr.backend_repository_arn,
    module.ecr.frontend_repository_arn
  ]
}
