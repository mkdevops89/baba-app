# Phase 10 — FinOps and Cost Governance

## Overview

Phase 10 establishes repeatable AWS cost visibility, cost-allocation tagging,
budget monitoring, anomaly detection, least-privilege FinOps access, and
evidence-based cloud waste remediation for the Baba App development
environment.

The implementation reduces avoidable spend without removing encryption,
CloudTrail, centralized logging, Terraform state protection, or other security
controls.

## Objectives

- Establish a reproducible 30-day AWS cost baseline.
- Identify the primary service and usage-type cost drivers.
- Enforce consistent cost-allocation tags through Terraform.
- Validate a monthly AWS budget and alert thresholds.
- Review AWS Cost Anomaly Detection findings and notification thresholds.
- Provide consolidated monthly cost reporting.
- Detect unused or legacy resources through a read-only waste audit.
- Provide a dedicated least-privilege FinOps IAM role.
- Align development EKS and NAT resources with the same controlled lifecycle.
- Preserve long-lived networking, container registries, IAM, audit, and
  Terraform-state resources while the development runtime is disabled.

## Implemented Controls

| Control | Implementation |
|---|---|
| Cost baseline | 30-day unblended-cost report by day, service, and usage type |
| Forecasting | UTC-aligned current-month Cost Explorer forecast |
| Budget | `baba-app-monthly-budget` with a USD 50 monthly limit |

### Budget Subscriber Validation

The consolidated report verifies that every configured budget notification has
at least one subscriber. It records subscriber counts and delivery types without
including email addresses or other subscriber destinations in report output.

| Budget alerts | Actual 50%, 80%, and 100%; forecasted 100% |
| Anomaly detection | Daily email subscription with USD 5 and 20% impact thresholds |
| Cost-allocation tags | Project, Environment, ManagedBy, Owner, CostCenter, and Phase |

### Cost-Allocation Tag Activation

The six required user-defined cost-allocation tag keys are active in AWS
Billing and Cost Management:

- `Project`
- `Environment`
- `ManagedBy`
- `Owner`
- `CostCenter`
- `Phase`

The consolidated report validates both resource-level tag compliance and
billing-level tag activation. Resource tags alone are not sufficient for cost
allocation because inactive keys cannot be used for AWS cost grouping and
filtering.

The tag audit discovers resources by querying the Resource Groups Tagging API
with `Project=baba-app`. Therefore, its compliance percentage applies to active,
taggable resources returned by that filtered query. Resources missing the
`Project` tag entirely are outside that discovery path and require separate
account-level inventory or tag-policy reconciliation.

| Tag compliance | 100% of active in-scope taggable resources |
| FinOps access | Dedicated read-only IAM role and customer-managed policy |
| Waste detection | Account-region inventory of common cost-leak resources |
| EKS optimization | Human-approved provision and destroy lifecycle |
| NAT optimization | NAT Gateway, Elastic IP, and private route follow EKS lifecycle |
| Security retention | CloudTrail, KMS, logging, ECR, VPC, and Terraform state retained |

## Reporting Scripts

| Script | Purpose |
|---|---|
| `scripts/cost-baseline.sh` | Generates the baseline, service costs, daily costs, usage-type costs, and forecast |
| `scripts/tag-audit.sh` | Validates the required cost-allocation tag standard |
| `scripts/waste-audit.sh` | Detects stopped or orphaned regional resources without modifying them |
| `scripts/cost-report.sh` | Produces a consolidated monthly FinOps report |

## Generate the Cost Baseline

```bash
BASELINE_START=2026-08-20 \
BASELINE_END=2026-09-19 \
AWS_PROFILE=baba-admin \
  10-finops/scripts/cost-baseline.sh
```

## Run the Tag Audit

```bash
AWS_PROFILE=baba-admin \
  10-finops/scripts/tag-audit.sh
```

## Run the Waste Audit

```bash
AWS_PROFILE=baba-admin \
  10-finops/scripts/waste-audit.sh
```

The snapshot review threshold defaults to 90 days and can be overridden:

```bash
SNAPSHOT_AGE_DAYS=120 \
AWS_PROFILE=baba-admin \
  10-finops/scripts/waste-audit.sh
```

## Generate the Consolidated Report

```bash
BASELINE_START=2026-08-20 \
BASELINE_END=2026-09-19 \
AWS_PROFILE=baba-admin \
OUTPUT_FILE=/tmp/baba-app-finops-report.json \
  10-finops/scripts/cost-report.sh
```

## Validated Results

The final Phase 10 validation established:

- USD 57.98 for the selected 30-day baseline after Cost Explorer data matured.
- EC2 Other, NAT Gateway, EBS, EKS, EC2 compute, VPC, and KMS as key cost areas.
- 100% tag compliance across 26 active in-scope resources.
- Two excluded KMS keys already pending deletion.
- Zero stopped instances, unattached volumes, old snapshots, idle Elastic IPs,
  active NAT Gateways, load balancers, RDS instances, or EKS clusters.
- Two retained Baba App ECR repositories.
- A projected October cost of USD 42.46 as of October 2, 2026 UTC.
- No verified recurring-savings claim until a complete post-optimization billing
  period is available.

## Optimization Actions

- Destroyed the development EKS runtime when not required.
- Changed the NAT Gateway, NAT Elastic IP, and private default route to follow
  the EKS lifecycle.
- Removed eight legacy unattached EBS volumes.
- Removed eight legacy EBS snapshots.
- Released one unused legacy Elastic IP.
- Deleted one retired Amazon Clone ECR repository.
- Reviewed Baba App ECR records and retained referenced platform manifests,
  attestations, and Sigstore artifacts.

## Documentation

- [Architecture](docs/architecture.md)
- [Security Controls](docs/security-controls.md)
- [Validation](docs/validation.md)

## Phase Status

Phase 10 implementation is complete. Verified savings remain intentionally
unquantified until Cost Explorer contains a complete post-optimization
comparison period.
