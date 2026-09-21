# -----------------------------------------------------------------------------
# AWS account audit trail
# -----------------------------------------------------------------------------
# Provides durable, encrypted management-event history for administrative and
# identity changes such as IAM role updates, EKS Access Entries, and security
# configuration changes.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  trail_name  = "${var.project_name}-${var.environment}-management-audit"
  bucket_name = "${var.project_name}-${var.environment}-cloudtrail-${data.aws_caller_identity.current.account_id}"
}

# -----------------------------------------------------------------------------
# CloudTrail KMS key
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cloudtrail_kms" {
  statement {
    sid    = "EnableAccountAdministration"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "logs.${data.aws_region.current.region}.amazonaws.com"
      ]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"

      values = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/cloudtrail/${local.trail_name}"
      ]
    }
  }

  statement {
    sid    = "AllowCloudTrailEncryption"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com"
      ]
    }

    actions = [
      "kms:GenerateDataKey*"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"

      values = [
        "arn:aws:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"
      ]
    }
  }

  statement {
    sid    = "AllowCloudTrailDescribeKey"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com"
      ]
    }

    actions = [
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }
}

resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for Baba App CloudTrail audit logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.cloudtrail_kms.json

  tags = {
    Name = "${var.project_name}-${var.environment}-cloudtrail"
  }
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/${var.project_name}-${var.environment}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

# -----------------------------------------------------------------------------
# CloudTrail S3 archive
# -----------------------------------------------------------------------------
# checkov:skip=CKV_AWS_18:Dedicated CloudTrail archive bucket; separate S3 server-access logging is deferred to centralized logging design to avoid recursive/duplicate audit logging.
# checkov:skip=CKV2_AWS_62:Event notifications are not required for the Phase 09 management-audit use case; alerting and event-driven detection will be implemented in the security-monitoring phase.
# checkov:skip=CKV_AWS_144:Cross-Region Replication is deferred to the disaster-recovery phase where the destination region, KMS key, replication role, retention, RPO, and recovery design will be implemented together.
resource "aws_s3_bucket" "cloudtrail" {
  #checkov:skip=CKV_AWS_18:Dedicated CloudTrail archive bucket; separate S3 server-access logging is deferred to centralized logging design to avoid recursive or duplicate audit logging.
  #checkov:skip=CKV2_AWS_62:Event notifications are not required for the Phase 09 management-audit use case; alerting and event-driven detection will be implemented in the security-monitoring phase.
  #checkov:skip=CKV_AWS_144:Cross-Region Replication is deferred to the disaster-recovery phase where destination region, KMS key, replication role, retention, and recovery objectives will be designed together.

  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cloudtrail.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "expire-audit-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.cloudtrail
  ]
}

# -----------------------------------------------------------------------------
# CloudTrail bucket policy
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com"
      ]
    }

    actions = [
      "s3:GetBucketAcl"
    ]

    resources = [
      aws_s3_bucket.cloudtrail.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
      ]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "cloudtrail.amazonaws.com"
      ]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"

      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"

      values = [
        "bucket-owner-full-control"
      ]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type = "*"
      identifiers = [
        "*"
      ]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.cloudtrail.arn,
      "${aws_s3_bucket.cloudtrail.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

# -----------------------------------------------------------------------------
# Multi-Region CloudTrail
# -----------------------------------------------------------------------------

resource "aws_cloudtrail" "management" {
  #checkov:skip=CKV_AWS_252:SNS delivery is not required for the Phase 09 audit baseline because CloudTrail is integrated with CloudWatch Logs; alerting will be implemented in the security-monitoring phase.

  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  kms_key_id                    = aws_kms_key.cloudtrail.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  enable_logging                = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  event_selector {
    include_management_events = true
    read_write_type           = "All"
  }

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_cloudwatch
  ]

  tags = {
    Name = local.trail_name
  }
}

# -----------------------------------------------------------------------------
# CloudTrail CloudWatch Logs integration
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.trail_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.cloudtrail.arn

  tags = {
    Name = "${local.trail_name}-logs"
  }
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch_assume_role" {
  statement {
    sid     = "AllowCloudTrailAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name               = "${var.project_name}-${var.environment}-cloudtrail-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_cloudwatch_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-cloudtrail-cloudwatch"
  }
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch" {
  statement {
    sid    = "WriteCloudTrailLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name   = "${var.project_name}-${var.environment}-cloudtrail-cloudwatch"
  role   = aws_iam_role.cloudtrail_cloudwatch.id
  policy = data.aws_iam_policy_document.cloudtrail_cloudwatch.json
}