# Phase 07 Architecture

## Purpose

Phase 07 separates infrastructure lifecycle automation from application CI/CD.

Application delivery and infrastructure mutation use different AWS IAM roles so compromise of one workflow does not automatically provide access to the other.

## Identity Separation

Application CI/CD role:

```text
baba-app-dev-github-actions-cicd
```

Infrastructure lifecycle role:

```text
baba-app-dev-github-actions-infrastructure
```

The CI/CD role is used for application artifact publication.

The infrastructure role is used only for controlled Terraform infrastructure lifecycle operations.

## Trust Flow

```text
GitHub Actions
     |
     | OIDC token
     v
AWS IAM OIDC Provider
     |
     | Subject restricted to:
     | infrastructure-dev Environment
     v
Infrastructure Automation IAM Role
     |
     v
Terraform
     |
     +--> S3 remote state
     +--> KMS state encryption
     +--> EKS lifecycle
     +--> EKS IAM roles
```

## GitHub Environment

The workflow uses:

```text
infrastructure-dev
```

The Environment is restricted to:

```text
main
```

The AWS IAM trust policy uses the GitHub Environment identity rather than a reusable branch-only identity.

This provides layered enforcement:

```text
GitHub workflow main check
+
GitHub Environment main-only deployment policy
+
AWS OIDC Environment subject restriction
```

## Terraform State

Terraform uses a portable S3 backend:

```text
bucket:
baba-app-dev-terraform-state-406312601212

state:
environments/dev/terraform.tfstate
```

State is encrypted with AWS KMS and uses S3 native state locking.

The backend configuration contains no local AWS CLI profile.

Local execution uses the standard AWS credential chain.

GitHub Actions uses temporary OIDC credentials.

## EKS Lifecycle

The EKS module is controlled by:

```hcl
count = var.enable_eks ? 1 : 0
```

This replaces the earlier operational need for targeted Terraform commands.

Provisioning:

```text
enable_eks = true
```

Destruction:

```text
enable_eks = false
```
