# Phase 08 — Observability and Centralized Logging Validation

## Overview

This document records the completed validation for Phase 08 — Observability for the Baba App platform.

Phase 08 demonstrates that the observability platform is functioning across metrics, dashboards, centralized logging, GitOps deployment, security controls, bounded resource usage, and reproducibility.

The implemented stack includes:

- Prometheus
- Grafana
- Alertmanager
- kube-state-metrics
- node-exporter
- Prometheus Operator
- Grafana Loki
- Grafana Alloy
- Spring Boot Actuator / Micrometer
- Argo CD GitOps delivery
- AWS-native telemetry through CloudWatch

The final evidence demonstrates not only that the components are running, but that they provide useful operational visibility and can be reproduced from version-controlled configuration.

---

## Validation Objectives

Phase 08 validation confirms that:

- observability components deploy successfully through GitOps
- Prometheus collects Kubernetes and application metrics
- Grafana queries Prometheus successfully
- dashboards display live platform and workload data
- application metrics are available through Spring Boot Actuator / Micrometer
- AWS-native telemetry remains available through CloudWatch
- operational logs are centralized through Grafana Alloy and Loki
- logs are searchable by namespace, workload, pod, and container metadata
- observability services are not unintentionally exposed publicly
- credentials and secrets are not committed to Git
- Kubernetes service accounts and RBAC follow least-privilege principles
- security scans pass or findings are explicitly documented
- retention and resource settings are bounded
- the environment can be reproduced from Git
- significant troubleshooting decisions are documented

---

## Repository Structure

Primary Phase 08 documentation:

```text
08-observability/
├── README.md
└── docs/
    ├── architecture.md
    ├── security-controls.md
    └── validation.md
```

GitOps resources are maintained separately under:

```text
06-gitops/
├── argocd/
│   ├── applications/
│   └── projects/
└── observability/
    ├── prometheus/
    ├── loki/
    └── alloy/
```

---

## Git Validation

Repository validation includes:

```bash
git status
git diff --check
```

Expected results:

- no whitespace errors
- no unintended files
- no plaintext credentials committed to Git
- only expected Phase 08 changes

Existing Gitleaks validation remains enabled.

---

## GitOps Validation

Observability resources are delivered through Argo CD.

Validated applications include:

```text
baba-app-observability
baba-app-loki
baba-app-alloy
```

Expected deployment namespace:

```text
observability
```

Validation confirmed:

- Argo CD recognizes the observability applications
- synchronization completes successfully
- automated prune and self-heal remain enabled where configured
- desired state is sourced from Git
- observability resources are constrained to the approved namespace
- Helm chart versions are explicitly pinned
- server-side apply is used where required for large CRDs

Representative commands:

```bash
argocd app list
argocd app get baba-app-observability
argocd app get baba-app-loki
argocd app get baba-app-alloy
kubectl get all -n observability
```

---

## Prometheus Validation

Prometheus is deployed through `kube-prometheus-stack`.

Validated components include:

- Prometheus
- Alertmanager
- kube-state-metrics
- node-exporter
- Prometheus Operator
- ServiceMonitors
- PrometheusRules

Representative validation:

```bash
kubectl get pods -n observability
kubectl get svc -n observability
```

Prometheus is exposed internally through `ClusterIP`.

No unintended public `LoadBalancer` or `NodePort` service is used.

Representative Prometheus queries include:

```promql
up
```

```promql
kube_pod_status_phase
```

```promql
kube_deployment_status_replicas_available
```

```promql
node_cpu_seconds_total
```

Expected result:

- active metric series are returned
- expected monitoring targets report healthy scrape status
- application and Kubernetes telemetry are available to Grafana

---

## Application Metrics Validation

The Baba App backend exposes metrics through Spring Boot Actuator and Micrometer.

Validated metrics path:

```text
Spring Boot Actuator / Micrometer
        ↓
ServiceMonitor
        ↓
Prometheus
        ↓
Grafana
```

The application metrics endpoint is exposed internally on the management port.

Validated endpoints include:

```text
/actuator/health
/actuator/prometheus
```

The Baba App Grafana dashboard includes:

