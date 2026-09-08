# Phase 07 Validation

## Pre-Merge Validation

The following checks were completed before merge.

### Terraform

- Terraform configuration validated successfully.
- `enable_eks = false` produces no EKS resources.
- `enable_eks = true` produces only the expected EKS resources.
- normal Terraform plan with EKS disabled produces no changes.
- remote backend operates without a hard-coded AWS CLI profile.

### IAM

The dedicated infrastructure automation role was created and verified in AWS.

Role:

```text
baba-app-dev-github-actions-infrastructure
```

The role uses GitHub OIDC and does not rely on long-lived credentials.

### GitHub Environment

Environment:

```text
infrastructure-dev
```

Deployment branch policy:

```text
main
```

Environment variable:

```text
EKS_PUBLIC_ACCESS_CIDR
```

The CIDR is stored as a GitHub Environment variable rather than committed to the repository.

### Infrastructure Security

The initial expanded Kubernetes Checkov scan identified findings related to:

- reusable base namespace
- placeholder image references
- image pull policy
- container UID

The scan was updated to evaluate the rendered development Kustomize overlay.

The container UID finding was remediated by explicitly declaring:

```yaml
runAsUser: 65532
runAsGroup: 65532
```

After remediation, the Infrastructure Security workflow passed.

## Post-Merge Runtime Validation

Runtime validation is intentionally performed after merge to `main`.

### Provision Test

Expected validation:

- Terraform applies `enable_eks = true`
- EKS cluster reaches `ACTIVE`
- worker nodes reach `Ready`
- Terraform state contains EKS resources

### Destroy Test

Expected validation:

- Terraform applies `enable_eks = false`
- EKS cluster is absent
- Terraform state contains no `module.eks` resources
- subsequent normal Terraform plan reports no changes

## Evidence

Runtime evidence should include:

- GitHub Actions workflow run
- Terraform plan summary
- successful apply
- AWS EKS cluster state
- Kubernetes node readiness
- successful destruction
- Terraform state validation
