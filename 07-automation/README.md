# Phase 07 — Secure Infrastructure Lifecycle Automation

## Overview

Phase 07 introduces controlled infrastructure lifecycle automation for the Baba App development environment.

The goal is to provision and destroy the EKS runtime through a secure, auditable workflow without relying on long-lived AWS credentials or targeted Terraform lifecycle operations.

The implementation uses Terraform, GitHub Actions, GitHub OIDC, protected GitHub Environments, least-privilege IAM, EKS Access API authentication, plan artifacts, and post-action validation.

## Objectives

- Introduce declarative EKS lifecycle control through Terraform.
- Remove dependence on targeted Terraform lifecycle operations such as `-target=module.eks`.
- Use GitHub Actions for controlled infrastructure provisioning and destruction.
- Authenticate to AWS through GitHub OIDC.
- Use a dedicated least-privilege infrastructure automation IAM role.
- Restrict infrastructure execution to the protected `infrastructure-dev` GitHub Environment.
- Restrict Environment deployments to the `main` branch.
- Require explicit confirmation for destructive operations.
- Generate and apply an exact reviewed Terraform plan.
- Validate EKS infrastructure after provisioning and destruction.
- Manage EKS administrator access through the EKS Access API.
- Preserve restricted Kubernetes API network access.
- Capture security, troubleshooting, and lifecycle validation evidence.

## Architecture

The infrastructure lifecycle flow is:

```text
Manual workflow_dispatch
        |
        v
Main branch validation
        |
        v
Protected GitHub Environment
infrastructure-dev
        |
        v
GitHub OIDC
        |
        v
Dedicated AWS IAM Role
        |
        v
Terraform init / validate / plan
        |
        v
Saved Terraform Plan Artifact
        |
        v
Terraform Apply
        |
        v
AWS API Post-Action Validation
```

Kubernetes API validation is intentionally separated from GitHub-hosted infrastructure validation:

```text
GitHub Actions
      |
      v
AWS EKS APIs
      |
      +--> Cluster status
      +--> Node group status

Approved Administrator Workstation
      |
      v
Restricted EKS Public Endpoint
      |
      v
kubectl
      |
      +--> Kubernetes node readiness
```

This design preserves the restricted EKS endpoint instead of widening network access for CI convenience.

## Infrastructure Lifecycle

Terraform uses:

```hcl
enable_eks = true
```

to provision EKS and:

```hcl
enable_eks = false
```

to remove the EKS runtime.

This allows Terraform to manage the complete EKS lifecycle declaratively without requiring targeted EKS resource operations.

The lifecycle workflow supports:

```text
provision
destroy
```

Destroy operations require the explicit confirmation value:

```text
DESTROY-EKS
```

## EKS Administrative Access

The EKS authentication mode uses:

```text
API_AND_CONFIG_MAP
```

Administrative Kubernetes access is managed through a Terraform-managed EKS access entry.

The approved IAM Identity Center administrator role is associated with:

```text
AmazonEKSClusterAdminPolicy
```

using cluster scope.

This provides explicit, auditable Kubernetes administrative authorization while maintaining the existing IAM Identity Center authentication model.

## GitHub Environment

Infrastructure automation runs through:

```text
infrastructure-dev
```

The Environment is restricted to the `main` branch.

Environment variables include:

```text
EKS_PUBLIC_ACCESS_CIDR
EKS_CLUSTER_ADMIN_PRINCIPAL_ARN
```

The administrator CIDR and EKS administrator principal configuration are supplied at runtime rather than hard-coded into reusable Terraform modules.

## Security Controls

Key controls include:

- GitHub OIDC authentication
- no static AWS access keys
- dedicated infrastructure automation IAM role
- restricted Terraform state access
- restricted IAM `PassRole` permissions
- Terraform-managed EKS Access API authorization
- GitHub Environment branch restrictions
- main-branch workflow guard
- manual workflow execution
- explicit destroy confirmation
- Terraform state locking
- plan-before-apply separation
- saved Terraform plan artifact
- exact reviewed plan application
- AWS API post-provision validation
- post-destroy validation
- restricted EKS public endpoint CIDR
- administrator-side Kubernetes validation
- Checkov security scanning
- Trivy security scanning

See:

- `docs/architecture.md`
- `docs/security-controls.md`
- `docs/validation.md`

## Workflow

Primary lifecycle workflow:

```text
.github/workflows/infrastructure-lifecycle.yml
```

Infrastructure security validation:

```text
.github/workflows/infrastructure-security.yml
```

Validation scripts:

```text
07-automation/scripts/validate-eks-ready.sh
07-automation/scripts/validate-eks-destroyed.sh
07-automation/scripts/validate-terraform-state.sh
```

## Runtime Validation

The complete EKS lifecycle was validated after merge to `main`.

Provision validation confirmed:

- GitHub OIDC authentication succeeded.
- Terraform lifecycle planning succeeded.
- EKS cluster reached `ACTIVE`.
- managed node group reached `ACTIVE`.
- local Kubernetes authentication succeeded.
- both worker nodes reached `Ready`.

Destroy validation confirmed:

- the EKS access policy association was removed.
- the EKS access entry was removed.
- the managed node group was removed.
- the EKS cluster was removed.
- EKS IAM lifecycle resources were removed.
- post-destroy AWS validation succeeded.
- Terraform state contained no remaining `module.eks` resources.

Successful destroy workflow run:

```text
34357082297
```

## Final State

Phase 07 concluded in the intended development steady state:

```text
EKS cluster is absent.
No module.eks resources remain in Terraform state.
No changes. Your infrastructure matches the configuration.
```

This confirms that the EKS runtime can be securely provisioned, validated, destroyed, and reconciled without affecting the long-lived Baba App infrastructure foundation.

## Phase Status

**Phase 07 — Complete**

Implementation, security validation, runtime provisioning, Kubernetes access validation, controlled destruction, Terraform state reconciliation, and final steady-state validation have all been completed successfully.
