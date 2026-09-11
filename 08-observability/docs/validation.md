# Phase 08 — Observability Validation

## Overview

This document defines the validation approach for Phase 08 — Observability.

Validation should demonstrate that the Baba App observability platform is functioning as designed across metrics, dashboards, logging, alerting, security controls, and GitOps deployment.

The final evidence should show not only that observability components are running, but that they provide useful operational visibility and can be reproduced from version-controlled configuration.

## Validation Objectives

Phase 08 validation should confirm:

- observability components deploy successfully through GitOps
- Prometheus collects Kubernetes and application metrics
- Grafana queries Prometheus successfully
- dashboards display live platform and workload data
- AWS-native telemetry remains available through CloudWatch
- operational logs are centralized and searchable
- alerting rules evaluate successfully
- at least one alert path is tested
- observability services are not unintentionally exposed publicly
- credentials and secrets are not committed to Git
- Kubernetes service accounts and RBAC follow least-privilege principles
- security scans pass or findings are documented
- retention and resource settings are bounded
- the environment can be reproduced from Git

## Pre-Deployment Validation

Before deploying observability components, validate repository configuration.

### Repository Structure

Expected Phase 08 structure:

```text
08-observability/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── security-controls.md
│   └── validation.md
└── scripts/
```

GitOps resources added later should remain clearly separated from Baba App application workloads.

### Git Validation

Run:

```bash
git status
git diff --check
```

Expected result:

- no whitespace errors
- no unintended files
- no plaintext credentials
- only expected Phase 08 changes

### Secret Scanning

Existing Gitleaks validation should continue to pass.

No observability credentials should appear in:

```text
values.yaml
Kubernetes manifests
GitHub workflows
Terraform files
README files
documentation
```

## GitOps Validation

Observability resources should be delivered through the existing GitOps model.

Validation should confirm:

- Argo CD recognizes the observability application or resources
- synchronization completes successfully
- desired state matches Git
- self-healing behavior remains available where configured
- observability resources are created only in approved namespaces

Expected namespace:

```text
observability
```

Validation commands may include:

```bash
kubectl get namespace observability
kubectl get all -n observability
```

Argo CD status should report:

```text
Synced
Healthy
```

where applicable.

## Prometheus Validation

Prometheus should be deployed and collecting metrics.

### Pod Health

Validate:

```bash
kubectl get pods -n observability
```

Prometheus-related pods should be:

```text
Running
Ready
```

### Service Validation

Validate Prometheus service exposure:

```bash
kubectl get svc -n observability
```

Prometheus should not use an unintended public `LoadBalancer`.

Preferred exposure:

```text
ClusterIP
```

### Metrics Collection

Prometheus should successfully scrape Kubernetes telemetry.

Validation targets may include:

- Kubernetes API metrics
- kube-state-metrics
- node metrics
- pod metrics
- application metrics where configured

Representative Prometheus queries may include:

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

## Grafana Validation

Grafana should provide authenticated dashboard access and successfully query the Prometheus datasource.

### Pod Health

Validate:

```bash
kubectl get pods -n observability
```

Grafana should report:

```text
Running
Ready
```

### Network Exposure

Validate:

```bash
kubectl get svc -n observability
```

Grafana should not be exposed through an unintended public service.

If administrative access uses port forwarding, validate through:

```bash
kubectl port-forward -n observability svc/<grafana-service> 3000:80
```

The exact service name will be documented after implementation.

### Authentication

Validation should confirm:

- anonymous access is disabled
- authentication is required
- administrative credentials are not stored in Git

### Datasource

Grafana should successfully query Prometheus.

Validation should confirm that the Prometheus datasource reports a successful connection.

## Dashboard Validation

Phase 08 should provide operational dashboards with live data.

### Platform Dashboard

Validate visibility into:

- node availability
- cluster health
- CPU utilization
- memory utilization
- workload health

### Kubernetes Dashboard

Validate visibility into:

- namespaces
- deployments
- pods
- replica availability
- pod restarts
- resource utilization

### Application Dashboard

Where application metrics are available, validate:

- backend availability
- frontend availability
- request activity
- errors
- application health

Screenshots or exported dashboard metadata may be retained as portfolio evidence where useful.

## AWS Observability Validation

Existing AWS-native telemetry should remain functional.

Validation may include:

```bash
aws logs describe-log-groups --region us-east-1
```

Relevant telemetry should include existing platform logs such as:

- EKS control-plane logs when EKS is provisioned
- VPC Flow Logs
- infrastructure service logs

CloudWatch configuration should remain managed through infrastructure-as-code where applicable.

## Centralized Logging Validation

Once the Phase 08 logging component is implemented, validation should demonstrate that workload logs can be queried centrally.

Validation should confirm:

- logs from Baba App workloads are collected
- logs include useful workload metadata
- logs can be filtered by namespace or workload
- sensitive values are not intentionally logged
- retention is bounded
- logging failure does not cause application failure

Representative test:

1. Generate normal application traffic.
2. Query the centralized logging platform.
3. Locate the corresponding backend or frontend log events.
4. Confirm timestamps and workload metadata.
5. Verify no credentials or secrets appear in the event.

## Alerting Validation

Alert rules should be evaluated and at least one controlled alert should be tested.

Potential test conditions include:

- temporarily scaling a deployment below expected replicas
- controlled workload restart
- short-lived application availability failure
- safe resource-threshold simulation

The test should avoid destructive or production-impacting behavior.

Validation evidence should include:

- alert rule name
- trigger condition
- alert state transition
- receiver or notification behavior where configured
- recovery to normal state

## Kubernetes Security Validation

Observability Kubernetes resources should be reviewed for security posture.

Validation should include:

- dedicated namespace
- dedicated service accounts
- least-privilege RBAC
- no unnecessary `cluster-admin`
- no unintended public services
- workload security contexts where supported
- resource requests and limits
- restricted secret handling

Commands may include:

```bash
kubectl get serviceaccounts -n observability
kubectl get roles,rolebindings -n observability
kubectl get clusterroles,clusterrolebindings | grep -i observ
kubectl get svc -n observability
```

## Security Scanning

The infrastructure-security workflow should validate observability resources.

Expected tools include:

```text
Checkov
Trivy
Gitleaks
```

Findings should be handled through one of the following:

```text
Remediate
Document accepted risk
Document deferred control
```

Security checks should not be disabled merely to obtain a passing workflow.

## Resource Validation

Observability components should not consume unbounded cluster resources.

Validate:

```bash
kubectl top pods -n observability
kubectl top nodes
```

where metrics support is available.

Review:

- CPU requests
- memory requests
- CPU limits
- memory limits
- storage use
- metrics retention
- log retention

The development implementation should remain appropriately sized for the Baba App environment.

## Failure Isolation Validation

Observability should not become a synchronous dependency of Baba App.

A controlled test may temporarily stop or scale down a visualization component such as Grafana.

Expected result:

```text
Baba App remains available.
```

Prometheus or logging interruptions should affect visibility, not application functionality.

## Reproducibility Validation

The observability platform should be recoverable from version-controlled configuration.

Validation should confirm:

- no required manual cluster configuration exists outside documented bootstrap steps
- GitOps resources are stored in Git
- configuration changes are reviewable
- component versions are explicit
- secrets are supplied separately from source control

## Cost Validation

Phase 08 should record the cost-impacting decisions introduced by observability.

Review:

- additional EKS workload consumption
- persistent storage if introduced
- CloudWatch ingestion
- CloudWatch retention
- log duplication
- metrics retention

The implementation should avoid unnecessary telemetry duplication.

## Commercial Product Validation Considerations

The future commercial implementation should support multiple observability levels without requiring the full Baba App stack.

Validation should eventually support configurations such as:

```text
Basic:
AWS-native metrics and alarms

Standard:
AWS dashboards and centralized logs

Advanced:
Prometheus, Grafana, Kubernetes metrics, centralized logging, and advanced alerting
```

Each tier should maintain baseline security requirements.

## Troubleshooting Evidence

During implementation, meaningful failures and remediations should be documented.

For each significant issue, capture:

