# -----------------------------------------------------------------------------
# GitHub Actions OpenID Connect provider
# -----------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

# -----------------------------------------------------------------------------
# GitHub Actions trust policy
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowGitHubActionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
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
        "repo:${var.github_owner}/${var.github_repository}:ref:refs/heads/main"
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# Dedicated CI/CD IAM role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_cicd" {
  name = "${var.project_name}-${var.environment}-github-actions-cicd"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-github-actions-cicd"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Least-privilege Amazon ECR permissions
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ecr_publish" {
  statement {
    sid    = "AllowECRAuthentication"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowPublishToBabaAppRepositories"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_policy" "ecr_publish" {
  name        = "${var.project_name}-${var.environment}-github-actions-ecr-publish"
  description = "Allows GitHub Actions to publish approved Baba App container images to ECR."

  policy = data.aws_iam_policy_document.ecr_publish.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ecr_publish" {
  role       = aws_iam_role.github_actions_cicd.name
  policy_arn = aws_iam_policy.ecr_publish.arn
}
