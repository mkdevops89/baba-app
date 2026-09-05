# Phase 04 - Validation Report

## Purpose

This document records the validation performed for Phase 04 of Baba App after provisioning Amazon EKS, deploying the frontend and backend workloads, applying Kubernetes security hardening, and validating application connectivity.

The objective was to confirm that the infrastructure, Kubernetes workloads, service discovery, health checks, container architecture, and security controls were functioning as expected before closing the phase.

---

## EKS Cluster Validation

The Amazon EKS cluster was successfully provisioned with Terraform.

Validated cluster characteristics:

- Cluster name: `baba-app-dev-eks`
- Kubernetes version: `1.36`
- Cluster status: `ACTIVE`
- Managed node group: `baba-app-dev-nodes`
- Worker node instance type: `t3.medium`
- Desired capacity: `2`
- Minimum capacity: `1`
- Maximum capacity: `3`

The cluster control plane was reachable using the configured AWS CLI SSO profile and Kubernetes context.

---

## Worker Node Validation

Two worker nodes were successfully registered with the cluster.

The nodes were distributed across separate private subnets and Availability Zones:

- `us-east-1a`
- `us-east-1b`

Both nodes reported:

```text
Ready
```

The nodes did not have public IP addresses.

This confirmed that the managed node group was operating in the private network design created during Phase 03.

---

## Kubernetes System Validation

Core Kubernetes system components were verified in the `kube-system` namespace.

Validated components included:

- Amazon VPC CNI
- CoreDNS
- kube-proxy

All required system pods were running successfully.

---

## Namespace Validation

A dedicated application namespace was created:

```text
baba-app
```

The namespace reached:

```text
Active
```

This provided logical separation between Baba App workloads and Kubernetes system resources.

---

## Container Registry Validation

Backend and frontend images were pushed to Amazon ECR.

Repositories:

```text
baba-app-dev-backend
baba-app-dev-frontend
```

The initial images used the `phase4` tag.

After discovering an architecture mismatch, the images were rebuilt for the EKS worker node architecture and pushed using:

```text
phase4-amd64
```

The final Kubernetes manifests reference the validated images using immutable SHA256 digests.

---

## Container Architecture Validation

The development workstation used Apple Silicon and initially produced:

```text
linux/arm64
```

container images.

The EKS worker nodes required:

```text
linux/amd64
```

The original backend deployment failed with:

```text
no match for platform in manifest: not found
```

The issue was remediated by rebuilding the backend and frontend images explicitly with:

```text
--platform linux/amd64
```

The corrected images were pushed to Amazon ECR and successfully deployed.

---

## Backend Deployment Validation

The backend Kubernetes Deployment was configured with:

- 2 replicas
- Container port `8080`
- Internal ClusterIP Service
- Readiness probe
- Liveness probe
- CPU and memory requests
- CPU and memory limits
- Non-root execution
- Read-only root filesystem
- RuntimeDefault seccomp profile
- Dropped Linux capabilities
- Service account token automount disabled
- SHA256-pinned image

Final deployment status:

```text
NAME               READY   UP-TO-DATE   AVAILABLE
baba-app-backend   2/2     2            2
```

Both backend pods reached:

```text
1/1 Running
```

with:

```text
0 Restarts
```

---

## Frontend Deployment Validation

The frontend Kubernetes Deployment was configured with:

- 2 replicas
- Container port `3000`
- Internal ClusterIP Service
- Readiness probe
- Liveness probe
- CPU and memory requests
- CPU and memory limits
- Non-root execution
- Read-only root filesystem
- RuntimeDefault seccomp profile
- Dropped Linux capabilities
- Service account token automount disabled
- SHA256-pinned image

Final deployment status:

```text
NAME                READY   UP-TO-DATE   AVAILABLE
baba-app-frontend   2/2     2            2
```

Both frontend pods reached:

```text
1/1 Running
```

with:

```text
0 Restarts
```

---

## Multi-AZ Workload Validation

The final backend and frontend pods were distributed across both EKS worker nodes.

This confirmed that application workloads were successfully scheduled across:

```text
us-east-1a
us-east-1b
```

The deployment therefore demonstrated multi-AZ workload placement within the development cluster.

---

## Backend Service Validation

The backend service was configured as:

```text
Type: ClusterIP
Port: 8080
```

The service successfully resolved the backend pods through Kubernetes service discovery.

