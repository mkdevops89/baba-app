# Baba App Phase 09 — Identity & Access Management Final Validation

## Phase Status

**Status:** Ready for Pull Request / Squash Merge  
**Branch:** `phase-09-identity`

Phase 09 implemented and validated a layered identity and access model across AWS IAM, Amazon EKS, Kubernetes RBAC, workload identity, privileged access, and auditability.

## Objectives Completed

- Separate human and automation access.
- Remove unnecessary EKS cluster-admin privileges from automation.
- Implement namespace-scoped Kubernetes RBAC.
- Add dedicated Kubernetes ServiceAccounts.
- Implement EKS Pod Identity for the backend.
- Restrict AWS workload permissions using least privilege.
- Validate positive and negative authorization behavior.
- Implement human EKS access roles through EKS Access Entries.
- Preserve a controlled break-glass administrative path.
- Add durable AWS management-event auditing with CloudTrail.
- Add explicit EKS control-plane log retention.
- Validate Terraform drift-free state.

## IAM-09-001 — Automation Cluster-Admin Remediation

**Status:** Remediated and Validated

The GitHub infrastructure automation identity previously inherited EKS cluster-admin access from the cluster bootstrap configuration.

Remediation:
- Disabled automatic bootstrap creator-admin access for future clusters.
- Preserved the existing live cluster without replacement using Terraform lifecycle handling.
- Removed `AmazonEKSClusterAdminPolicy` from the GitHub infrastructure role.
- Retained explicit human administrator access.

Validation:
- GitHub infrastructure role has no associated EKS access policy.
- Human Identity Center administrator retains cluster-admin access.
- Terraform plan remained safe and did not replace the cluster.

## IAM-09-002 — Namespace Kubernetes RBAC

**Status:** Implemented and Validated

Created namespace-scoped RBAC groups:
- `baba-app-admins`
- `baba-app-developers`
- `baba-app-readonly`

Developer:
- Can read Pods and logs.
- Can update approved application workloads.
- Cannot read Secrets.
- Cannot modify RBAC.
- Cannot access cluster Nodes.
- Cannot access unrelated namespaces.

Readonly:
- Can read Pods, logs, Services, and Deployments.
- Cannot patch Deployments.
- Cannot delete Pods.
- Cannot read Secrets.
- Cannot access cluster resources.

Namespace admin:
- Can administer resources inside `baba-app`.
- Can manage namespaced RBAC.
- Cannot access Nodes.
- Cannot create ClusterRoles.
- Cannot access `observability`.

## IAM-09-003 — GitOps RBAC Drift Protection

**Status:** Implemented and Validated

Phase 09 RBAC manifests were integrated with Argo CD.

Validation:
- RBAC objects are GitOps-managed.
- A deleted Role was automatically restored by Argo CD.
- Application health remained stable after reconciliation.

## IAM-09-004 — Dedicated Workload Identities

**Status:** Implemented and Validated

Dedicated ServiceAccounts:
- Backend: `baba-app-backend`
- Frontend: `baba-app-frontend`

Both retain:

```text
automountServiceAccountToken: false
```

Validation:
- Backend Pods run with `baba-app-backend`.
- Frontend Pods run with `baba-app-frontend`.
- Application rollouts remained healthy.

## IAM-09-005 — AWS Workload Permission Review

**Status:** Validated

Security decision:
- Grant AWS permissions only where a workload has a defined dependency.
- Frontend receives no AWS workload role.
- Backend receives only narrowly scoped Secrets Manager access through EKS Pod Identity.
- No static AWS access keys are used.

## IAM-09-006 — EKS Pod Identity Foundation

**Status:** Implemented and Validated

Implemented:
- EKS Pod Identity Agent add-on.
- Dedicated backend IAM role.
- EKS Pod Identity association.
- Dedicated Secrets Manager secret.
- Least-privilege secret-read policy.

Backend IAM permissions:

```text
secretsmanager:GetSecretValue
secretsmanager:DescribeSecret
```

restricted to one designated backend secret.

Validation:
- Pod Identity Agent is `ACTIVE`.
- Agent DaemonSet is healthy across both worker nodes.
- Backend ServiceAccount maps to the dedicated IAM role.
- Pod Identity environment variables are injected.
- Projected Pod Identity token is mounted.
- Standard Kubernetes ServiceAccount token automount remains disabled.

## IAM-09-007 — Credential Delivery and Least-Privilege Enforcement

**Status:** Implemented and Validated

Positive backend test:
- Temporary AWS credentials delivered.
- STS confirmed the dedicated backend assumed role.
- Backend successfully retrieved its designated Secrets Manager secret.

Negative frontend test:
- Frontend received no AWS workload credentials.
- Secret retrieval failed with `NoCredentials`.
- No Pod Identity credential endpoint or authorization token was injected.

## IAM-09-008 — Human and Automation EKS Access Review

**Status:** Validated

Validated access entries for:
- AWS IAM Identity Center administrator.
- EKS service-linked role.
- EKS node role.
- GitHub infrastructure automation role.

Results:
- Identity Center administrator retains cluster-admin access.
- GitHub infrastructure role has no EKS cluster access policy.
- Node role has no unnecessary EKS access policy.
- EKS service-linked role contains AWS-managed service permissions only.

## IAM-09-009 — Human Role-Based EKS Access Model

**Status:** Implemented and Validated

Created IAM roles:
- `baba-app-dev-eks-admin`
- `baba-app-dev-eks-developer`
- `baba-app-dev-eks-readonly`

Mappings:

```text
baba-app-dev-eks-admin
→ baba-app-admins

baba-app-dev-eks-developer
→ baba-app-developers

baba-app-dev-eks-readonly
→ baba-app-readonly
```

No AWS-managed EKS access policies are attached to these roles. Kubernetes RBAC is the authorization layer.

Real IAM-role authentication and positive/negative RBAC testing succeeded for all three roles.

## IAM-09-010 — Terraform Automation Permissions

**Status:** Implemented and Validated

The GitHub infrastructure role was extended with narrowly scoped lifecycle permissions for only the approved human EKS IAM roles.

It can manage:
- `baba-app-dev-eks-admin`
- `baba-app-dev-eks-developer`
- `baba-app-dev-eks-readonly`

It was not granted:
- permission to assume those roles;
- additional Kubernetes privileges;
- EKS cluster-admin access.

## IAM-09-011 — Break-Glass and Privileged Access Model

**Status:** Implemented and Documented

The existing AWS IAM Identity Center administrator path is retained as the controlled high-privilege recovery path.

The design intentionally avoids:
- permanent break-glass IAM users;
- long-lived access keys;
- shared administrator credentials;
- hard-coded Kubernetes tokens.

Runbook:

```text
09-identity/runbooks/break-glass-access.md
```

## IAM-09-012 — Identity and Privileged-Access Auditability

**Status:** Implemented and Validated

### EKS Control-Plane Logging

Enabled:
- API
- Audit
- Authenticator
- Controller Manager
- Scheduler

CloudWatch retention:

```text
365 days
```

The existing EKS log group was imported into Terraform state and placed under lifecycle management.

### CloudTrail

Implemented:

```text
baba-app-dev-management-audit
```

Validated:
- Logging enabled.
- Multi-Region trail enabled.
- Global service events included.
- Management events enabled.
- Read and write management activity captured.
- Log file validation enabled.
- Dedicated S3 audit bucket.
- Public access blocked.
- Versioning enabled.
- SSE-KMS enabled.
- Dedicated customer-managed KMS key.
- KMS rotation enabled.
- S3 lifecycle expiration: 365 days.
- Noncurrent version expiration: 30 days.
- Secure transport enforced.

