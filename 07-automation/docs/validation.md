# Phase 07 Validation

## Pre-Merge Validation

The following checks were completed before merge.

### Terraform

- Terraform configuration validated successfully.
- `enable_eks = false` produces no EKS resources.
- `enable_eks = true` produces only the expected EKS resources.
- Normal Terraform plan with EKS disabled produces no changes.
- Remote backend operates without a hard-coded AWS CLI profile.

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

Environment variables:

```text
EKS_PUBLIC_ACCESS_CIDR
EKS_CLUSTER_ADMIN_PRINCIPAL_ARN
```

The EKS public access CIDR is stored as a GitHub Environment variable rather than committed to the repository.

The EKS administrator principal ARN is also supplied through the protected GitHub Environment so Terraform receives the same intended administrative access configuration during automated lifecycle operations.

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

Runtime validation was completed after merge to `main`.

### Provision Validation

The infrastructure lifecycle workflow successfully validated the EKS provision path.

Validation included:

- Terraform lifecycle execution with `enable_eks = true`
- GitHub OIDC authentication to AWS
- EKS cluster status confirmed as `ACTIVE`
- managed node group status confirmed as `ACTIVE`
- Terraform-managed EKS administrative access entry
- cluster-scoped `AmazonEKSClusterAdminPolicy`
- local Kubernetes API validation from the approved administrator workstation
- both EKS worker nodes confirmed `Ready`

Local validation command:

```bash
07-automation/scripts/validate-eks-ready.sh
```

The script successfully returned both worker nodes in `Ready` state.

### EKS Authentication Validation

The EKS cluster authentication mode was updated from:

```text
CONFIG_MAP
```

to:

```text
API_AND_CONFIG_MAP
```

A Terraform-managed EKS access entry was created for the approved IAM Identity Center administrator role.

The access entry was associated with:

```text
AmazonEKSClusterAdminPolicy
```

using cluster scope.

This resolved the previous Kubernetes authentication error:

```text
the server has asked for the client to provide credentials
```

### GitHub Runner Validation Strategy

The EKS Kubernetes API endpoint remains restricted to the approved administrator CIDR.

Because GitHub-hosted runners do not originate from that approved CIDR, Kubernetes API validation was intentionally removed from the GitHub lifecycle workflow.

The GitHub workflow now validates infrastructure through AWS APIs:

```text
aws eks describe-cluster
aws eks describe-nodegroup
```

Kubernetes API validation remains a separate administrator-side check from the approved network location.

This preserves the restricted EKS endpoint instead of widening public access for CI convenience.

### Destroy Validation

The controlled destroy workflow completed successfully.

Successful workflow run:

```text
34357082297
```

Validation included:

- reviewed Terraform destroy plan
- EKS access policy association removed
- EKS access entry removed
- managed node group removed
- EKS cluster removed
- EKS IAM resources removed
- post-destroy AWS validation completed successfully

Local validation command:

```bash
07-automation/scripts/validate-eks-destroyed.sh
```

Result:

```text
EKS cluster is absent.
```

Terraform state validation command:

```bash
07-automation/scripts/validate-terraform-state.sh
```

Result:

```text
No module.eks resources remain in Terraform state.
```

A final Terraform plan returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed that the environment returned to the intended steady state with EKS disabled.

## Troubleshooting and Remediation Evidence

### GitHub Runner Could Not Reach EKS Kubernetes API

Initial post-provision validation attempted to use `kubectl` from a GitHub-hosted runner.

The runner could not reach the EKS public endpoint because the cluster only allowed the approved administrator `/32` CIDR.

Remediation:

- kept the EKS endpoint restriction in place
- removed GitHub-hosted `kubectl` validation
- replaced it with AWS EKS API validation
- retained Kubernetes API validation on the approved administrator workstation

### Local kubectl Authentication Failure

The administrator workstation could reach the EKS endpoint but initially received:

```text
You must be logged in to the server
```

Root cause:

- the local IAM Identity Center administrator role did not have an explicit EKS access entry

Remediation:

- enabled `API_AND_CONFIG_MAP`
- created a Terraform-managed EKS access entry
- associated `AmazonEKSClusterAdminPolicy`
- validated node readiness successfully

### Terraform Access Entry Refresh Failure

Terraform in GitHub Actions initially failed with:

```text
eks:DescribeAccessEntry
```

Access denied.

Remediation:

- expanded the dedicated infrastructure automation role with the EKS Access API permissions required for Terraform lifecycle management
- passed the configured administrator principal ARN through the protected GitHub Environment

### Partial Destroy IAM Failure

The first destroy attempt successfully removed the EKS cluster and node group but stopped while deleting the EKS IAM roles.

Terraform required:

```text
iam:ListInstanceProfilesForRole
```

before deleting the roles.

Remediation:

- added `iam:ListInstanceProfilesForRole` to the restricted EKS role-management policy
- updated the automation IAM policy
- reran the destroy workflow
- Terraform safely resumed from the partially destroyed state and completed teardown

## Final Validation State

Phase 07 ended in the intended steady state:

```text
EKS cluster is absent.
No module.eks resources remain in Terraform state.
No changes. Your infrastructure matches the configuration.
```

## Evidence

Phase 07 validation evidence includes:

- GitHub Actions lifecycle workflow runs
- Terraform plan summaries
- successful provision and destroy applies
- AWS EKS cluster and node group status checks
- Kubernetes node readiness validation
- EKS access entry and policy association validation
- successful destruction
- Terraform state validation
- final no-change Terraform plan