```text
Symptom
Root cause
Security or operational impact
Remediation
Validation after remediation
```

This evidence will support both portfolio documentation and interview preparation.

## Final Validation Criteria

Phase 08 can be considered complete when:

- observability components are deployed through GitOps
- Prometheus collects expected metrics
- Grafana dashboards contain live data
- AWS telemetry remains accessible
- operational logs are centralized
- at least one alert is tested
- observability endpoints are securely controlled
- secrets are excluded from Git
- security scans pass or findings are documented
- resource and retention settings are bounded
- troubleshooting evidence is captured
- final documentation reflects the implemented state

## Phase Status

## Live Validation and Troubleshooting Results

### Fresh EKS Reprovision Validation

The Phase 08 observability stack was validated after completely destroying and reprovisioning the EKS cluster.

The following components were restored successfully through Terraform, Argo CD, Helm, and GitOps:

- Prometheus
- Grafana
- Alertmanager
- kube-state-metrics
- node-exporter
- Prometheus Operator
- Kubernetes ServiceMonitors and PrometheusRules

This fresh-cluster deployment confirmed that the Phase 08 configuration is reproducible and not dependent on leftover Kubernetes state.

### Server-Side Apply for Prometheus CRDs

The initial observability deployment encountered issues applying large Prometheus Operator CustomResourceDefinitions through Argo CD.

The Argo CD Application was updated with:

```yaml
syncOptions:
  - CreateNamespace=false
  - ServerSideApply=true
```

Server-side apply allowed Argo CD to successfully manage the full Prometheus Operator CRD set.

### Grafana Memory Exhaustion

Grafana initially restarted with:

```text
Reason: OOMKilled
Exit Code: 137
```

The Grafana memory allocation was increased to:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 300m
    memory: 512Mi
```

After the GitOps rollout, the replacement Grafana pod remained stable with a restart count of zero.

### Admission Webhook TLS Remediation

Prometheus Operator logs showed repeated TLS errors:

```text
remote error: tls: bad certificate
```

Both the MutatingWebhookConfiguration and ValidatingWebhookConfiguration initially contained empty `caBundle` fields.

The Prometheus Operator admission webhook patch process was configured to run as an Argo CD PreSync hook.

After remediation:

- Mutating webhook `caBundle` was populated.
- Validating webhook `caBundle` was populated.
- Admission certificate patch jobs completed successfully.
- Repeated `bad certificate` errors stopped.

This restored trusted TLS communication for Prometheus Operator admission webhooks.

### Prometheus Status Reconciliation Anomaly

The Prometheus workload is operational, but the Prometheus custom resource continues to report:

```text
Available=False
Reason=StatefulSetNotFound
```

The operator reports:

```text
shard 0: statefulset observability/prometheus-baba-observability-prometheus not found
```

However, live validation confirmed:

- `prometheus-baba-observability-prometheus` exists.
- The StatefulSet reports `1/1 Ready`.
- The StatefulSet labels match the Prometheus CR selector.
- The StatefulSet owner reference UID matches the Prometheus CR UID.
- Prometheus responds successfully to its readiness endpoint.
- Prometheus API queries return successful metric results.
- Grafana successfully queries the Prometheus datasource.
- Kubernetes dashboards display live cluster, node, namespace, pod, CPU, and memory metrics.

The remaining Argo CD `Degraded` state is therefore documented as a Prometheus Operator status-reconciliation anomaly rather than a monitoring service outage.

Healthy resources were intentionally not deleted solely to force a cosmetic health-state change.

## Observability Validation Outcome

Phase 08 successfully provides operational visibility across:

- EKS worker nodes
- Kubernetes namespaces
- Pods and containers
- CPU utilization
- Memory utilization
- Resource requests and limits
- Kubernetes API server
- kubelet and cAdvisor
- kube-state-metrics
- node-exporter
- Prometheus
- Grafana
- Alertmanager
- Prometheus Operator

Grafana dashboards successfully provide cluster-level, node-level, and pod-level drill-down capabilities.

Application-specific Baba App metrics are planned as an additional observability enhancement.
