# Phase 06 GitOps Validation

## Purpose

This document records Phase 06 GitOps validation. Validation is divided into local configuration validation and live EKS/Argo CD validation.

## Validation Status

| Validation Area | Status |
|---|---|
| Kustomize base rendering | PASS |
| Kustomize dev overlay rendering | PASS |
| Namespace declaration | PASS |
| Placeholder image removal | PASS |
| Immutable backend image digest | PASS |
| Immutable frontend image digest | PASS |
| Argo CD AppProject YAML syntax | PASS |
| Argo CD Application YAML syntax | PASS |
| Git whitespace validation | PASS |
| Argo CD installation | PENDING LIVE VALIDATION |
| AppProject creation | PENDING LIVE VALIDATION |
| Application creation | PENDING LIVE VALIDATION |
| Argo CD synchronization | PENDING LIVE VALIDATION |
| Backend workload health | PENDING LIVE VALIDATION |
| Frontend workload health | PENDING LIVE VALIDATION |
| Runtime image digest verification | PENDING LIVE VALIDATION |
| Drift detection | PENDING LIVE VALIDATION |
| Self-healing | PENDING LIVE VALIDATION |
| Pruning | PENDING LIVE VALIDATION |

## Local Validation

### Kustomize Base

```bash
kubectl kustomize 06-gitops/manifests/base
```

Result:

```text
PASS
```

### Kustomize Deprecation Remediation

Initial rendering reported that `commonLabels` was deprecated. The configuration was updated to current `labels` syntax and the warning was removed.

Result:

```text
PASS
```

### Development Overlay

```bash
kubectl kustomize 06-gitops/manifests/overlays/dev
```

Result:

```text
PASS
```

The overlay rendered the `baba-app` Namespace, Services, Deployments, development labels, and immutable ECR image references.

### Placeholder Check

```bash
kubectl kustomize 06-gitops/manifests/overlays/dev | grep placeholder
```

Observed result:

```text
No output
```

Status:

```text
PASS
```

### Immutable Image Check

```bash
kubectl kustomize 06-gitops/manifests/overlays/dev | grep "image:"
```

Backend:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-backend@sha256:88f9c5203ea301c780029f7b9a62d3c0777d4d037ed7738093777b723d2a7a74
```

Frontend:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-frontend@sha256:de401212938d47baddf5432aa54c6ce0ce0eb193f488706126003163a898f59b
```

Status:

```text
PASS
```

### Argo CD YAML Validation

Because the former EKS endpoint is offline, `kubectl` API discovery could not validate the custom resources. Local YAML parsing was used instead:

```bash
for f in   06-gitops/argocd/projects/baba-app-project.yaml   06-gitops/argocd/applications/baba-app-dev.yaml
do
  ruby -e 'require "yaml"; YAML.load_file(ARGV[0]); puts "#{ARGV[0]}: valid"' "$f"
done
```

Observed result:

```text
06-gitops/argocd/projects/baba-app-project.yaml: valid
06-gitops/argocd/applications/baba-app-dev.yaml: valid
```

Status:

```text
PASS
```

### Git Whitespace Validation

```bash
git diff --check
```

Observed result:

```text
No output
```

Status:

```text
PASS
```

## Live Validation Plan

### Recreate EKS

Expected:

```text
EKS control plane available
worker nodes available
kubectl connectivity restored
```

Status: `PENDING`

### Install Argo CD

Install into `argocd` and verify components are healthy.

Status: `PENDING`

### Apply AppProject

```text
06-gitops/argocd/projects/baba-app-project.yaml
```

Expected:

```text
AppProject/baba-app created
```

Status: `PENDING`

### Apply Application

```text
06-gitops/argocd/applications/baba-app-dev.yaml
```

Expected:

```text
Application/baba-app-dev created
```

Status: `PENDING`

### Validate Sync and Health

Expected:

```text
Sync Status: Synced
Health Status: Healthy
```

Status: `PENDING`

### Validate Workloads

```bash
kubectl get pods -n baba-app
```

Expected backend and frontend replicas Ready.

Status: `PENDING`

### Validate Runtime Digests

Confirm running Pods use the exact Phase 05 backend and frontend digests.

Status: `PENDING`

## Drift Detection Test

Introduce deliberate drift:

```bash
kubectl scale deployment baba-app-backend   --replicas=5   -n baba-app
```

Git declares 2 replicas.

Expected flow:

```text
Actual state changes to 5
        ↓
Argo CD detects drift
        ↓
Application becomes OutOfSync
        ↓
Self-healing begins
        ↓
Deployment returns to 2 replicas
        ↓
Application returns to Synced
```

Status: `PENDING`

## Pruning Test

A temporary Git-managed Kubernetes resource will be introduced and then removed through the approved Git workflow.

Expected flow:

```text
Resource exists in cluster
        ↓
Resource removed from Git
        ↓
Argo CD detects desired-state change
        ↓
Argo CD prunes resource
        ↓
Resource no longer exists
```

Status: `PENDING`

## Evidence to Capture

- Terraform EKS creation result
- kubectl connectivity
- Argo CD component health
- AppProject details
- Application details
- sync and health status
- workload Pods
- runtime image digests
- drift detection evidence
- self-healing evidence
- pruning evidence
- troubleshooting events

## Phase Completion Criteria

```text
Local manifest validation        PASS
Argo CD installed                PASS
AppProject validated             PASS
Application validated            PASS
GitOps synchronization           PASS
Application workloads healthy    PASS
Immutable images verified        PASS
Drift detection                  PASS
Self-healing                     PASS
Pruning                          PASS
Documentation updated            PASS
```

Until live validation is complete, the GitOps design is locally implemented but not fully validated against the runtime environment.