- backend replica availability
- application uptime
- HTTP request rate
- HTTP 5xx error rate
- request activity by URI and method
- p95 request latency
- JVM heap usage
- process CPU utilization

The dashboard was visually validated with live application data.

---

## Grafana Validation

Grafana provides authenticated dashboard access.

Validated controls include:

- anonymous access disabled
- authenticated administrative access required
- credentials supplied through Kubernetes Secret
- credentials not committed to Git
- service exposure limited to `ClusterIP`
- local administrative access performed through port forwarding
- Prometheus configured as the default datasource
- Loki configured as an additional datasource

Representative access command:

```bash
kubectl port-forward   -n observability   svc/baba-observability-grafana   3001:80
```

Grafana successfully queries both Prometheus and Loki.

---

## Dashboard Validation

Phase 08 provides operational dashboard coverage across:

- cluster health
- node availability
- CPU utilization
- memory utilization
- namespaces
- deployments
- pods
- replica availability
- pod restarts
- resource requests and limits
- Baba App application metrics

The custom Baba App dashboard is provisioned through GitOps.

---

## AWS Observability Validation

AWS-native telemetry remains available alongside the in-cluster observability stack.

Relevant telemetry includes:

- EKS control-plane logs where enabled
- VPC Flow Logs
- CloudWatch log groups
- infrastructure service logs

Representative command:

```bash
aws logs describe-log-groups --region us-east-1
```

AWS telemetry remains managed through infrastructure-as-code where applicable.

---

# Centralized Logging Validation

## Logging Architecture

Validated centralized logging flow:

```text
Kubernetes Pods
      ↓
/var/log/pods
      ↓
Grafana Alloy DaemonSet
      ↓
CRI processing + Kubernetes labels
      ↓
Grafana Loki
      ↓
Grafana Explore / LogQL
```

Grafana Alloy runs as a DaemonSet so each EKS worker node has a node-local log collector.

Loki runs in development-oriented monolithic mode with bounded retention.

---

## Loki Validation

Loki is deployed internally through the Kubernetes Service:

```text
baba-app-loki
```

The Loki service uses `ClusterIP`.

Readiness validation:

```bash
kubectl port-forward   -n observability   svc/baba-app-loki   3100:3100
```

```bash
curl -s http://localhost:3100/ready
```

Expected:

```text
ready
```

Label API validation:

```bash
curl -s http://localhost:3100/loki/api/v1/labels
```

Validated labels include:

```text
app
container
namespace
pod
service_name
stream
```

Namespace values were confirmed to include:

```text
argocd
baba-app
kube-system
observability
```

---

## Baba App Log Validation

A fresh backend pod was deliberately created to produce deterministic startup logs.

Representative query:

```bash
curl -G -s   "http://localhost:3100/loki/api/v1/query_range"   --data-urlencode 'query={namespace="baba-app"}'   --data-urlencode 'limit=20'
```

The query returned real Baba App backend entries with labels including:

```text
app=baba-app-backend
container=backend
namespace=baba-app
pod=<backend-pod-name>
service_name=baba-app-backend
stream=stdout
```

Grafana Explore also successfully rendered Baba App backend log lines using:

```logql
{namespace="baba-app"}
```

and:

```logql
{namespace="baba-app", container="backend"}
```

This proves the full application log path is operational.

---

# Centralized Logging Troubleshooting Resolved

## 1. Alloy Read-Only Root Filesystem

### Symptom

Alloy entered `CrashLoopBackOff` with an error similar to:

```text
failed to create remotecfg service: mkdir /tmp/alloy: read-only file system
```

### Root Cause

The container was hardened with:

```text
readOnlyRootFilesystem: true
```

but Alloy required writable runtime space under `/tmp/alloy`.

### Remediation

Added a scoped `emptyDir` volume mounted at:

```text
/tmp/alloy
```

The container root filesystem remained read-only.

### Security Outcome

The fix preserved container hardening while granting only the minimum required writable path.

---

## 2. Alloy ServiceAccount RBAC Mismatch

### Symptom

Alloy could not list Kubernetes Pods.

### Root Cause

The custom ClusterRoleBinding referenced the wrong ServiceAccount name.

