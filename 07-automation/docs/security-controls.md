# Phase 07 Security Controls

## Authentication

GitHub Actions authenticates to AWS through OIDC.

No long-lived AWS access keys are stored in repository or Environment secrets.

## Dedicated Infrastructure Role

The infrastructure role is:

```text
baba-app-dev-github-actions-infrastructure
```

The role is separate from the application CI/CD role.

This limits the blast radius of workflow compromise.

## Terraform State Access

The infrastructure automation role is restricted to:

- the Baba App Terraform state bucket
- the development state object
- the Terraform lock object
- the Terraform state KMS key

The role does not receive general S3 administration permissions.

## IAM Role Control

The automation role may manage only the EKS roles required for the development environment.

`iam:PassRole` is restricted to the exact EKS roles and to:

```text
eks.amazonaws.com
```

## Privilege Escalation Boundary

The infrastructure automation role cannot modify its own IAM role or permissions.

Changes to the automation role must be performed through the administrative/bootstrap identity.

This prevents the lifecycle workflow from granting itself additional privileges.

## Destructive Operation Controls

EKS destruction requires:

1. manual `workflow_dispatch`
2. explicit `destroy` selection
3. exact confirmation value:

```text
DESTROY-EKS
```

4. execution from `main`
5. access through the protected `infrastructure-dev` Environment
6. successful AWS OIDC authentication
7. Terraform plan generation
8. application of the saved plan

## AWS Account Validation

The workflow validates that AWS credentials belong to:

```text
406312601212
```

before Terraform operations are executed.

This protects against accidental infrastructure execution in an unintended AWS account.

## Terraform Plan Integrity

The plan job creates a binary Terraform plan.

The apply job downloads and applies that exact plan instead of generating a new plan.

This reduces configuration drift between review and execution.

## Security Scanning

Infrastructure and Kubernetes configuration is evaluated through:

- Checkov
- Trivy

GitOps Kubernetes security scanning evaluates the rendered Kustomize development overlay instead of the reusable base manifests.

This prevents false findings caused by placeholder images and missing base namespaces.

## Container Identity Hardening

Backend and frontend workloads explicitly run as:

```text
UID 65532
GID 65532
```

with:

```yaml
runAsNonRoot: true
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
```

All Linux capabilities are dropped and the default seccomp profile is used.