CloudTrail remains independent of `enable_eks`, so account-level administrative activity remains auditable even when development EKS is shut down for cost control.

## Final Terraform Validation

Final live-state result:

```text
No changes. Your infrastructure matches the configuration.
```

This confirms:
- no Terraform drift;
- audit resources reconciled;
- Pod Identity reconciled;
- human EKS access reconciled;
- no pending cluster replacement;
- no pending destruction.

## Final GitOps Validation

Pre-merge live state:

```text
baba-app-dev            phase-09-identity   Synced   Healthy
baba-app-identity-dev   phase-09-identity   Synced   Healthy
```

Committed Argo CD manifests both contain:

```text
targetRevision: main
```

This is the expected pre-merge state.

After squash merge:
1. Switch both live Argo applications to `main`.
2. Hard refresh both.
3. Confirm `Synced / Healthy`.
4. Run one final Terraform plan and confirm `No changes`.

## Phase 09 Security Outcome

```text
Human Identity
→ IAM Identity Center / IAM Role
→ EKS Access Entry
→ Kubernetes Group
→ Namespace RBAC

Backend Workload
→ Kubernetes ServiceAccount
→ EKS Pod Identity
→ Dedicated IAM Role
→ Least-Privilege AWS Permission

Automation
→ GitHub OIDC
→ Dedicated Infrastructure Role
→ Narrow Terraform Permissions
→ No Kubernetes Cluster-Admin

Privileged Recovery
→ Federated Identity Center Admin
→ Explicit EKS Cluster-Admin
→ Break-Glass Procedure

Audit
→ EKS Control-Plane Logs
→ CloudWatch Retention
→ CloudTrail Management Events
→ KMS-Encrypted S3 Archive
```

## Interview Summary

> I implemented a layered identity and access model across AWS and Kubernetes. I removed inherited EKS cluster-admin privileges from the GitHub infrastructure automation role, created namespace-scoped Kubernetes RBAC for administrator, developer, and readonly access, and mapped dedicated IAM roles into those groups using EKS Access Entries. For workloads, I replaced shared/default identities with dedicated ServiceAccounts and implemented EKS Pod Identity for a narrowly scoped backend Secrets Manager use case. I validated both positive and negative authorization paths, proving that the backend received short-lived credentials while the frontend received no AWS credentials. I also defined a federated break-glass model using IAM Identity Center and added durable auditability through EKS control-plane logs and a multi-Region, KMS-encrypted CloudTrail trail. The final Terraform plan returned no changes, confirming the environment was reconciled and drift-free.

## Phase Closure Checklist

- [x] Automation cluster-admin privilege removed.
- [x] Human cluster-admin access preserved.
- [x] Namespace RBAC implemented.
- [x] GitOps drift protection validated.
- [x] Dedicated workload ServiceAccounts deployed.
- [x] EKS Pod Identity implemented.
- [x] Backend positive authorization test passed.
- [x] Frontend negative authorization test passed.
- [x] Human IAM roles mapped through EKS Access Entries.
- [x] Developer RBAC validated.
- [x] Readonly RBAC validated.
- [x] Namespace-admin RBAC validated.
- [x] Infrastructure automation permissions narrowed.
- [x] Break-glass runbook created.
- [x] EKS audit logging enabled.
- [x] EKS log retention set to 365 days.
- [x] CloudTrail management-event trail implemented.
- [x] CloudTrail S3/KMS controls validated.
- [x] Terraform final plan reports no changes.
- [x] Feature-branch Argo applications are Synced / Healthy.
- [x] Committed Argo manifests point to `main`.
- [ ] Phase 09 pull request merged into `main`.
- [ ] Live Argo applications switched back to `main`.
- [ ] Post-merge Argo state validated as Synced / Healthy.
- [ ] Final post-merge Terraform plan confirmed clean.

## Final Phase Status

**Ready for Pull Request and Squash Merge**
