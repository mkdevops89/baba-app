# -----------------------------------------------------------------------------
# Frontend ECR Repository
# -----------------------------------------------------------------------------
# Stores Baba App frontend container images.
# Immutable tags prevent existing image tags from being overwritten.
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-${var.environment}-frontend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
  encryption_type = "KMS"
  kms_key         = aws_kms_key.ecr.arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend"
  }
}

# -----------------------------------------------------------------------------
# Backend ECR Repository
# -----------------------------------------------------------------------------
# Stores Baba App backend container images.
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-${var.environment}-backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
  encryption_type = "KMS"
  kms_key         = aws_kms_key.ecr.arn
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-backend"
  }
}

# -----------------------------------------------------------------------------
# ECR KMS Encryption
# -----------------------------------------------------------------------------
# Dedicated customer-managed KMS key shared by the frontend and backend ECR
# repositories.
resource "aws_kms_key" "ecr" {
  description             = "KMS key for Baba App ECR repositories"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr-kms"
  }
}

# Friendly alias for the ECR KMS key.
resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project_name}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# -----------------------------------------------------------------------------
# Frontend ECR Lifecycle Policy
# -----------------------------------------------------------------------------
# Keeps repository storage under control by retaining only the most recent
# 20 images.
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the most recent 20 images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Backend ECR Lifecycle Policy
# -----------------------------------------------------------------------------
# Applies the same 20-image retention strategy to backend images.
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the most recent 20 images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}