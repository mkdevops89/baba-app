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

      # Phase 09 - EKS managed add-on lifecycle.
      "eks:CreateAddon",
      "eks:DeleteAddon",
      "eks:DescribeAddon",
      "eks:ListAddons",
      "eks:UpdateAddon",

      # Phase 09 - Pod Identity association lifecycle.
      "eks:CreatePodIdentityAssociation",
      "eks:DeletePodIdentityAssociation",
      "eks:DescribePodIdentityAssociation",
      "eks:ListPodIdentityAssociations",
      "eks:UpdatePodIdentityAssociation",

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
  # Phase 09 human EKS access role lifecycle
  # ---------------------------------------------------------------------------
  # Terraform may manage only the three IAM roles used for namespace-scoped
  # human access to the Baba App EKS cluster.
  #
  # These roles are authentication principals only. They do not receive AWS
  # permissions and are not passed to an AWS service. Kubernetes authorization
  # is enforced through EKS Access Entries and namespace-scoped RBAC groups.
  statement {
    sid    = "ManageHumanEKSAccessRoles"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-admin",
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-developer",
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-readonly"
    ]
  }

  # ---------------------------------------------------------------------------
  # Phase 09 workload identity IAM lifecycle
  # ---------------------------------------------------------------------------
  # Terraform may manage only the backend Pod Identity role created for the
  # Baba App development workload.
  statement {
    sid    = "ManageBackendPodIdentityRole"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-backend-pod-identity"
    ]
  }

  # Terraform may create and remove only the managed policy used by the
  # backend Pod Identity role.
  statement {
    sid    = "ManageBackendPodIdentityPolicy"
    effect = "Allow"

    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:SetDefaultPolicyVersion",
      "iam:TagPolicy",
      "iam:UntagPolicy"
    ]

    resources = [
      "arn:aws:iam::*:policy/${var.project_name}-${var.environment}-backend-secret-read"
    ]
  }

  # EKS needs permission to use this exact IAM role when Terraform creates the
  # Pod Identity association. Restrict PassRole to the Pod Identity service.
  statement {
    sid    = "PassBackendPodIdentityRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-backend-pod-identity"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "pods.eks.amazonaws.com"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Phase 09 demo secret lifecycle
  # ---------------------------------------------------------------------------
  # Limit automation to the Baba App development backend secret namespace.
  statement {
    sid    = "ManageBackendDemoSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:UpdateSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource"
    ]

    resources = [
      "arn:aws:secretsmanager:*:*:secret:${var.project_name}/${var.environment}/backend/config-*"
    ]
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

# -----------------------------------------------------------------------------
# Phase 09 security automation permissions
# -----------------------------------------------------------------------------
# These permissions are intentionally split into a second managed policy
# because the primary infrastructure automation policy reached the AWS
# managed-policy size quota.
data "aws_iam_policy_document" "phase09_security_automation" {
  # Terraform reads the secret resource policy during state refresh.
  statement {
    sid    = "ReadBackendDemoSecretPolicy"
    effect = "Allow"

    actions = [
      "secretsmanager:GetResourcePolicy"
    ]

    resources = [
      "arn:aws:secretsmanager:*:*:secret:${var.project_name}/${var.environment}/backend/config-*"
    ]
  }

  # Terraform checks for attached instance profiles before deleting IAM roles.
  statement {
    sid    = "ReadDeletableRoleInstanceProfiles"
    effect = "Allow"

    actions = [
      "iam:ListInstanceProfilesForRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-admin",
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-developer",
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-eks-readonly",
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-backend-pod-identity"
    ]
  }

  # ---------------------------------------------------------------------------
  # Phase 09 CloudTrail audit lifecycle
  # ---------------------------------------------------------------------------
  # Terraform may manage only the Baba App development management trail.
  statement {
    sid    = "ManageBabaAppCloudTrail"
    effect = "Allow"

    actions = [
      "cloudtrail:CreateTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:DeleteTrail",
      "cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:StartLogging",
      "cloudtrail:StopLogging",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:GetEventSelectors",
      "cloudtrail:AddTags",
      "cloudtrail:RemoveTags",
      "cloudtrail:ListTags"
    ]

    resources = [
      "arn:aws:cloudtrail:*:*:trail/${var.project_name}-${var.environment}-management-audit"
    ]
  }

  # Some CloudTrail discovery APIs do not support resource-level constraints.
  statement {
    sid    = "ReadCloudTrailConfiguration"
    effect = "Allow"

    actions = [
      "cloudtrail:DescribeTrails"
    ]

    resources = ["*"]
  }

  # ---------------------------------------------------------------------------
  # Phase 09 CloudTrail archive bucket lifecycle
  # ---------------------------------------------------------------------------
  # Scope S3 management to the single audit bucket used by CloudTrail.
  statement {
    sid    = "ManageCloudTrailAuditBucket"
    effect = "Allow"

    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:ListBucket",
      "s3:GetAccelerateConfiguration",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetBucket*",
      "s3:PutBucket*",
      "s3:DeleteBucket*"
    ]

    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment}-cloudtrail-*"
    ]
  }

  # ---------------------------------------------------------------------------
  # Phase 09 CloudTrail CloudWatch IAM role
  # ---------------------------------------------------------------------------
  statement {
    sid    = "ManageCloudTrailCloudWatchRole"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-cloudtrail-cloudwatch"
    ]
  }

  # CloudTrail must be allowed to receive the dedicated CloudWatch delivery
  # role. No other role may be passed through this permission.
  statement {
    sid    = "PassCloudTrailCloudWatchRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-${var.environment}-cloudtrail-cloudwatch"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "cloudtrail.amazonaws.com"
      ]
    }
  }

  # ---------------------------------------------------------------------------
  # Phase 09 security log groups
  # ---------------------------------------------------------------------------
  # Terraform manages only the CloudTrail and EKS control-plane log groups.
  statement {
    sid    = "ManagePhase09SecurityLogGroups"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:AssociateKmsKey",
      "logs:DisassociateKmsKey",
      "logs:TagResource",
      "logs:UntagResource"
    ]

    resources = [
      "arn:aws:logs:*:*:log-group:/aws/cloudtrail/${var.project_name}-${var.environment}-management-audit*",
      "arn:aws:logs:*:*:log-group:/aws/eks/${var.project_name}-${var.environment}-eks/cluster*"
    ]
  }

  # ---------------------------------------------------------------------------
  # Phase 09 customer-managed KMS lifecycle
  # ---------------------------------------------------------------------------
  # KMS CreateKey cannot be restricted to a pre-existing key ARN because the
  # ARN does not exist until AWS creates the key. Require Baba App project and
  # environment tags at creation instead.
  statement {
    sid    = "CreateBabaAppPhase09KMSKeys"
    effect = "Allow"

    actions = [
      "kms:CreateKey"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"

      values = [
        var.project_name
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Environment"

      values = [
        var.environment
      ]
    }
  }

  # Once created, Terraform may manage only KMS keys carrying the Baba App
  # project and environment tags.
  statement {
    sid    = "ManageBabaAppPhase09KMSKeys"
    effect = "Allow"

    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:EnableKeyRotation",
      "kms:DisableKeyRotation",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:EnableKey",
      "kms:DisableKey",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ListResourceTags",

      # Required when Terraform configures AWS services to use these CMKs.
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",

      # Alias operations require authorization against the target KMS key
      # as well as the explicitly scoped alias resource.
      "kms:CreateAlias",
      "kms:UpdateAlias",
      "kms:DeleteAlias"
    ]

    resources = [
      "arn:aws:kms:*:*:key/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"

      values = [
        var.project_name
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"

      values = [
        var.environment
      ]
    }
  }

  # KMS aliases are name-scoped because aliases themselves do not carry the
  # project/environment resource tags used above.
  statement {
    sid    = "ManageBabaAppPhase09KMSAliases"
    effect = "Allow"

    actions = [
      "kms:CreateAlias",
      "kms:UpdateAlias",
      "kms:DeleteAlias"
    ]

    resources = [
      "arn:aws:kms:*:*:alias/${var.project_name}-${var.environment}-cloudtrail",
      "arn:aws:kms:*:*:alias/${var.project_name}-${var.environment}-eks-control-plane-logs",
      "arn:aws:kms:*:*:alias/${var.project_name}-${var.environment}-backend-secret"
    ]
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

# -----------------------------------------------------------------------------
# Phase 09 security automation managed policy
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "phase09_security_automation" {
  name        = "${var.project_name}-${var.environment}-github-actions-phase09-security"
  description = "Phase 09 audit, KMS, CloudTrail, and security logging automation permissions."

  policy = data.aws_iam_policy_document.phase09_security_automation.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "phase09_security_automation" {
  role       = aws_iam_role.github_actions_infrastructure.name
  policy_arn = aws_iam_policy.phase09_security_automation.arn
}