# -----------------------------------------------------------------------------
# Phase 10 - FinOps read-only access
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# Only the existing AWS IAM Identity Center AdministratorAccess role in this
# account may assume the dedicated FinOps role.
data "aws_iam_policy_document" "finops_trust" {
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

# Read-only permissions required by the Phase 10 baseline, monthly reporting,
# budget validation, anomaly review, and cost-allocation tag audit scripts.
data "aws_iam_policy_document" "finops_readonly" {
  statement {
    sid    = "ReadCostExplorerReports"
    effect = "Allow"

    actions = [
      "ce:GetAnomalies",
      "ce:GetAnomalyMonitors",
      "ce:GetAnomalySubscriptions",
      "ce:GetCostAndUsage",
      "ce:GetCostAndUsageWithResources",
      "ce:GetCostForecast",
      "ce:GetDimensionValues",
      "ce:GetTags"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ReadBudgetControls"
    effect = "Allow"

    actions = [
      "budgets:DescribeBudget",
      "budgets:DescribeNotificationsForBudget",
      "budgets:DescribeSubscribersForNotification",
      "budgets:ViewBudget"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "ReadResourceTagCompliance"
    effect = "Allow"

    actions = [
      "tag:GetComplianceSummary",
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues"
    ]

    resources = ["*"]
  }

  # The tag-audit script uses key state only to distinguish active resources
  # from KMS keys that AWS is already permanently deleting.
  statement {
    sid    = "ReadKMSKeyState"
    effect = "Allow"

    actions = [
      "kms:DescribeKey"
    ]

    resources = [
      "arn:aws:kms:*:${data.aws_caller_identity.current.account_id}:key/*"
    ]
  }
}

resource "aws_iam_role" "finops_readonly" {
  name                 = "${var.project_name}-${var.environment}-finops-readonly"
  description          = "Read-only access to Baba App cost, budget, anomaly, and tag information."
  assume_role_policy   = data.aws_iam_policy_document.finops_trust.json
  max_session_duration = 3600

  tags = {
    Name    = "${var.project_name}-${var.environment}-finops-readonly"
    Purpose = "FinOps reporting and cost governance"
    Phase   = var.phase
  }
}

resource "aws_iam_policy" "finops_readonly" {
  name        = "${var.project_name}-${var.environment}-finops-readonly"
  description = "Read-only Baba App cost reporting, budget, anomaly, and tag-audit permissions."
  policy      = data.aws_iam_policy_document.finops_readonly.json

  tags = {
    Name    = "${var.project_name}-${var.environment}-finops-readonly"
    Purpose = "FinOps reporting and cost governance"
    Phase   = var.phase
  }
}

resource "aws_iam_role_policy_attachment" "finops_readonly" {
  role       = aws_iam_role.finops_readonly.name
  policy_arn = aws_iam_policy.finops_readonly.arn
}