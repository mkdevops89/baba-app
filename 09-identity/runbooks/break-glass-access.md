# Baba App Phase 09 — Break-Glass and Privileged Access Runbook

## Purpose

This runbook defines the emergency administrative access model for the Baba App EKS environment.

Normal access remains least-privileged and namespace-scoped. The existing AWS IAM Identity Center administrator path serves as the controlled high-privilege recovery path. No permanent emergency IAM user or static credential is created.

## Scope

- Project: `baba-app`
- Environment: `dev`
- Region: `us-east-1`
- EKS cluster: `baba-app-dev-eks`
- Normal human roles:
  - `baba-app-dev-eks-admin`
  - `baba-app-dev-eks-developer`
  - `baba-app-dev-eks-readonly`
- High-privilege path:
  - AWS IAM Identity Center `AdministratorAccess`
  - EKS `AmazonEKSClusterAdminPolicy`

## Security Model

Normal access:

```text
Human identity
→ dedicated IAM role
→ EKS Access Entry
→ Kubernetes group
→ namespace-scoped RBAC
```

Emergency access:

```text
Authorized administrator
→ AWS IAM Identity Center
→ AdministratorAccess
→ EKS Access Entry
→ AmazonEKSClusterAdminPolicy
→ cluster-wide administration
```

## When Break-Glass Access May Be Used

Use only when normal role-based access is insufficient, such as:

- accidental RBAC lockout;
- EKS Access Entry misconfiguration;
- GitOps failure preventing access remediation;
- cluster security incident requiring immediate containment;
- failed IAM/RBAC deployment;
- critical platform outage;
- emergency revocation of compromised access.

Do not use it for routine deployment, troubleshooting, or normal namespace administration.

## Pre-Use Checklist

Before using the high-privilege path:

- Confirm normal namespace roles are insufficient.
- Record the reason for elevation.
- Record the affected cluster and environment.
- Identify the minimum emergency action required.
- Avoid unrelated changes.
- Prefer reversible actions.
- Preserve evidence for post-event review.

Example ticket note:

```text
Reason: Developer access entry was accidentally removed.
Impact: Engineering cannot authenticate to the Baba App namespace.
Emergency action: Restore the approved EKS Access Entry and validate RBAC.
Expected duration: Less than 30 minutes.
```

## Validate High-Privilege Identity

Authenticate:

```bash
aws sso login --profile baba-admin
```

Confirm identity:

```bash
aws sts get-caller-identity --profile baba-admin
```

## Validate EKS Administrator Access Entry

```bash
aws eks list-access-entries   --cluster-name baba-app-dev-eks   --region us-east-1   --profile baba-admin
```

Then inspect the approved Identity Center administrator principal:

```bash
aws eks list-associated-access-policies   --cluster-name baba-app-dev-eks   --principal-arn <IDENTITY_CENTER_ADMIN_ROLE_ARN>   --region us-east-1   --profile baba-admin
```

Expected:

```text
AmazonEKSClusterAdminPolicy
accessScope: cluster
```

## Validate Kubernetes Cluster-Admin Capability

```bash
kubectl auth can-i '*' '*' --all-namespaces
```

Expected:

```text
yes
```

This confirms the recovery path only; it is not intended for routine use.

## Preferred Recovery Method

Prefer Terraform reconciliation rather than ad hoc manual fixes.

```bash
cd ~/baba-app/03-terraform/environments/dev

terraform fmt -recursive
terraform validate

AWS_PROFILE=baba-admin terraform plan   -var='enable_eks=true'
```

Review carefully. Do not apply plans containing unexpected destruction, EKS replacement, or unrelated changes.

Save the exact approved plan:

```bash
AWS_PROFILE=baba-admin terraform plan   -var='enable_eks=true'   -out=phase09-break-glass-recovery.tfplan
```

Apply:

```bash
AWS_PROFILE=baba-admin terraform apply   phase09-break-glass-recovery.tfplan
```

## Validate Restored Access

Developer:

```bash
KUBECONFIG="$HOME/.kube/baba-app-developer" kubectl auth can-i get pods -n baba-app
```

Readonly:

```bash
KUBECONFIG="$HOME/.kube/baba-app-readonly" kubectl auth can-i get pods -n baba-app
```

Namespace admin:

```bash
KUBECONFIG="$HOME/.kube/baba-app-namespace-admin" kubectl auth can-i create deployments.apps -n baba-app
```

Re-run negative authorization tests as well.

## Emergency Containment

Before revoking a compromised principal, capture:

- principal ARN;
- access entry;
- associated EKS access policies;
- Kubernetes groups;
- relevant CloudTrail evidence;
- incident/change identifier.

Inspect:

```bash
aws eks describe-access-entry   --cluster-name baba-app-dev-eks   --principal-arn <PRINCIPAL_ARN>   --region us-east-1   --profile baba-admin
```

Direct CLI or console changes are emergency-only and must be reconciled back into Terraform afterward.

## Post-Use Requirements

After emergency access:

1. Confirm service/access restoration.
2. Re-run positive and negative RBAC tests.
3. Run Terraform plan with `enable_eks=true`.
4. Confirm no unexplained drift remains.
5. Record all emergency actions.
6. Reconcile manual changes back into Terraform or GitOps.
7. Review CloudTrail and EKS audit events.
8. Update/close the incident or change ticket.
9. Document root cause and prevention actions.
10. Return to normal least-privileged roles.

## Post-Use Terraform Validation

```bash
cd ~/baba-app/03-terraform/environments/dev

AWS_PROFILE=baba-admin terraform plan   -var='enable_eks=true'
```

Expected after reconciliation:

```text
No changes.
```

## Access Revocation Principle

The break-glass design intentionally does not create:

- permanent IAM users;
- long-lived access keys;
- shared administrator credentials;
- hard-coded Kubernetes tokens.

It relies on federated Identity Center access and short-lived AWS sessions.

## Audit Evidence

Retain:

- incident/change ticket;
- justification for elevation;
- principal used;
- start/end time;
- actions performed;
- Terraform plan/apply output;
- CloudTrail events;
- EKS audit events;
- validation results;
- root-cause/remediation notes.

## Security Decision

The Baba App environment keeps one federated cluster-admin path through AWS IAM Identity Center for platform administration and emergency recovery.

Routine engineers use dedicated EKS Access Entries mapped to namespace-scoped Kubernetes RBAC groups.

This provides:

- least privilege for daily work;
- a recoverable admin path;
- no static emergency credentials;
- federated access;
- separation between routine and emergency administration;
- auditable privileged access.

## Validation Checklist

- [ ] Identity Center administrator can authenticate.
- [ ] Approved Identity Center EKS Access Entry exists.
- [ ] `AmazonEKSClusterAdminPolicy` is associated only with the approved administrator principal.
- [ ] GitHub infrastructure automation has no EKS cluster-admin policy.
- [ ] Namespace admin remains namespace-scoped.
- [ ] Developer cannot access Secrets or cluster resources.
- [ ] Readonly cannot mutate workloads.
- [ ] Break-glass use requires documented justification.
- [ ] Manual emergency changes are reconciled into Terraform/GitOps.
- [ ] CloudTrail/EKS audit evidence is reviewed after emergency use.

## Control

```text
IAM-09-011 — Break-glass and privileged access model
```

Mark the control **Validated** only after the administrator path, privilege boundaries, and audit evidence sources are confirmed.
