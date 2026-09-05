# -----------------------------------------------------------------------------
# Terraform Remote State Bucket
# -----------------------------------------------------------------------------
# Stores Terraform state remotely so infrastructure state is not dependent on a
# developer workstation.
#
# prevent_destroy protects this security-critical bucket from accidental
# Terraform deletion.
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Terraform State Versioning
# -----------------------------------------------------------------------------
# Versioning provides recovery capability if the Terraform state object is
# accidentally overwritten or corrupted.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# Terraform State Encryption
# -----------------------------------------------------------------------------
# Encrypts Terraform state using a dedicated customer-managed AWS KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}

# -----------------------------------------------------------------------------
# Terraform State Public Access Protection
# -----------------------------------------------------------------------------
# Prevents public ACLs and bucket policies from exposing Terraform state.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Terraform State KMS Key
# -----------------------------------------------------------------------------
# Dedicated customer-managed encryption key for the Terraform state bucket.
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Baba App Terraform state"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-terraform-state-kms"
  }
}

# Friendly alias for the Terraform state KMS key.
resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${var.project_name}-${var.environment}-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}
