# Phase 08 — Observability Security Controls

## Overview

Phase 08 introduces observability components that collect, process, store, and expose operational telemetry for the Baba App platform.

Because observability systems often have broad visibility into infrastructure and application behavior, they must be treated as sensitive platform components.

This document defines the security controls for Prometheus, Grafana, Kubernetes metrics collection, centralized logging, AWS-native telemetry, and alerting.

## Security Objectives

The observability implementation should:

- prevent unauthenticated public access
- minimize credential exposure
- use least-privilege identities
- restrict service-to-service access
- avoid storing secrets in Git
- protect telemetry that may contain sensitive operational details
- preserve existing network restrictions
- minimize unnecessary data retention
- keep observability configuration version-controlled
- maintain auditable deployment and configuration changes

## Grafana Access Control

Grafana must not be exposed as a public unauthenticated service.

Required controls include:

- authentication enabled
- anonymous access disabled
- administrative credentials excluded from Git
- controlled network exposure
- restricted administrative access
- secure session handling
- least-privilege user roles where multiple users are introduced

For the Baba App development environment, Grafana should initially be accessed through a controlled administrative path rather than an unrestricted public endpoint.

Possible approved access models include:

```text
kubectl port-forward
Private ingress
VPN / private network
Authenticated ingress
```

The exact model will be selected based on implementation complexity and security requirements.

## Prometheus Exposure

Prometheus provides detailed infrastructure and workload information and should not be directly exposed to the public Internet.

Controls include:

- Kubernetes `ClusterIP` service where practical
- no unauthenticated public load balancer
- Grafana used as the primary visualization layer
- administrative access only when required
- namespace-level isolation
- restricted service discovery configuration

## Kubernetes Namespace Isolation

Observability components should run in a dedicated namespace.

Target namespace:

```text
observability
```

This separates monitoring workloads from Baba App application workloads and supports:

- clearer RBAC boundaries
- easier resource governance
- easier troubleshooting
- future NetworkPolicy enforcement
- lifecycle separation

## Kubernetes RBAC

Prometheus and supporting metrics components require Kubernetes API visibility.

Permissions should be limited to what each component requires.

Security principles include:

- dedicated service accounts
- no unnecessary `cluster-admin`
- read-only Kubernetes API permissions for metrics collection
- separate identities for components with different responsibilities
- explicit RBAC manifests or chart configuration
- review of ClusterRole permissions before deployment

Broad administrative permissions should not be granted solely for installation convenience.

## Kubernetes Workload Hardening

Observability workloads should follow the container-security baseline established earlier in Baba App.

Where supported by the deployed component, workloads should use:

```yaml
securityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

Container-level controls should include where practical:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

Some observability components may require exceptions due to their runtime behavior.

Any exception should be:

- technically justified
- narrowly scoped
- documented
- reviewed by security scanning

## Secrets Management

Secrets must not be committed to the repository.

Examples include:

- Grafana administrator credentials
- API tokens
- notification webhook credentials
- external logging credentials
- future SMTP credentials
- external datasource credentials

Preferred patterns include:

```text
GitHub Environment or repository secrets
AWS Secrets Manager
Kubernetes Secret populated securely at deployment time
External Secrets integration in a later phase
```

Plaintext passwords must not be placed in:

```text
values.yaml
Kubernetes manifests
Terraform source
README files
GitHub workflow source
```

## GitOps Security

Observability resources should be managed through GitOps where possible.

Security benefits include:

- reviewed configuration changes
- version history
- reproducible deployments
- easier rollback
- auditable desired state
- reduced manual cluster drift

Observability changes should follow the existing branch and pull-request process before reaching `main`.

Argo CD should reconcile only approved observability paths and namespaces.

## Network Exposure

Observability components should default to internal Kubernetes networking.

Preferred service type:

```text
ClusterIP
```

Public exposure should require an explicit architectural decision.

Controls should include:

- no default public `LoadBalancer` services
- restricted ingress where used
- TLS for externally reachable interfaces
- controlled administrative source networks
- later NetworkPolicy enforcement in the Kubernetes security phase

## Telemetry Data Sensitivity

Metrics and logs can reveal sensitive operational information such as:

- internal service names
- namespace names
- IP addresses
- error messages
- deployment identifiers
- resource usage
- infrastructure topology
- application behavior

Application logging must avoid recording:

- passwords
- access tokens
- session tokens
- AWS credentials
- authentication headers
- secrets
- unnecessary personally identifiable information

Operational telemetry should be treated as internal platform data.

## Log Security

Centralized logs should be protected against unnecessary exposure.

Controls include:

- authenticated log access
- controlled retention
- no secret logging
- restricted write permissions
- restricted log-reader permissions
- transport encryption when telemetry leaves the cluster
- AWS-native encryption where CloudWatch is used

Existing CloudWatch logs should continue to use the encryption and retention controls established in earlier infrastructure phases.

## Metrics Retention

Metrics retention should be intentionally bounded.

The development environment does not require long-term metrics retention.

Goals include:

- sufficient history for troubleshooting
- reduced storage consumption
- reduced operating cost
- reduced unnecessary telemetry persistence

Retention settings will be documented as implementation values are selected.

## Log Retention

Log retention should be defined by operational need.

Development telemetry should not be retained indefinitely.

Retention should balance:

```text
Troubleshooting value
        +
