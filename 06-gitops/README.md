# Phase 06 — GitOps with Argo CD and Kustomize

## Overview

Phase 06 introduces GitOps-based Kubernetes delivery for Baba App using Argo CD and Kustomize. Phase 05 builds, scans, signs, attests, and publishes immutable container images to Amazon ECR. Phase 06 declares the desired Kubernetes state in Git and allows Argo CD to reconcile that state into Amazon EKS.

> CI builds and verifies the artifact. GitOps deploys and reconciles the artifact.

## Phase Objectives

- Use Git as the source of truth for Kubernetes deployment state.
- Use Kustomize for reusable base manifests and environment-specific overlays.
- Deploy through Argo CD rather than direct CI-to-cluster deployment.
- Deploy immutable ECR image digests instead of mutable tags.
- Configure a restricted Argo CD `AppProject` and declarative `Application`.
- Enable automated synchronization, self-healing, and pruning.
- Validate drift detection and remediation.
- Preserve Phase 04 Kubernetes hardening.
- Keep secrets and sensitive values out of Git.

## Architecture

```text
Developer
    |
    v
GitHub Repository
    |
    v
GitHub Actions
    |
    +---- Build / Test / Scan
    +---- SBOM / Sign / Provenance
    |
    v
Amazon ECR
    |
    v
Immutable Image Digest
    |
    v
Git Deployment State
    |
    v
Argo CD
    |
    v
Amazon EKS
```

## Directory Structure

```text
06-gitops/
├── README.md
├── argocd/
│   ├── applications/baba-app-dev.yaml
│   ├── projects/baba-app-project.yaml
│   └── configuration/
├── manifests/
│   ├── base/
│   │   ├── backend-deployment.yaml
│   │   ├── backend-service.yaml
│   │   ├── frontend-deployment.yaml
│   │   ├── frontend-service.yaml
│   │   └── kustomization.yaml
│   └── overlays/dev/
│       ├── namespace.yaml
│       └── kustomization.yaml
└── docs/
    ├── architecture.md
    ├── security-controls.md
    └── validation.md
```

## Immutable Image Deployment

Backend:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-backend@sha256:88f9c5203ea301c780029f7b9a62d3c0777d4d037ed7738093777b723d2a7a74
```

Frontend:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-frontend@sha256:de401212938d47baddf5432aa54c6ce0ce0eb193f488706126003163a898f59b
```

Using digests ensures Kubernetes runs the exact artifacts scanned, signed, attested, and published in Phase 05.

## Argo CD Design

The `baba-app` AppProject restricts deployments to:

- repository: `https://github.com/mkdevops89/baba-app.git`
- cluster: `https://kubernetes.default.svc`
- namespace: `baba-app`
- namespace resources: `Deployment`, `Service`
- cluster resource: `Namespace`

The `baba-app-dev` Application reconciles `main` from:

```text
06-gitops/manifests/overlays/dev
```

with:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

## Kubernetes Security Controls

- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- drop all Linux capabilities
- `RuntimeDefault` seccomp
- `automountServiceAccountToken: false`
- CPU/memory requests and limits
- readiness and liveness probes
- ClusterIP services
- writable `/tmp` via `emptyDir`

## Local Validation

```bash
kubectl kustomize 06-gitops/manifests/base
kubectl kustomize 06-gitops/manifests/overlays/dev
kubectl kustomize 06-gitops/manifests/overlays/dev | grep placeholder
kubectl kustomize 06-gitops/manifests/overlays/dev | grep "image:"
git diff --check
```

## Live Validation Plan

1. Recreate EKS.
2. Install Argo CD.
3. Apply the AppProject.
4. Apply the Application.
5. Verify sync and health.
6. Verify backend/frontend Pods.
7. Verify exact runtime image digests.
8. Introduce deliberate drift.
9. Confirm self-healing.
10. Validate pruning with a temporary Git-managed resource.
11. Capture evidence.

## Deferred Controls

- NetworkPolicies
- Kyverno / OPA Gatekeeper
- admission-time signature enforcement
- external secret management
- production promotion approval gates
- multi-environment promotion
- runtime threat detection

## Phase Outcome

```text
Git = desired deployment state
Argo CD = reconciliation controller
Kustomize = environment configuration layer
ECR digest = immutable deployable artifact
EKS = runtime platform
```
