# Phase 06 GitOps Security Controls

## Purpose

This document records the security controls introduced in the Baba App GitOps foundation.

## Control Summary

| Control | Status |
|---|---|
| Separation of CI and CD | Implemented and validated |
| Git as source of truth | Implemented and validated |
| Restricted Argo CD source repository | Implemented and validated |
| Restricted destination cluster/namespace | Implemented and validated |
| Restricted Kubernetes resource types | Implemented and validated |
| AppProject authorization enforcement | Implemented and validated |
| Immutable ECR image digests | Implemented and validated |
| No `latest` tag | Implemented and validated |
| Argo CD drift detection | Implemented and validated |
| Self-healing | Implemented and validated |
| Pruning | Implemented and validated |
| Namespace declared in Git | Implemented and validated |
| Service account token automount disabled | Implemented |
| Non-root workloads | Implemented |
| Privilege escalation disabled | Implemented |
| All Linux capabilities dropped | Implemented |
| Read-only root filesystem | Implemented |
| RuntimeDefault seccomp | Implemented |
| Resource requests/limits | Implemented |
| Liveness/readiness probes | Implemented |
| ClusterIP services | Implemented and validated |
| Secrets kept out of Git | Implemented |
| PR-reviewed change path | Implemented |

## Separation of CI and CD

GitHub Actions builds and verifies artifacts. Argo CD deploys and reconciles them. This reduces the need for CI to hold persistent Kubernetes credentials.

## Restricted Source Repository

Allowed source:

```text
https://github.com/mkdevops89/baba-app.git
```

This prevents the Baba App project from deploying arbitrary repositories.

## Restricted Destination

```text
Cluster: https://kubernetes.default.svc
Namespace: baba-app
```

This limits the deployment boundary to the intended cluster and namespace.

## Restricted Resource Types

Namespace-scoped resources:

```text
Deployment
Service
```

Cluster-scoped resource:

```text
Namespace
```

Wildcards are intentionally avoided.

## Immutable Artifacts

Backend:

```text
sha256:88f9c5203ea301c780029f7b9a62d3c0777d4d037ed7738093777b723d2a7a74
```

Frontend:

```text
sha256:de401212938d47baddf5432aa54c6ce0ce0eb193f488706126003163a898f59b
```

Digest deployment ties runtime state to the exact artifact scanned, signed, attested, and published in Phase 05.

## Drift Detection, Self-Healing, and Pruning

Configured Application behavior:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

Live validation confirmed drift detection, restoration of Git-declared state, and removal of obsolete managed resources.

## Kubernetes Workload Hardening

```yaml
automountServiceAccountToken: false
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

Container controls include:

```yaml
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
capabilities:
  drop:
    - ALL
```

The workloads also define resource requests/limits, liveness/readiness probes, ClusterIP services, and an explicit writable `/tmp` volume.

## Secrets Handling

No application credentials or Kubernetes Secret values are committed to Git in Phase 06. Advanced external secret management is deferred.

## Pull Request Change Path

Phase 06 is developed on:

```text
feature/gitops-foundation
```

Argo CD is configured to reconcile:

```text
main
```

This supports review before deployment-state changes are consumed by the GitOps controller.

## Deferred Controls

- Kubernetes NetworkPolicies
- Kyverno / OPA Gatekeeper
- admission-time signature verification
- external secrets
- production promotion approvals
- multi-environment promotion
- runtime security monitoring
- advanced Argo CD RBAC and SSO hardening

## Security Outcome

```text
Least privilege
+
Immutable artifacts
+
Git-based desired state
+
Declarative configuration
+
Drift detection
+
Automated reconciliation
+
Hardened Kubernetes workloads
```

## Separation of CI and CD

### Status

```text
IMPLEMENTED
VALIDATED
```

---

## Git as the Deployment Source of Truth

### Status

```text
IMPLEMENTED
VALIDATED
```

---

## Automated Drift Detection

### Status

```text
IMPLEMENTED
VALIDATED
```

---

## Self-Healing

### Control

```yaml
selfHeal: true
```

### Status

```text
IMPLEMENTED
VALIDATED
```

---

## Pruning

### Control

```yaml
prune: true
```

### Status

```text
IMPLEMENTED
VALIDATED
```

---

## AppProject Resource Authorization Enforcement

### Control

The Baba App AppProject restricts namespace-scoped resources to the types required by the application.

A temporary ConfigMap was intentionally introduced through Git during validation.

Argo CD rejected the resource with:

```text
resource :ConfigMap is not permitted in project baba-app
```

### Security Benefit

This demonstrates that the AppProject resource whitelist is actively enforced and prevents unauthorized Kubernetes resource types from being deployed through the Baba App GitOps project.

### Status

```text
IMPLEMENTED
VALIDATED
```