Expected chart-created ServiceAccount:

```text
baba-app-alloy
```

### Remediation

Updated the custom ClusterRoleBinding to reference the correct ServiceAccount.

### Validation

```bash
kubectl auth can-i list pods   --as=system:serviceaccount:observability:baba-app-alloy   --all-namespaces
```

Expected:

```text
yes
```

---

## 3. EKS Pod Log Filesystem Permissions

### Symptom

The non-root Alloy container could not access `/var/log/pods`.

### Root Cause

EKS node pod-log directories and files were owned by `root:root` with restrictive permissions.

### Security Constraint

Alloy was intentionally configured to run as:

```text
UID: 65534
GID: 65534
runAsNonRoot: true
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities: drop ALL
seccomp: RuntimeDefault
```

### Remediation

Added:

```yaml
supplementalGroups:
  - 0
```

at Pod security-context level.

### Security Outcome

Alloy remained non-root while receiving only the group-level access necessary to read node-local pod logs.

---

## 4. Kubernetes Log Path Capture

### Symptom

Alloy generated invalid paths with extra path segments or double slashes.

### Root Cause

Alloy relabeling joined:

```text
pod UID
container name
```

using:

```text
separator = "/"
```

The combined value was captured as `$1`.

### Remediation

Corrected the replacement path to:

```text
/var/log/pods/*$1/*.log
```

### Validation

Rendered Helm configuration confirmed the expected path.

---

## 5. Alloy File Matching

### Symptom

Alloy attempted to `stat()` wildcard paths directly and reported:

```text
no such file or directory
```

### Root Cause

`loki.source.file` was receiving glob-style `__path__` values without built-in file matching enabled.

### Remediation

Enabled:

```alloy
file_match {
  enabled     = true
  sync_period = "10s"
}
```

### Validation

Recent Alloy logs no longer reported wildcard path errors.

---

## 6. Incorrect Alloy Loki Service Endpoint

### Symptom

Alloy reported:

```text
lookup baba-loki.observability.svc.cluster.local: no such host
```

### Root Cause

The configured endpoint referenced:

```text
baba-loki
```

while the actual Kubernetes Service was:

```text
baba-app-loki
```

### Remediation

Updated the endpoint to:

```text
http://baba-app-loki.observability.svc.cluster.local:3100/loki/api/v1/push
```

### Validation

DNS errors stopped and Loki began receiving log streams.

---

## 7. Incorrect Grafana Loki Datasource Endpoint

### Symptom

Grafana could not query Loki even though direct Loki API requests worked.

### Root Cause

Grafana's datasource still referenced the old nonexistent `baba-loki` service.

### Remediation

Updated the Grafana Loki datasource URL to:

```text
http://baba-app-loki.observability.svc.cluster.local:3100
```

### Validation

Grafana Explore successfully displayed Baba App logs.

---

## 8. Deterministic Application Log Generation

### Problem

The logging pipeline was healthy, but existing Baba App Pods were idle and produced no recent log lines.

### Validation Method

Deleted one backend replica so Kubernetes recreated it.

The new backend generated deterministic Spring Boot startup events.

### Result

The logs appeared through:

```text
kubectl logs
      ↓
Alloy
      ↓
Loki API
      ↓
Grafana Explore
```

This provided end-to-end proof of centralized application logging.

---

# Security Finding — Generated Spring Security Credential

## Finding

During centralized logging validation, the Baba App backend emitted an automatically generated Spring Security development password to stdout.

The logging pipeline correctly collected the application output and stored the credential in Loki.

This is an application-security finding, not a Loki or Alloy defect.

## Risk

Centralized logging increases the number of systems and users that may have access to application output.

A credential written to stdout can therefore become visible to:

- log administrators
- operators
- incident responders
- automated log-processing systems
- downstream monitoring integrations

The exposed value must be treated as compromised.

## Root Cause

The backend had a custom `SecurityFilterChain` but no explicit local `UserDetailsService`.

Spring Boot therefore auto-configured its default development user and generated a temporary password.

## Remediation

The backend security configuration was updated with an intentionally empty local user store:

