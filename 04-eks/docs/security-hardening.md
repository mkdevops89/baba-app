# Phase 04 - Kubernetes Security Hardening

## Purpose

This document records the Kubernetes security hardening performed during Phase 04 of Baba App.

The objective was to identify workload-level security gaps in the frontend and backend Kubernetes manifests, remediate the findings, validate application stability after hardening, and confirm the final configuration with Checkov and Trivy.

---

## Initial Security Scan

The initial Kubernetes manifest scans identified multiple findings in both the backend and frontend Deployments.

The Services and namespace did not require remediation, but both application Deployments were missing several explicit workload-security controls.

Initial findings included:

- Privilege escalation not explicitly disabled
- Containers not explicitly configured to run as non-root
- Pod and container security contexts not defined
- Linux capabilities not dropped
- `NET_RAW` capability not explicitly removed
- Seccomp profile not configured
- Root filesystem writable
- Service account token automatically mounted
- High UID/GID not explicitly enforced
- Container images referenced by tag rather than immutable digest
- Image pull policy set to `IfNotPresent`

These findings were reviewed individually rather than blindly suppressed.

---

## Hardening Strategy

The Phase 04 workload-hardening approach followed these principles:

- Apply least privilege
- Explicitly define pod and container security contexts
- Prevent privilege escalation
- Run workloads as non-root
- Remove unnecessary Linux capabilities
- Use the runtime-default seccomp profile
- Keep the container root filesystem read-only
- Allow writable storage only where the application requires it
- Prevent unnecessary Kubernetes API credential exposure
- Pin deployed images to immutable SHA256 digests
- Maintain CPU and memory resource controls
- Preserve application availability while security controls are introduced

---

## Pod Security Context

Both frontend and backend pods were configured with an explicit pod-level security context.

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  seccompProfile:
    type: RuntimeDefault
```

### Why This Matters

`runAsNonRoot: true` prevents the workload from running as the root user.

The explicit user and group IDs provide a consistent non-root execution identity.

The `RuntimeDefault` seccomp profile restricts the Linux system calls available to the container using the container runtime's default security profile.

---

## Container Security Context

Both application containers were configured with:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

This establishes explicit container-level restrictions instead of relying on Kubernetes defaults.

---

## Privilege Escalation Protection

The following control was enabled:

```yaml
allowPrivilegeEscalation: false
```

This prevents a process inside the container from gaining more privileges than its parent process.

The control reduces the impact of a compromised application process and supports least-privilege execution.

---

## Non-Root Execution

Both frontend and backend containers are required to run as non-root:

```yaml
runAsNonRoot: true
runAsUser: 65532
runAsGroup: 65532
```

The Baba App Phase 02 container images already use distroless non-root runtime images, so the Kubernetes configuration reinforces the container-image security model.

---

## Linux Capability Hardening

All default Linux capabilities are dropped:

```yaml
capabilities:
  drop:
    - ALL
```

The applications do not require additional Linux capabilities for normal operation.

Dropping all capabilities reduces the number of privileged kernel operations available to a compromised process.

This also remediated findings related to:

- Assigned Linux capabilities
- `NET_RAW`
- Excess container privileges

No capabilities were added back.

---

## Seccomp Hardening

The pod security context explicitly enables:

```yaml
seccompProfile:
  type: RuntimeDefault
```

Seccomp reduces the available Linux system-call surface for the application containers.

Using `RuntimeDefault` provides a practical baseline without maintaining a custom seccomp profile during this development phase.

---

## Read-Only Root Filesystem

The frontend and backend containers use:

```yaml
readOnlyRootFilesystem: true
```

A read-only root filesystem prevents the running application from modifying the container filesystem.

This helps limit:

- Runtime tampering
- Dropping malicious executables
- Unauthorized configuration changes
- Persistence inside the container filesystem

---

## Controlled Writable Temporary Storage

When the read-only root filesystem was first enabled for the backend, the new pod entered a crash loop.

The application required writable temporary storage during startup.

Rather than disabling the security control, a dedicated Kubernetes `emptyDir` volume was introduced:

```yaml
volumes:
  - name: tmp
    emptyDir: {}
```

The volume was mounted only at:

```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
```

The same pattern was applied to the frontend workload.

The resulting model is:

```text
Read-only root filesystem
          +
