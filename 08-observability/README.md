# Phase 08 — Observability

## Overview

Phase 08 introduces a centralized observability foundation for the Baba App platform.

The purpose of this phase is to provide operational visibility across AWS infrastructure, EKS, Kubernetes workloads, and the Baba App application while preserving secure access, reproducibility, and cost awareness.

The implementation will use GitOps-managed observability components and AWS-native telemetry where appropriate.

## Objectives

Phase 08 is designed to:

- establish centralized metrics, dashboards, logs, and alerting
- monitor EKS cluster and node health
- monitor Kubernetes workloads and deployment state
- monitor backend and frontend application health
- provide Grafana dashboards for platform and application visibility
- use Prometheus as the primary Kubernetes and application metrics platform
- retain AWS-native CloudWatch telemetry for infrastructure visibility
- centralize operational logs for troubleshooting
- define actionable alerts with controlled noise
- avoid public unauthenticated observability endpoints
- use GitOps for observability deployment and configuration
- preserve least-privilege access
- keep retention and resource usage cost-conscious
- produce validation evidence and troubleshooting documentation
- keep the design reusable for a future commercial secure-cloud product

## Phase Scope

Phase 08 focuses on operational observability.

The primary observability domains are:

```text
Metrics
Dashboards
Logs
Alerts
Operational troubleshooting
```

Deeper security monitoring, SIEM integration, threat correlation, and advanced detection remain part of later security phases.

## Target Architecture

```text
Application Metrics
       |
       v
   Prometheus
       |
       v
    Grafana
       |
       +--> Platform dashboards
       +--> Kubernetes dashboards
       +--> Application dashboards


Kubernetes / EKS
       |
       +--> kube-state-metrics
       +--> node metrics
       +--> workload metrics


AWS Infrastructure
       |
       v
 CloudWatch Metrics / Logs
       |
       v
Operational Visibility


Application / Kubernetes Logs
       |
       v
Centralized Logging
       |
       v
Troubleshooting / Search
```

## GitOps Delivery Model

Observability components should be deployed through Git and Argo CD rather than through undocumented manual installation steps.

Target delivery flow:

```text
Git
 |
 v
Argo CD
 |
 +--> Baba App workloads
 |
 +--> Observability components
        |
        +--> Prometheus
        +--> Grafana
        +--> metrics collectors
        +--> logging components
```

This keeps the observability platform:

- version-controlled
- reviewable
- reproducible
- auditable
- recoverable

## Metrics Foundation

Prometheus will provide the primary metrics platform for Kubernetes and application telemetry.

Planned metrics sources include:

- Kubernetes object state
- pod metrics
- node metrics
- workload health
- deployment state
- resource utilization
- application availability
- application request metrics where supported

Key metrics should help answer:

```text
Is the cluster healthy?
Are the workloads healthy?
Is the application available?
Are resources under pressure?
What changed?
```

## Grafana

Grafana will provide dashboards for centralized operational visibility.

Initial dashboard categories include:

### Platform Dashboard

- EKS health
- node availability
- CPU utilization
- memory utilization
- workload health

### Kubernetes Dashboard

- namespaces
- deployments
- pods
- replicas
- pod restarts
- resource utilization

### Application Dashboard

- backend health
- frontend health
- application availability
- error conditions
- request behavior where application metrics are available

## AWS Observability

AWS-native observability will continue to be used where it provides the strongest operational value.

CloudWatch may provide visibility into:

- EKS control-plane logs
- VPC Flow Logs
- AWS service metrics
- infrastructure events
- service-specific operational logs

Prometheus and CloudWatch will serve complementary purposes rather than duplicate every metric.

```text
Prometheus
    |
    +--> Kubernetes and application telemetry

CloudWatch
    |
    +--> AWS-native infrastructure telemetry
```

## Logging

Phase 08 will introduce centralized operational logging.

Logging should support:

- application troubleshooting
- Kubernetes workload troubleshooting
- deployment troubleshooting
- infrastructure diagnostics

The design should minimize duplicate log ingestion and unnecessary retention costs.

Structured logging should be preferred where practical.

## Alerting

Alerts should focus on actionable conditions.

Initial alert categories may include:

- node unavailable
- high CPU utilization
- high memory utilization
- pod restart spikes
- deployment replica shortages
- application unavailable
- repeated application errors
- infrastructure degradation

Alert thresholds should be tuned to avoid excessive noise and alert fatigue.

## Security Controls

Observability must not weaken the security posture established in earlier phases.

Key controls include:

- no public unauthenticated Grafana access
- credentials and secrets excluded from Git
- least-privilege Kubernetes service accounts
- controlled network exposure
- secure administrator access
- security scanning of observability manifests
- environment-specific configuration
- GitOps-managed deployment
- protected repository workflows
- bounded metrics and log retention

Detailed security controls are documented in:

```text
08-observability/docs/security-controls.md
```

## Validation

Phase 08 validation should demonstrate:

- Prometheus is collecting metrics
- Grafana can query Prometheus
- Kubernetes dashboards contain live data
- application health metrics are visible
- AWS telemetry remains available
- centralized logs are searchable
- at least one alert condition is tested
- observability services are not publicly exposed without approved controls
- security scans pass
- the implementation can be reproduced from Git

Validation evidence will be documented in:

```text
08-observability/docs/validation.md
```

## Cost Considerations

Because Baba App is a development environment, observability should remain cost-conscious.

The design should consider:

- short metrics retention
- controlled log retention
- right-sized observability workloads
- limited telemetry duplication
- optional components
- destruction of temporary EKS resources when not actively needed

For a future commercial version, observability may be offered in tiers:

```text
Basic
CloudWatch metrics and alarms

Standard
CloudWatch dashboards and centralized logs

Advanced
Prometheus, Grafana, centralized logging, and advanced alerting
```

## Documentation

Phase 08 documentation includes:

```text
08-observability/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── security-controls.md
│   └── validation.md
└── scripts/
```

## Expected Outcome

At the completion of Phase 08, Baba App should provide:

- centralized Kubernetes metrics
- AWS infrastructure visibility
- Grafana dashboards
- application health visibility
- centralized operational logs
- actionable alerts
- secure observability access
- reproducible GitOps deployment
- validation evidence
- documented troubleshooting procedures

## Phase Status

**Phase 08 — In Progress**