```java
@Bean
public UserDetailsService userDetailsService() {
    return new InMemoryUserDetailsManager();
}
```

This prevents Spring Boot from generating the default development credential while preserving existing protected-route behavior.

## Local Validation

Backend validation completed successfully:

```text
mvn clean test
BUILD SUCCESS
```

## Deployment Validation Status

Final remediation validation remains pending deployment of the updated backend image.

After deployment, validate:

```bash
kubectl logs -n baba-app   -l app.kubernetes.io/name=baba-app-backend   --since=5m   | grep -i 'generated security password'
```

Expected:

```text
<no output>
```

Then validate Loki:

```logql
{namespace="baba-app"} |= "generated security password"
```

Expected for newly generated logs:

```text
no matching entries
```

Historical entries may remain visible until Loki retention removes them.

---

# Prometheus Operator Validation

## Server-Side Apply for CRDs

The initial deployment encountered issues applying large Prometheus Operator CRDs through Argo CD.

The observability Application was configured with:

```yaml
syncOptions:
  - CreateNamespace=false
  - ServerSideApply=true
```

This enabled Argo CD to manage the Prometheus Operator CRD set successfully.

---

## Grafana Memory Exhaustion

Grafana initially restarted with:

```text
Reason: OOMKilled
Exit Code: 137
```

Resources were adjusted to:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 300m
    memory: 512Mi
```

After rollout, Grafana remained stable.

---

## Admission Webhook TLS Remediation

Prometheus Operator logs initially showed:

```text
remote error: tls: bad certificate
```

The webhook configurations initially had empty `caBundle` fields.

The certificate patch process was ordered through Argo CD hooks.

After remediation:

- mutating webhook `caBundle` populated
- validating webhook `caBundle` populated
- certificate patch jobs completed
- repeated TLS errors stopped

This restored trusted communication for Prometheus Operator admission webhooks.

---

## Prometheus Status Reconciliation Anomaly

The Prometheus workload is operational, but the Prometheus custom resource can report:

```text
Available=False
Reason=StatefulSetNotFound
```

even while the generated StatefulSet and Pod are healthy.

Live validation confirmed:

- StatefulSet exists
- StatefulSet reports `1/1 Ready`
- owner reference matches the Prometheus CR
- Prometheus readiness endpoint responds
- Prometheus API queries return metric results
- Grafana successfully queries Prometheus
- Kubernetes dashboards display live data

This condition was reproduced after a clean rebuild.

The remaining Argo CD `Degraded` state is classified as a Prometheus Operator status-reconciliation anomaly rather than a monitoring service outage.

Healthy workloads were intentionally not deleted solely to force a cosmetic health state.

---

# Kubernetes Security Validation

Validated observability controls include:

- dedicated `observability` namespace
- dedicated ServiceAccounts
- custom least-privilege Alloy RBAC
- no unnecessary `cluster-admin`
- no public Grafana, Prometheus, Alloy, or Loki service
- hardened Alloy security context
- resource requests and limits
- credentials supplied separately from source control
- GitOps-managed configuration

Representative validation:

```bash
kubectl get serviceaccounts -n observability
kubectl get roles,rolebindings -n observability
kubectl get clusterroles,clusterrolebindings | grep -i observ
kubectl get svc -n observability
```

---

# Security Scanning

Security validation continues through the CI/CD pipeline.

Relevant tools include:

```text
Gitleaks
Checkov
Trivy
CodeQL
```

Findings are handled through:

```text
Remediate
Document accepted risk
Document deferred control
Time-bound exception with reassessment
```

Security gates are not disabled merely to obtain a passing build.

Runtime-image CVEs with no vendor fix are handled through package-specific, time-bound Trivy exceptions with expiration dates.

---

# Resource and Retention Validation

The Phase 08 development environment uses bounded resource and retention settings.

Validated controls include:

- Prometheus retention: 7 days
- Prometheus retention size: bounded
- Loki retention: 7 days
- Grafana resource requests and limits
- Prometheus resource requests and limits
- Alloy resource requests and limits
- no unnecessary persistent storage for the development implementation
- no public observability endpoints

Representative commands:

```bash
kubectl top pods -n observability
kubectl top nodes
```

where metrics support is available.

---

# Failure Isolation

Observability is not a synchronous dependency of Baba App.

Expected architecture behavior:

```text
Observability failure
        ↓
