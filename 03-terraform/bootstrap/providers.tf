provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "platform-engineering"
      CostCenter  = "portfolio"
      Phase       = "03"
      Repository  = "baba-app"
    }
  }
}