# Phase 06 GitOps Architecture

## Purpose

This document describes the Baba App GitOps architecture for deploying to Amazon EKS with Argo CD and Kustomize.

## Design Principle

> CI builds and verifies artifacts. GitOps declares and reconciles deployment state.

GitHub Actions remains the CI platform. Argo CD becomes the Kubernetes deployment and reconciliation controller.

## End-to-End Flow

```text
Developer
  |
  v
GitHub
  |
  v
GitHub Actions
  |-- Build / lint / available tests
  |-- Gitleaks / CodeQL / SCA
  |-- IaC and Kubernetes scans
  |-- Container scan
  |-- SBOM / provenance / signing
  v
Amazon ECR
  |
  v
Immutable SHA256 digest
  |
  v
GitOps desired state
  |
  v
Kustomize
  |
  v
Argo CD
  |
  v
Amazon EKS
```

## CI/CD Separation

### Continuous Integration

Phase 05 produces trusted immutable artifacts in ECR through security scanning, SBOM generation, signing, and provenance.

### Continuous Deployment

Phase 06 lets Argo CD:

- read desired state from Git
- render Kustomize overlays
- compare desired vs actual state
- synchronize resources
- detect drift
- self-heal drift
- prune resources removed from Git

## Git as Source of Truth

Repository:

```text
https://github.com/mkdevops89/baba-app.git
```

Revision:

```text
main
```

Path:

```text
06-gitops/manifests/overlays/dev
```

Feature branches are used for development and PR validation. Argo CD consumes reviewed state from `main`.

## Kustomize Model

```text
manifests/
├── base/
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   └── kustomization.yaml
└── overlays/dev/
    ├── namespace.yaml
    └── kustomization.yaml
```

The base defines shared resources. The dev overlay declares the namespace, environment label, and exact ECR digests.

## Immutable Artifact Flow

Backend digest:

```text
sha256:88f9c5203ea301c780029f7b9a62d3c0777d4d037ed7738093777b723d2a7a74
```

Frontend digest:

```text
sha256:de401212938d47baddf5432aa54c6ce0ce0eb193f488706126003163a898f59b
```

```text
Source Commit
    ↓
GitHub Actions
    ↓
Security Validation
    ↓
ECR Image
    ↓
Immutable Digest
    ↓
GitOps Manifest
    ↓
Argo CD
    ↓
EKS Workload
```

## AppProject Boundary

The `baba-app` AppProject permits only:

```text
Source: https://github.com/mkdevops89/baba-app.git
Destination cluster: https://kubernetes.default.svc
Destination namespace: baba-app
Namespace resources: Deployment, Service
Cluster resources: Namespace
```

This avoids the unrestricted default-project pattern.

## Application

```text
Name: baba-app-dev
Project: baba-app
Revision: main
Path: 06-gitops/manifests/overlays/dev
Destination: baba-app namespace
```

Automated sync:

```yaml
automated:
  prune: true
  selfHeal: true
```

## Drift Detection and Self-Healing

If Git declares `replicas: 2` but someone manually scales to 5, Argo CD should detect the divergence and restore the Git-declared count.

## Pruning

When a managed resource is intentionally removed from Git, Argo CD should remove that resource from the cluster when pruning is enabled.

## Namespace Management

The `baba-app` namespace is explicitly declared in Git and the Application uses:

```text
CreateNamespace=false
```

## Security Benefits

- separation of CI and CD
- less dependence on CI-held Kubernetes credentials
- Git-based audit trail
- PR-reviewed deployment changes
- restricted source repository
- restricted destination namespace
- restricted resource types
- immutable container artifacts
- drift detection and correction
- no secrets stored directly in Git

## Future Enhancements

- NetworkPolicies
- Argo CD RBAC/SSO hardening
- policy-as-code
- admission-time artifact verification
- external secret management
- multi-environment promotion
- runtime threat detection