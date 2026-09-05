# Phase 04 - Amazon EKS Foundation

## Overview

Phase 04 deploys Baba App to Amazon Elastic Kubernetes Service (Amazon EKS) using Terraform-managed infrastructure and hardened Kubernetes manifests.

This phase builds on the networking, security, and Amazon ECR foundation created in Phase 03. The application is deployed as separate frontend and backend workloads across private subnets in multiple Availability Zones.

The main goals of this phase are to:

- Provision an Amazon EKS cluster with Terraform
- Deploy managed worker nodes into private subnets
- Distribute workloads across multiple Availability Zones
- Deploy Baba App frontend and backend containers from Amazon ECR
- Configure internal Kubernetes service discovery
- Implement application health checks
- Apply Kubernetes workload security controls
- Pin container images to immutable SHA256 digests
- Validate application connectivity
- Scan Kubernetes manifests with Checkov and Trivy
- Preserve the environment as reproducible infrastructure while supporting cost-conscious teardown

---

## Phase Architecture

The Phase 04 architecture includes:

```text
                         AWS
                          |
                +-------------------+
                |    Amazon EKS     |
                | Kubernetes 1.36   |
                +---------+---------+
                          |
              +-----------+-----------+
              |                       |
       Private Subnet A         Private Subnet B
         us-east-1a               us-east-1b
              |                       |
       +------+------+         +------+------+
       | EKS Worker  |         | EKS Worker  |
       | t3.medium   |         | t3.medium   |
       +------+------+         +------+------+
              |                       |
       Backend / Frontend      Backend / Frontend
             Pods                    Pods
              \                       /
               \                     /
                +-------------------+
                | Kubernetes        |
                | ClusterIP Services|
                +-------------------+
```

The worker nodes do not have public IP addresses and run inside the private subnets created during Phase 03.

---

## Infrastructure Components

### Amazon EKS Cluster

The EKS cluster is provisioned with Terraform and configured with:

- Kubernetes version 1.36
- Private endpoint access enabled
- Public endpoint access enabled for controlled administration
- Public API access restricted to an approved `/32` CIDR
- Private subnet placement
- Managed worker nodes
- Amazon EKS control plane logging

The public endpoint remains enabled for the development environment so the cluster can be administered from an approved workstation.

The public endpoint is not open to `0.0.0.0/0`.

---

## EKS Control Plane Logging

The following EKS control plane logs are enabled:

- API server
- Audit
- Authenticator
- Controller Manager
- Scheduler

These logs provide visibility into cluster activity and support future security monitoring, audit, and incident-response phases.

---

## Managed Node Group

The EKS managed node group uses:

- Instance type: `t3.medium`
- Desired capacity: 2 nodes
- Minimum capacity: 1 node
- Maximum capacity: 3 nodes
- Private subnet placement
- Multi-AZ deployment

The two active worker nodes were successfully distributed across:

- `us-east-1a`
- `us-east-1b`

The nodes do not have public IP addresses.

---

## Application Workloads

Baba App is deployed as two independent Kubernetes Deployments.

### Backend

The backend runs the Spring Boot application.

Configuration:

- 2 replicas
- Container port `8080`
- Internal ClusterIP Service
- Readiness probe
- Liveness probe
- CPU requests and limits
- Memory requests and limits
- Hardened security context
- SHA256-pinned container image

Backend health endpoint:

```text
/api/products
```

---

### Frontend

The frontend runs the Next.js application.

Configuration:

- 2 replicas
- Container port `3000`
- Internal ClusterIP Service
- Readiness probe
- Liveness probe
- CPU requests and limits
- Memory requests and limits
- Hardened security context
- SHA256-pinned container image

Frontend health endpoint:

```text
/login
```

The root application path redirects to `/login`, so `/login` is used for Kubernetes health validation.

---

## Kubernetes Namespace

Application resources are deployed into a dedicated namespace:

```text
baba-app
```

This keeps Baba App workloads logically separated from Kubernetes system components such as:

