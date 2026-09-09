# -----------------------------------------------------------------------------
# GitHub Actions trust policy
# -----------------------------------------------------------------------------
# The infrastructure automation role is separate from the CI/CD artifact
# publishing role. This preserves separation of duties between container
# publication and infrastructure lifecycle management.
#
# Only the immutable Baba App repository identity operating through the
# protected infrastructure GitHub Environment may assume this role.
#
# GitHub Environment protection provides an additional approval boundary
# before AWS credentials can be issued for infrastructure lifecycle actions.
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowBabaAppMainGitHubActions"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        var.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repository}@${var.github_repository_id}:environment:${var.github_environment}"
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# Dedicated infrastructure automation role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_infrastructure" {
  name = "${var.project_name}-${var.environment}-github-actions-infrastructure"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-github-actions-infrastructure"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "infrastructure-lifecycle-automation"
  }
}

# -----------------------------------------------------------------------------
# Terraform backend permissions
# -----------------------------------------------------------------------------
# Terraform can read and update only the development state object and its
# native S3 lock file. It is not granted unrestricted access to the bucket.
data "aws_iam_policy_document" "infrastructure_automation" {
  statement {
    sid    = "ListTerraformStatePrefix"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      var.terraform_state_bucket_arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = [
        var.terraform_state_key,
        "${var.terraform_state_key}.tflock"
      ]
    }
  }

  statement {
    sid    = "ManageDevelopmentTerraformState"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "${var.terraform_state_bucket_arn}/${var.terraform_state_key}",
      "${var.terraform_state_bucket_arn}/${var.terraform_state_key}.tflock"
    ]
  }

  statement {
    sid    = "UseTerraformStateKMSKey"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]

    resources = [
      var.terraform_state_kms_key_arn
    ]
  }

  # ---------------------------------------------------------------------------
  # EKS lifecycle permissions
  # ---------------------------------------------------------------------------
  # These actions support creation, inspection, and deletion of the Baba App
  # development EKS cluster and its managed node group.
  statement {
    sid    = "ManageBabaAppDevelopmentEKS"
    effect = "Allow"

    actions = [
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:CreateNodegroup",
      "eks:DeleteNodegroup",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",

      # EKS Access API permissions allow Terraform to manage the approved
      # administrative access entry and its cluster access policy association.
      "eks:CreateAccessEntry",
      "eks:DescribeAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:UpdateAccessEntry",
      "eks:ListAccessEntries",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
      "eks:ListAssociatedAccessPolicies"
    ]

    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # EKS IAM role lifecycle
  # ---------------------------------------------------------------------------
  # Terraform may create and remove only the named roles used by the Baba App
  # EKS control plane and worker nodes.
  statement {
    sid    = "ManageBabaAppEKSRoles"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:ListAttachedRolePolicies"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-cluster-role",
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-node-role"
    ]
  }

  # Terraform must pass the two approved roles to EKS and EC2.
  statement {
    sid    = "PassApprovedEKSRoles"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-cluster-role",
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-node-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "eks.amazonaws.com"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Read-only infrastructure refresh
  # ---------------------------------------------------------------------------
  # Terraform refreshes the existing long-lived foundation before planning.
  # Read access does not permit these services to be modified by this role.
  statement {
    sid    = "ReadExistingBabaAppFoundation"
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:ListResourceTags",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      "logs:ListTagsForResource",
      "logs:DescribeLogGroups",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "infrastructure_automation" {
  name        = "${var.project_name}-${var.environment}-github-actions-infrastructure"
  description = "Least-privilege permissions for Baba App EKS lifecycle automation."

  policy = data.aws_iam_policy_document.infrastructure_automation.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "infrastructure_automation" {
  role       = aws_iam_role.github_actions_infrastructure.name
  policy_arn = aws_iam_policy.infrastructure_automation.arn
}