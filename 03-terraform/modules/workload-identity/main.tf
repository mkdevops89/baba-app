# -----------------------------------------------------------------------------
# Backend demo secret
# -----------------------------------------------------------------------------
# This secret exists only to demonstrate a realistic workload-identity pattern.
# No plaintext secret value is stored in Terraform or Git.
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "backend_secret_kms" {
  statement {
    sid    = "EnableAccountAdministration"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSecretsManagerUse"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
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
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
      ]
    }
  }
}

resource "aws_kms_key" "backend_secret" {
  description             = "KMS key for Baba App backend Secrets Manager configuration"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.backend_secret_kms.json

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-secret"
  }
}

resource "aws_kms_alias" "backend_secret" {
  name          = "alias/${var.project_name}-${var.environment}-backend-secret"
  target_key_id = aws_kms_key.backend_secret.key_id
}

resource "aws_secretsmanager_secret" "backend_config" {
  #checkov:skip=CKV2_AWS_57:This is a static development configuration secret used to validate EKS Pod Identity; automatic credential rotation is not applicable to this demo value.

  name = "${var.project_name}/${var.environment}/backend/config"
  kms_key_id = aws_kms_key.backend_secret.arn

  description = "Demo backend configuration used to validate EKS Pod Identity."
  
  # This is a disposable development secret. Immediate deletion keeps the
  # cluster lifecycle reproducible and prevents a scheduled-deletion secret
  # from blocking recreation with the same name.
  recovery_window_in_days = 0
  
  tags = {
    Name = "${var.project_name}-${var.environment}-backend-config"
  }
}

# -----------------------------------------------------------------------------
# EKS Pod Identity trust policy
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "backend_pod_identity_trust" {
  statement {
    sid    = "AllowEksPodIdentity"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "backend" {
  name               = "${var.project_name}-${var.environment}-backend-pod-identity"
  assume_role_policy = data.aws_iam_policy_document.backend_pod_identity_trust.json

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-pod-identity"
  }
}

# -----------------------------------------------------------------------------
# Least-privilege Secrets Manager access
# -----------------------------------------------------------------------------
# The backend workload can read only its dedicated secret. It cannot enumerate
# or retrieve unrelated secrets in the AWS account.
data "aws_iam_policy_document" "backend_secret_read" {
  statement {
    sid    = "ReadBackendConfigSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.backend_config.arn
    ]
  }

  statement {
    sid    = "DecryptBackendConfigSecret"
    effect = "Allow"

    actions = [
      "kms:Decrypt"
    ]

    resources = [
      aws_kms_key.backend_secret.arn
    ]
  }
}

resource "aws_iam_policy" "backend_secret_read" {
  name   = "${var.project_name}-${var.environment}-backend-secret-read"
  policy = data.aws_iam_policy_document.backend_secret_read.json
}

resource "aws_iam_role_policy_attachment" "backend_secret_read" {
  role       = aws_iam_role.backend.name
  policy_arn = aws_iam_policy.backend_secret_read.arn
}

# -----------------------------------------------------------------------------
# EKS Pod Identity association
# -----------------------------------------------------------------------------
# Bind the Kubernetes backend ServiceAccount to the IAM role. EKS injects
# temporary credentials only into Pods using this exact namespace/account pair.
resource "aws_eks_pod_identity_association" "backend" {
  cluster_name    = var.cluster_name
  namespace       = "baba-app"
  service_account = "baba-app-backend"
  role_arn        = aws_iam_role.backend.arn
}