The backend product endpoint was tested from inside the cluster:

```text
http://baba-app-backend:8080/api/products
```

Result:

```text
HTTP 200
```

The endpoint returned the Baba App product catalog successfully.

The root backend path returned:

```text
HTTP 403
```

This was expected based on the application security configuration and was not used as the health-check endpoint.

---

## Frontend Service Validation

The frontend service was configured as:

```text
Type: ClusterIP
Port: 3000
```

The frontend service was tested from inside the cluster using:

```text
http://baba-app-frontend:3000/login
```

Result:

```text
HTTP 200
```

The root route was also observed to redirect to:

```text
/login
```

with:

```text
HTTP 307
```

The `/login` route was therefore selected for Kubernetes readiness and liveness validation.

---

## Kubernetes Service Discovery Validation

Both application services successfully registered their pod endpoints.

Backend service endpoints resolved to both backend pods.

Frontend service endpoints resolved to both frontend pods.

This confirmed:

- Kubernetes DNS
- ClusterIP routing
- Pod-to-service connectivity
- Multi-replica service registration

For newer Kubernetes versions, `EndpointSlice` should be preferred over the deprecated legacy `Endpoints` API for future inspection.

---

## Readiness Probe Validation

Backend readiness probe:

```text
GET /api/products
Port 8080
```

Frontend readiness probe:

```text
GET /login
Port 3000
```

The readiness probes successfully transitioned the pods to:

```text
Ready
```

This confirmed that traffic would only be routed to healthy application pods.

---

## Liveness Probe Validation

Backend liveness probe:

```text
GET /api/products
Port 8080
```

Frontend liveness probe:

```text
GET /login
Port 3000
```

After final hardening, all pods remained healthy with:

```text
0 Restarts
```

This confirmed that the liveness configuration did not introduce false-positive restarts.

---

## Read-Only Filesystem Validation

The backend initially failed after enabling:

```yaml
readOnlyRootFilesystem: true
```

The Spring Boot application required writable temporary storage.

The issue was remediated by mounting an `emptyDir` volume at:

```text
/tmp
```

The root filesystem remained read-only while the application retained access to temporary storage.

After the change, both backend replicas successfully reached:

```text
1/1 Running
```

The same controlled writable temporary-storage pattern was applied to the frontend.

---

## Final Pod Validation

Final application state:

```text
Backend replicas:   2/2 Ready
Frontend replicas:  2/2 Ready
Total app pods:     4
Running pods:       4
Restarts:           0
```

This confirmed that the final hardened workload configuration was stable.

---

## Security Scan Validation

### Checkov

The final Kubernetes manifest scan returned:

```text
Passed checks: 178
Failed checks: 0
Skipped checks: 0
```

This confirmed that all Checkov Kubernetes checks evaluated for the Phase 04 manifests passed.

### Trivy

The final Trivy configuration scan returned:

```text
Backend Deployment:   0 misconfigurations
Backend Service:      0 misconfigurations
Frontend Deployment:  0 misconfigurations
Frontend Service:     0 misconfigurations
Namespace:            0 misconfigurations
```

Final result:

```text
0 Kubernetes misconfigurations
```

---

## Final Validation Summary

Phase 04 validation confirmed that:

- The EKS cluster was active and reachable
- Two worker nodes were healthy
- Worker nodes were deployed in private subnets
- Worker nodes were distributed across two Availability Zones
- Kubernetes system components were healthy
- The application namespace was active
- Backend and frontend images were available in Amazon ECR
- Container architecture matched the EKS worker nodes
- Backend and frontend Deployments reached full availability
- All four application pods were running with zero restarts
- Kubernetes ClusterIP service discovery worked
- Backend API connectivity returned HTTP 200
- Frontend connectivity returned HTTP 200
- Readiness and liveness probes worked correctly
- Read-only filesystem hardening remained enabled
- Required temporary storage was isolated to `/tmp`
- Images were pinned using SHA256 digests
- Checkov completed with 178 passed and 0 failed
- Trivy completed with 0 Kubernetes misconfigurations

---

## Phase Validation Outcome

Phase 04 successfully met its infrastructure, application deployment, operational validation, and Kubernetes workload-security objectives.

The environment is ready for:

- Phase documentation closure
- Source-control commit and merge
- Controlled EKS teardown for cost management
- Reprovisioning later from Terraform and Kubernetes manifests
