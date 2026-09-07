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
| Argo CD installation | PASS|
| AppProject creation | PASS |
| Application creation | PASS |
| Argo CD synchronization | PASS |
| Backend workload health | PASS |
| Frontend workload health | PASS |
| Runtime image digest verification | PASS |
| Drift detection | PASS |
| Self-healing | PASS |
| Pruning | PASS |

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

---

## Live GitOps Validation Results

### EKS Recreation

The development EKS environment was recreated through Terraform for Phase 06 live validation.

```text
Plan: 8 to add, 0 to change, 0 to destroy.
```

Cluster connectivity was restored with:

```bash
AWS_PROFILE=baba-admin aws eks update-kubeconfig \
  --region us-east-1 \
  --name baba-app-dev-eks
```

Both managed worker nodes reached `Ready`.

Validation status:

```text
PASS
```

---

## Argo CD Installation Validation

The initial client-side installation encountered:

```text
The CustomResourceDefinition "applicationsets.argoproj.io" is invalid:
metadata.annotations: Too long: may not be more than 262144 bytes
```

The installation was remediated using server-side apply:

```bash
kubectl apply \
  --server-side \
  --force-conflicts \
  -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

The following CRDs were verified:

```text
applications.argoproj.io
applicationsets.argoproj.io
appprojects.argoproj.io
```

All core Argo CD workloads reached `Running`.

Validation status:

```text
PASS
```

---

## Argo CD Application Synchronization

The committed Application is designed to reconcile from:

```text
main
```

For pre-merge live validation, the runtime Application was temporarily patched to:

```text
feature/gitops-foundation
```

Argo CD reported:

```text
Sync Status: Synced
Health Status: Healthy
```

Validation status:

```text
PASS
```

---

## Workload Health Validation

The GitOps deployment created:

```text
2 backend Pods
2 frontend Pods
```

All four Pods reached:

```text
Running
Ready 1/1
```

Backend and frontend Services remained:

```text
ClusterIP
```

Validation status:

```text
PASS
```

---

## Runtime Immutable Artifact Validation

Backend:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-backend@sha256:88f9c5203ea301c780029f7b9a62d3c0777d4d037ed7738093777b723d2a7a74
```

Frontend:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-frontend@sha256:de401212938d47baddf5432aa54c6ce0ce0eb193f488706126003163a898f59b
```

These matched the exact immutable Phase 05 artifacts.

Validation status:

```text
PASS
```

---

## Drift Detection and Self-Healing Validation

Git declared:

```text
replicas: 2
```

A manual out-of-band change was introduced:

```bash
kubectl scale deployment baba-app-backend \
  --replicas=5 \
  -n baba-app
```

Argo CD restored the Deployment to:

```text
desired=2
available=2
```

Final state:

```text
Synced
Healthy
```

Validation status:

```text
PASS
```

---

## AppProject Least-Privilege Enforcement Validation

A temporary ConfigMap was introduced through Git.

The Baba App `AppProject` permitted only:

```text
Deployment
Service
```

Argo CD rejected the ConfigMap with:

```text
resource :ConfigMap is not permitted in project baba-app
```

The whitelist was not weakened for the test.

Validation status:

```text
PASS
```

---

## Pruning Validation

A temporary Git-managed Service was created:

```text
baba-app-prune-test
```

Argo CD created it after the Git change.

The Service was then removed from Git.

Because the Application configures:

```yaml
prune: true
```

Argo CD automatically deleted it.

Final verification:

```text
Error from server (NotFound): services "baba-app-prune-test" not found
```

Validation status:

```text
PASS
```

---

## Phase 06 Live Validation Outcome

```text
EKS recreation                         PASS
Argo CD installation                   PASS
Argo CD CRDs                           PASS
AppProject creation                    PASS
Application creation                   PASS
Kustomize reconciliation               PASS
Application synchronization            PASS
Backend workload health                PASS
Frontend workload health               PASS
Immutable artifact deployment          PASS
Drift remediation / self-healing       PASS
AppProject least-privilege enforcement PASS
Automated pruning                      PASS
```

Phase 06 GitOps functionality has now been validated against the live Amazon EKS environment.

## Post-Merge Validation

After Phase 06 was merged into `main`, the live Argo CD Application was refreshed and successfully reconciled from the permanent branch.

Argo CD source:

```text
targetRevision: main
```

Reconciled revision:

```text
9bbdeaf86246d17a0c6f55013cc9ed8e3c551480
```

Final application state:

```text
Sync Status: Synced
Health Status: Healthy
```

Runtime workload state:

```text
Backend Pods:  2/2 Running
Frontend Pods: 2/2 Running
```

Backend image:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-backend@sha256:88f9c5203ea301c780029f7b9a62d3c0777d4d037ed7738093777b723d2a7a74
```

Frontend image:

```text
406312601212.dkr.ecr.us-east-1.amazonaws.com/baba-app-dev-frontend@sha256:de401212938d47baddf5432aa54c6ce0ce0eb193f488706126003163a898f59b
```

This confirmed that the permanent GitOps flow was operating from `main`, Argo CD successfully reconciled the approved desired state, all application workloads remained healthy, and the exact immutable Phase 05 artifacts continued to run in Amazon EKS.

Validation status:

```text
PASS
```
