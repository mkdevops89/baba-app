#############################################
# Human EKS Access Roles
#############################################

data "aws_caller_identity" "current" {}

#############################################
# Trust Policy
#
# These roles can only be assumed by the
# AWS IAM Identity Center AdministratorAccess
# permission-set role in this AWS account.
#############################################

data "aws_iam_policy_document" "human_access_trust" {
  statement {
    sid    = "AllowIdentityCenterAdministrator"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"

      values = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_*"
      ]
    }
  }
}

#############################################
# Namespace Administrator
#
# This is NOT Kubernetes cluster-admin.
# EKS authentication maps this role to the
# baba-app-admins Kubernetes group, which is
# bound only inside the baba-app namespace.
#############################################

resource "aws_iam_role" "eks_namespace_admin" {
  name = "${var.project_name}-${var.environment}-eks-admin"

  assume_role_policy = data.aws_iam_policy_document.human_access_trust.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-admin"
    Environment = var.environment
    Purpose     = "EKS namespace administration"
  }
}

resource "aws_eks_access_entry" "eks_namespace_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.eks_namespace_admin.arn
  type          = "STANDARD"

  kubernetes_groups = [
    "baba-app-admins"
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-admin-access"
    Environment = var.environment
  }
}

#############################################
# Developer
#############################################

resource "aws_iam_role" "eks_developer" {
  name = "${var.project_name}-${var.environment}-eks-developer"

  assume_role_policy = data.aws_iam_policy_document.human_access_trust.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-developer"
    Environment = var.environment
    Purpose     = "EKS developer access"
  }
}

resource "aws_eks_access_entry" "eks_developer" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.eks_developer.arn
  type          = "STANDARD"

  kubernetes_groups = [
    "baba-app-developers"
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-developer-access"
    Environment = var.environment
  }
}

#############################################
# Read-Only
#############################################

resource "aws_iam_role" "eks_readonly" {
  name = "${var.project_name}-${var.environment}-eks-readonly"

  assume_role_policy = data.aws_iam_policy_document.human_access_trust.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-readonly"
    Environment = var.environment
    Purpose     = "EKS read-only access"
  }
}

resource "aws_eks_access_entry" "eks_readonly" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.eks_readonly.arn
  type          = "STANDARD"

  kubernetes_groups = [
    "baba-app-readonly"
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-eks-readonly-access"
    Environment = var.environment
  }
}