Reduced visibility
        ↓
Application continues serving traffic
```

Grafana, Prometheus, Loki, or Alloy failure should not directly cause Baba App application failure.

---

# Reproducibility Validation

Phase 08 was validated after a complete EKS destruction and reprovision.

The following were restored successfully from infrastructure-as-code and GitOps configuration:

- EKS observability namespace
- Prometheus
- Grafana
- Alertmanager
- kube-state-metrics
- node-exporter
- Prometheus Operator
- ServiceMonitors
- PrometheusRules
- Loki
- Alloy
- Grafana datasources
- Baba App application dashboard

This confirms the implementation is reproducible and is not dependent on leftover cluster state.

Secrets remain supplied separately from Git.

---

# Cost Validation

Phase 08 cost-related decisions include:

- bounded metrics retention
- bounded log retention
- no unnecessary persistent development storage
- no public load balancers for observability tools
- small development-oriented Loki deployment
- controlled CPU and memory requests/limits
- use of existing EKS worker capacity

The implementation intentionally avoids unnecessary telemetry duplication.

---

# Alerting Validation

Prometheus Alertmanager is deployed with an internal `ClusterIP` service and a development-safe receiver configuration.

Alert rules are available through the observability stack.

Before Phase 08 is declared fully closed, at least one controlled alert condition should be tested if this has not already been completed.

Suitable tests include:

- temporarily scaling a workload below its expected replica count
- controlled backend restart
- short-lived availability failure
- safe threshold simulation

Validation evidence should capture:

```text
Alert rule
Trigger condition
Pending/Firing state
Receiver behavior
Recovery to normal
```

If an alert test is intentionally deferred, that decision should be documented explicitly rather than represented as completed.

---

# Phase 08 Acceptance Criteria

Phase 08 is technically validated when:

- observability components deploy through GitOps
- Prometheus collects expected Kubernetes metrics
- Baba App application metrics reach Prometheus
- Grafana dashboards contain live data
- AWS telemetry remains accessible
- operational logs are centralized through Alloy and Loki
- Baba App logs are queryable in Grafana
- observability endpoints remain privately exposed
- credentials are excluded from Git
- resource and retention settings are bounded
- troubleshooting evidence is documented
- the Prometheus CR anomaly is documented accurately
- the Spring-generated credential finding is remediated and deployment-validated
- at least one alert is tested or explicitly documented as deferred
- final documentation reflects the implemented state

---

# Current Phase Status

## Completed

- Prometheus deployment
- Grafana deployment
- Alertmanager deployment
- Kubernetes metrics collection
- Baba App application metrics
- custom Grafana application dashboard
- Loki centralized log storage
- Alloy node-level collection
- Grafana Loki datasource
- end-to-end Baba App log ingestion
- fresh-cluster reproducibility test
- TLS webhook remediation
- Grafana OOM remediation
- Prometheus status-anomaly investigation
- centralized logging troubleshooting and validation
- Spring credential exposure identified
- Spring credential code remediation implemented locally
- Maven validation passed

## Pending Final Closure Items

1. Deploy the Spring credential-remediation backend image.
2. Confirm new backend startup logs do not contain `generated security password`.
3. Confirm new Loki entries do not contain that credential.
4. Confirm or document the controlled alert test status.

After those items are validated, Phase 08 can be formally marked complete.

---

# Phase 08 Outcome

Phase 08 provides operational visibility across:

- EKS worker nodes
- Kubernetes namespaces
- Pods and containers
- CPU utilization
- Memory utilization
- resource requests and limits
- Kubernetes API server
- kubelet and cAdvisor
- kube-state-metrics
- node-exporter
- Prometheus
- Grafana
- Alertmanager
- Prometheus Operator
- Baba App backend metrics
- Kubernetes workload logs
- Baba App backend logs
- GitOps reconciliation state

The observability implementation now supports both operational monitoring and security investigation workflows while remaining intentionally sized for the Baba App development environment.