```text
kube-system
```

---

## Service Architecture

Both application services use:

```text
ClusterIP
```

The backend service listens internally on:

```text
8080
```

The frontend service listens internally on:

```text
3000
```

Neither service is directly exposed to the public internet during this phase.

This avoids creating an unnecessary AWS Load Balancer while the application is being validated in the development environment.

Public ingress and external traffic management can be introduced in a later phase.

---

## Amazon ECR Integration

Frontend and backend container images are stored in Amazon Elastic Container Registry.

Repositories:

```text
baba-app-dev-backend
baba-app-dev-frontend
```

The ECR repositories were created in Phase 03 with:

- Immutable image tags
- Image scanning
- KMS encryption
- Lifecycle management

Kubernetes Deployments reference images using immutable SHA256 digests rather than relying only on image tags.

Example:

```text
repository@sha256:<image-digest>
```

Digest pinning ensures Kubernetes deploys the exact container artifact that was validated.

---

## Container Architecture Compatibility

The initial Phase 04 images were built locally on an Apple Silicon Mac.

Those images were built for:

```text
linux/arm64
```

The EKS worker nodes use:

```text
linux/amd64
```

This caused Kubernetes to return:

```text
no match for platform in manifest: not found
```

The containers were rebuilt explicitly for the worker-node architecture:

```text
linux/amd64
```

The corrected images were then pushed to Amazon ECR and successfully deployed to EKS.

This validation demonstrated the importance of matching container image architecture to the Kubernetes worker-node architecture.

---

## Health Checks

Both application Deployments include Kubernetes readiness and liveness probes.

### Readiness Probes

Readiness probes determine whether a pod is ready to receive traffic.

Backend:

```text
GET /api/products
```

Frontend:

```text
GET /login
```

A pod is added to its Kubernetes Service only after its readiness probe succeeds.

---

### Liveness Probes

Liveness probes verify that the application remains responsive after startup.

If a liveness probe repeatedly fails, Kubernetes can restart the affected container.

This improves workload resilience and self-healing behavior.

---

## Kubernetes Security Hardening

Both frontend and backend workloads use explicit security controls.

### Non-Root Execution

Containers are configured to run as a non-root user:

```yaml
runAsNonRoot: true
runAsUser: 65532
runAsGroup: 65532
```

---

### Seccomp

The Kubernetes runtime default seccomp profile is enabled:

```yaml
seccompProfile:
  type: RuntimeDefault
```

This limits the Linux system calls available to the container.

---

### Privilege Escalation

Privilege escalation is disabled:

```yaml
allowPrivilegeEscalation: false
```

---

### Linux Capabilities

All unnecessary Linux capabilities are removed:

```yaml
capabilities:
  drop:
    - ALL
```

---

### Read-Only Root Filesystem

The container root filesystem is configured as read-only:

```yaml
readOnlyRootFilesystem: true
```

This reduces the ability of a compromised application to modify the container filesystem.

---

## Writable Temporary Storage

During backend hardening, the Spring Boot application required writable temporary storage.

Instead of disabling the read-only root filesystem, a Kubernetes `emptyDir` volume was mounted at:

```text
/tmp
```

This allows temporary application writes while keeping the rest of the container filesystem read-only.

The resulting design is:

```text
Read-only container root filesystem
                +
Explicit writable /tmp volume
```

This preserves the stronger security control while maintaining application functionality.

The same temporary-storage pattern is used for the frontend workload.

---

## Service Account Token Hardening

The application does not need direct access to the Kubernetes API.

Automatic service account token mounting is therefore disabled:

```yaml
automountServiceAccountToken: false
```

This reduces unnecessary credential exposure inside application containers.

---

## Resource Management

CPU and memory requests and limits are configured for both workloads.

This improves:

- Kubernetes scheduling
- Resource isolation
- Cluster stability
- Protection against uncontrolled resource consumption

---

## Security Scanning

Kubernetes manifests were scanned using:

- Checkov
- Trivy

