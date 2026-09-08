# Phase 07 — Secure Infrastructure Lifecycle Automation

## Overview

Phase 07 introduces controlled infrastructure lifecycle automation for the Baba App development environment.

The goal is to provision and destroy the EKS runtime through a secure, auditable workflow without relying on long-lived AWS credentials or targeted Terraform operations.

## Objectives

- Introduce declarative EKS lifecycle control through Terraform.
- Remove dependence on targeted Terraform operations such as `-target=module.eks`.
- Use GitHub Actions for controlled infrastructure provisioning and destruction.
- Authenticate to AWS through GitHub OIDC.
- Use a dedicated least-privilege infrastructure automation IAM role.
- Restrict infrastructure execution to the protected `infrastructure-dev` GitHub Environment.
- Restrict Environment deployments to the `main` branch.
- Require explicit confirmation for destructive operations.
- Generate and apply an exact Terraform plan.
- Validate EKS state after provisioning and destruction.
- Capture security and validation evidence.

## Architecture

The lifecycle flow is:

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
Post-action validation
```

## Infrastructure Lifecycle

Terraform uses the variable:

```hcl
enable_eks = true
```

to provision EKS and:

```hcl
enable_eks = false
```

to remove EKS resources.

This allows Terraform to manage the complete lifecycle declaratively without targeted resource operations.

## Security Controls

Key controls include:

- GitHub OIDC authentication
- no static AWS access keys
- dedicated infrastructure automation IAM role
- restricted Terraform state access
- restricted IAM PassRole permissions
- GitHub Environment branch restrictions
- main-branch workflow guard
- manual workflow execution
- exact destroy confirmation string
- Terraform state locking
- plan-before-apply separation
- post-provision validation
- post-destroy validation
- Checkov and Trivy security scanning

See:

- `docs/architecture.md`
- `docs/security-controls.md`
- `docs/validation.md`

## Workflow

Primary workflow:

```text
.github/workflows/infrastructure-lifecycle.yml
```

Security validation:

```text
.github/workflows/infrastructure-security.yml
```

## Phase Status

Implementation complete on:

```text
feature/automation-foundation
```

Full runtime lifecycle validation is performed after merge to `main` because the AWS OIDC trust and protected GitHub Environment intentionally restrict infrastructure execution to the main branch.