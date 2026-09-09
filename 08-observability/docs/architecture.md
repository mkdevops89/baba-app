# Phase 08 — Observability Architecture

## Overview

Phase 08 introduces a centralized observability foundation for the Baba App platform.

The objective is to provide operational visibility across:

- AWS infrastructure
- EKS
- Kubernetes nodes
- Kubernetes workloads
- backend services
- frontend services

The observability platform is designed to support:

- metrics
- dashboards
- logs
- alerting
- troubleshooting
- operational validation

The implementation will favor GitOps-managed deployment and secure-by-default access.

## Architecture Goals

The observability design should:

- provide centralized infrastructure and application visibility
- minimize manual operational checks
- avoid direct dependency on SSH-based troubleshooting
- preserve least-privilege access
- support reusable deployment patterns
- remain cost-conscious for the development environment
- separate operational observability from deeper security monitoring
- integrate with the existing GitOps delivery model

## High-Level Architecture

```text
                    Baba App Platform

        +-----------------------------------+
        |                                   |
        |          Application Layer        |
        |                                   |
        |   Frontend              Backend   |
        |      |                     |      |
        |      +---------+-----------+      |
        |                |                  |
        +----------------|------------------+
                         |
                         v
                Application Metrics

                         |
                         v

+---------------------------------------------------+
|                  Kubernetes / EKS                 |
|                                                   |
|  Pods        Deployments        Nodes             |
|    |              |              |                |
|    +--------------+--------------+                |
|                   |                               |
|                   v                               |
|             Kubernetes Metrics                    |
|                                                   |
|        kube-state-metrics / node metrics          |
+-------------------------+-------------------------+
                          |
                          v
                     Prometheus
                          |
                          v
                       Grafana
                          |
               Dashboards and Alerts


AWS Infrastructure
      |
      v
CloudWatch Metrics and Logs
      |
      +----------------------+
                             |
                             v
                    Operational Visibility


Application and Kubernetes Logs
      |
      v
Centralized Logging Layer
      |
      v
Search / Troubleshooting
```

## Metrics Strategy

Prometheus will provide the primary Kubernetes and application metrics layer.

Metrics sources will include:

- Kubernetes workload metrics
- Kubernetes object state
- node-level resource metrics
- pod-level resource metrics
- application health metrics
- application availability metrics

Key visibility targets include:

- CPU usage
- memory usage
- node health
- pod status
- pod restarts
- replica availability
- deployment health
- application availability
- request behavior where application metrics are available

## Grafana

Grafana will provide visualization for the observability platform.

Initial dashboard categories will include:

### Platform Dashboard

Visibility into:

- EKS cluster health
- node availability
- CPU utilization
- memory utilization
- workload health

### Kubernetes Dashboard

Visibility into:

- namespaces
- deployments
- pods
- replicas
- pod restarts
- resource utilization

### Application Dashboard

Visibility into:

- backend health
- frontend health
- application availability
- request metrics where available
- error conditions

## AWS Observability

AWS-native telemetry will continue to be used where it provides operational value.

CloudWatch may provide visibility into:

- EKS control-plane logs
- VPC Flow Logs
- AWS infrastructure metrics
- infrastructure events
- service-specific operational logs

The goal is not to duplicate every AWS metric in Prometheus.

Instead:

```text
Prometheus
    |
    +--> Kubernetes and application metrics

CloudWatch
    |
    +--> AWS infrastructure and AWS-native telemetry
```

## Logging Strategy

Phase 08 will introduce centralized operational logging.

Logging should support:

- application troubleshooting
- Kubernetes workload troubleshooting
- infrastructure troubleshooting
- deployment diagnostics

The logging implementation should avoid unnecessary duplication and excessive retention costs.

Structured application logging should be preferred where practical.

## Alerting Strategy

Alerts should focus on actionable conditions.

Initial alert categories may include:

- node unavailable
- high CPU utilization
- high memory utilization
- pod restart spikes
- deployment replica shortage
- application unavailable
- repeated application errors
- infrastructure health degradation

Alert thresholds should avoid excessive noise.

## Security Model

The observability platform must not introduce unnecessary public exposure.

Security requirements include:

- no unauthenticated Grafana access
- no credentials stored in Git
- Kubernetes secrets handled securely
- least-privilege service accounts
- restricted network exposure
- secure administrative access
- security scanning of observability manifests
- controlled dashboard access

## GitOps Integration

Observability components should be deployed through the existing GitOps model rather than manual cluster installation.

Target flow:

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

This keeps observability configuration:

- version-controlled
- reviewable
- reproducible
- auditable

## Cost and Retention

Because Baba App is a development environment, observability should remain cost-conscious.

Design considerations include:

- limited metrics retention
- controlled log retention
- minimal duplicate telemetry
- right-sized observability workloads
- optional components where possible

The commercial version may later support configurable tiers such as:

```text
Basic:
CloudWatch metrics + alarms

Standard:
CloudWatch + dashboards + centralized logs

Advanced:
Prometheus + Grafana + centralized logging + advanced alerting
```

## Phase Boundaries

Phase 08 focuses on operational observability.

Deeper security monitoring, SIEM integration, threat detection, and security-event correlation remain part of later security-monitoring phases.

## Expected Outcome

At the end of Phase 08, the Baba App platform should provide:

- centralized Kubernetes metrics
- application health visibility
- Grafana dashboards
- AWS operational visibility
- centralized operational logs
- actionable alerts
- validation evidence
- documented troubleshooting procedures