Initial scans identified multiple workload-hardening issues, including:

- Missing security contexts
- Privilege escalation
- Missing seccomp profiles
- Missing non-root enforcement
- Linux capabilities
- Writable root filesystems
- Automatic service account token mounting
- Container image digest pinning

The findings were remediated and the manifests were rescanned.

### Final Checkov Result

```text
Passed checks: 178
Failed checks: 0
Skipped checks: 0
```

### Final Trivy Result

```text
0 Kubernetes misconfigurations
```

---

## Application Validation

The final Kubernetes environment contained:

```text
Backend Deployment:   2/2 Ready
Frontend Deployment:  2/2 Ready
```

All four application pods were:

```text
1/1 Running
```

with:

```text
0 Restarts
```

Workloads were distributed across both EKS worker nodes and Availability Zones.

---

## Backend Connectivity Validation

The backend was tested through its Kubernetes Service:

```text
http://baba-app-backend:8080/api/products
```

Result:

```text
HTTP 200
```

The endpoint successfully returned the Baba App product catalog.

---

## Frontend Connectivity Validation

The frontend was tested through its Kubernetes Service:

```text
http://baba-app-frontend:3000/login
```

Result:

```text
HTTP 200
```

This confirmed that Kubernetes DNS, service discovery, pod networking, and application routing were functioning correctly.

---

## Repository Structure

Phase 04 resources are organized as:

```text
03-terraform/
└── modules/
    └── eks/
        ├── main.tf
        ├── outputs.tf
        └── variables.tf

04-eks/
├── README.md
├── docs/
└── manifests/
    ├── backend/
    │   ├── deployment.yaml
    │   └── service.yaml
    ├── frontend/
    │   ├── deployment.yaml
    │   └── service.yaml
    └── namespaces/
        └── baba-app.yaml
```

The EKS infrastructure remains part of the Terraform foundation while Kubernetes application resources are maintained under the dedicated Phase 04 directory.

---

## Cost Management Strategy

The EKS environment is treated as an ephemeral development environment.

Once implementation, validation, documentation, and security scanning are complete, the EKS-specific resources can be removed to reduce AWS costs.

The Phase 04 teardown is designed to remove:

- Amazon EKS control plane
- EKS managed node group
- Worker EC2 instances

while retaining the Phase 03 foundation, including:

- VPC
- Public and private subnets
- NAT Gateway
- Amazon ECR repositories
- VPC Flow Logs
- Terraform remote state infrastructure

A full Terraform destroy should not be used when only the Phase 04 EKS resources need to be removed.

---

## Security Decisions

Some EKS infrastructure findings are intentionally documented rather than blindly suppressed.

### EKS Public API Endpoint

The EKS public endpoint remains enabled in the development environment.

Mitigations include:

- Private endpoint access is enabled
- Public access is restricted to an approved `/32`
- The API is not open to `0.0.0.0/0`

A production environment would preferably use private-only cluster administration through an approved private access path.

---

### Kubernetes Secrets Encryption

Modern EKS versions automatically provide encryption for Kubernetes API data, including Kubernetes Secrets.

A customer-managed KMS key is not introduced solely to satisfy a static-analysis rule in the development environment.

A dedicated customer-managed key may be appropriate for production or compliance-driven environments.

---

## Phase Outcome

Phase 04 successfully established a secure Amazon EKS foundation for Baba App.

The phase demonstrates:

- Infrastructure as Code with Terraform
- Private Kubernetes worker nodes
- Multi-AZ workload deployment
- Amazon ECR integration
- Kubernetes service discovery
- Health monitoring
- Container architecture troubleshooting
- Kubernetes workload hardening
- Immutable image deployment
- Static security scanning
- Security remediation
- Cost-aware cloud engineering

The resulting Kubernetes manifests completed final validation with:

```text
Checkov: 178 passed / 0 failed
Trivy:   0 misconfigurations
```

Phase 04 is ready for documentation closure, source-control merge, and controlled EKS teardown.