Operational evidence
        +
Security visibility
        -
Storage cost
        -
Unnecessary data persistence
```

## Alerting Security

Alerting integrations may require external credentials or webhook URLs.

Controls include:

- notification credentials excluded from Git
- minimum required permissions
- secure transport
- restricted alert receivers
- no sensitive data embedded unnecessarily in alert messages

Alert messages should contain enough context for investigation without exposing credentials or sensitive application data.

## AWS IAM

AWS observability integrations must use IAM roles instead of long-lived AWS access keys.

Where Kubernetes workloads require AWS API access, future implementation should prefer:

```text
EKS Pod Identity
or
IAM Roles for Service Accounts (IRSA)
```

rather than static credentials stored in Kubernetes Secrets.

Any AWS permissions added for observability should be:

- service-specific
- read-only where practical
- resource-scoped where supported
- independently reviewable

## CloudWatch Security

AWS-native logs and metrics should continue to use existing AWS security controls.

Relevant controls include:

- IAM authorization
- KMS encryption where configured
- CloudWatch log retention
- centralized AWS account ownership
- no embedded AWS credentials
- audited infrastructure configuration through Terraform

## Security Scanning

Observability infrastructure should be included in the existing infrastructure-security workflow.

Planned validation includes:

- Checkov
- Trivy
- Kubernetes manifest scanning
- Terraform scanning where AWS resources are added
- secret scanning through Gitleaks

Security findings should be evaluated in deployment context.

False positives caused by rendered GitOps overlays should be handled using the same rendered-manifest strategy established earlier.

## Dependency and Supply Chain Security

Observability introduces third-party container images and Helm charts.

Controls should include:

- trusted upstream projects
- explicit chart versions
- explicit image versions
- avoidance of `latest` tags
- vulnerability scanning
- future image-signature and provenance validation in the supply-chain phase

Where possible, dependency versions should be pinned rather than automatically tracking upstream releases.

## Resource Controls

Observability workloads can consume significant CPU, memory, and storage.

Kubernetes workloads should define:

- resource requests
- resource limits
- retention constraints
- storage limits where applicable

This protects Baba App application workloads from observability-related resource exhaustion.

## Availability Considerations

Observability failure should not cause Baba App application failure.

The design should avoid making application availability dependent on:

```text
Prometheus
Grafana
logging collectors
alert receivers
```

The observability layer should monitor the platform rather than become a critical synchronous dependency of the application.

## Security Validation

Phase 08 security validation should verify:

- Grafana is not anonymously publicly accessible
- Prometheus is not publicly exposed
- observability secrets are not committed
- dedicated service accounts are used
- RBAC is limited to required access
- container security controls are applied where supported
- security scanners pass or findings are documented
- telemetry retention is bounded
- public services are not introduced unintentionally
- AWS integrations avoid static access keys

## Deferred Controls

The following controls are intentionally deferred to later phases where they receive deeper treatment:

- Kubernetes NetworkPolicies
- policy-as-code enforcement
- EKS Pod Identity / IRSA expansion
- runtime threat detection
- image signature enforcement
- software provenance verification
- SIEM event correlation
- security detection engineering

Phase 08 should remain compatible with these future controls.

## Commercial Product Considerations

For a future reusable small-business product, observability should be modular.

A customer should not be required to deploy the full Baba App observability stack.

Potential configurations include:

```text
Basic
- CloudWatch metrics
- CloudWatch alarms
- bounded log retention

Standard
- AWS dashboards
- centralized application logs
- operational alerts

Advanced
- Prometheus
- Grafana
- Kubernetes monitoring
- centralized logging
- advanced alerting
```

Security controls should remain consistent regardless of the selected tier:

- authentication
- least privilege
- encryption
- bounded retention
- no embedded credentials
- auditable configuration

## Expected Security Outcome

At the completion of Phase 08, the observability platform should improve operational visibility without weakening the security controls established in previous phases.

The final implementation should demonstrate that monitoring infrastructure is itself treated as protected infrastructure.