Writable /tmp only
```

This preserves filesystem immutability while allowing required temporary application writes.

---

## Service Account Token Hardening

Neither application workload requires direct access to the Kubernetes API.

Automatic service account token mounting was therefore disabled:

```yaml
automountServiceAccountToken: false
```

This prevents unnecessary Kubernetes API credentials from being placed inside the application pods.

The control reduces credential exposure if an application container is compromised.

---

## Resource Controls

Both Deployments define CPU and memory requests and limits.

Example pattern:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

Resource controls support:

- Predictable scheduling
- Resource isolation
- Cluster stability
- Protection against uncontrolled container resource consumption

The exact frontend and backend memory values differ based on application requirements.

---

## Image Pull Policy

The original manifests used:

```yaml
imagePullPolicy: IfNotPresent
```

This was changed to:

```yaml
imagePullPolicy: Always
```

This ensures the node checks the registry when starting the workload.

The final deployment also uses digest-pinned images, so the image content itself remains immutable.

---

## Image Digest Pinning

The original Kubernetes manifests referenced images using tags such as:

```text
phase4-amd64
```

Checkov identified that the Deployments were not pinned to immutable image digests.

The manifests were updated to use the form:

```text
<ecr-repository>@sha256:<digest>
```

Digest pinning ensures Kubernetes deploys the exact container artifact that was tested and approved.

This protects against ambiguity that can occur when using image tags alone.

---

## Container Architecture Remediation

The initial Phase 04 images were built on an Apple Silicon workstation and were incompatible with the EKS worker-node architecture.

The pods failed with:

```text
no match for platform in manifest: not found
```

The images were rebuilt explicitly for:

```text
linux/amd64
```

The corrected images were then pushed to Amazon ECR and successfully deployed.

This issue was not a Kubernetes security failure, but it became part of the overall deployment-hardening workflow because the final immutable digests needed to reference the correct validated architecture.

---

## Health Probe Security Considerations

Backend health probes use:

```text
/api/products
```

The backend root path returned:

```text
HTTP 403
```

because of the application security configuration.

A known healthy application endpoint was therefore selected for both readiness and liveness validation.

Frontend health probes use:

```text
/login
```

because the root route redirects to `/login`.

The probes verify application health without weakening application access controls.

---

## Backend Hardening Validation

After the initial security-context changes, one new backend pod failed to become Ready and entered:

```text
CrashLoopBackOff
```

The rollout remained partially available because Kubernetes retained the previously healthy replicas.

The issue was resolved by adding controlled writable `/tmp` storage while retaining:

```yaml
readOnlyRootFilesystem: true
```

After remediation, both backend replicas reached:

```text
1/1 Running
```

with:

```text
0 Restarts
```

---

## Frontend Hardening Validation

The same security controls were then applied to the frontend Deployment.

The hardened frontend successfully rolled out with both replicas reaching:

```text
1/1 Running
```

with:

```text
0 Restarts
```

This confirmed that the non-root execution, read-only filesystem, seccomp, capability, and temporary-storage controls were compatible with the Next.js workload.

---

## Checkov Validation

Before workload hardening, Checkov reported multiple Kubernetes Deployment failures.

After the security controls were applied, the remaining failures were limited to image digest pinning.

Once both frontend and backend images were pinned by SHA256 digest, the final Checkov result was:

```text
Passed checks: 178
Failed checks: 0
Skipped checks: 0
```

This included successful validation of controls related to:

- Non-root execution
- Security contexts
- Privilege escalation
- Linux capabilities
- Seccomp
- Read-only root filesystem
- Service account tokens
- CPU requests
- CPU limits
- Memory requests
- Memory limits
- Readiness probes
- Liveness probes
- Fixed image references
- Image digest pinning
- Image pull policy

---

## Trivy Validation

The initial Trivy scan reported 12 Kubernetes misconfigurations for each application Deployment.

After remediation, the final Trivy scan reported:

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

## Final Security Controls

The final Phase 04 application workloads include:

- Dedicated `baba-app` namespace
- Non-root container execution
- Explicit high UID/GID
- `RuntimeDefault` seccomp profile
- Privilege escalation disabled
- All Linux capabilities dropped
- Read-only root filesystems
- Explicit writable `/tmp` volumes
- Service account token automount disabled
- CPU requests and limits
- Memory requests and limits
- Readiness probes
- Liveness probes
- Internal ClusterIP Services
- SHA256 image digest pinning
- `imagePullPolicy: Always`
- Private EKS worker nodes
- Multi-AZ workload placement

---

## Deferred Security Capabilities

Some controls are intentionally planned for later phases rather than being introduced prematurely in Phase 04.

Examples include:

- Kubernetes NetworkPolicies
- Pod Security Admission enforcement
- Runtime threat detection
- Kubernetes audit-log analytics
- Admission policy enforcement
- Image signing and verification
- Software supply-chain attestation
- Advanced workload identity
- Policy-as-code admission controls

These capabilities align with later Kubernetes security, supply-chain security, and monitoring phases.

---

## Security Outcome

Phase 04 moved the Baba App Kubernetes workloads from a functional baseline to a hardened deployment model.

The final configuration demonstrates:

- Least-privilege container execution
- Explicit security contexts
- Reduced Linux attack surface
- Immutable container filesystems
- Controlled temporary storage
- Reduced Kubernetes credential exposure
- Immutable image deployment
- Security scanning and remediation
- Validation of hardened workloads under live EKS conditions

Final security scan results:

```text
Checkov: 178 passed / 0 failed
Trivy:   0 misconfigurations
```

The Kubernetes workload-hardening objectives for Phase 04 are complete.
