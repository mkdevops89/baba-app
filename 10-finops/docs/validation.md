# Phase 10 — FinOps Validation

## Overview

This document records the validation evidence for cost visibility, tagging,
budget monitoring, anomaly detection, least-privilege access, waste detection,
and approved cost optimization.

## Acceptance Criteria

| Criterion | Result |
|---|---|
| Reproducible 30-day cost baseline | PASS |
| Current-month forecast | PASS |
| USD 50 monthly budget validated | PASS |
| Budget notifications validated | PASS |
| Cost anomaly subscription validated | PASS |
| Required active-resource tags | PASS |
| Dedicated read-only FinOps role | PASS |
| Positive IAM permission tests | PASS |
| Negative IAM permission tests | PASS |
| Repeatable cloud waste audit | PASS |
| EKS lifecycle destruction | PASS |
| NAT lifecycle alignment | PASS |
| Retained infrastructure drift-free | PASS |
| Security and audit controls retained | PASS |

## Cost Baseline

Validated period:

- Start inclusive: August 20, 2026
- End exclusive: September 19, 2026
- Metric: UnblendedCost
- Final observed total after data maturation: USD 57.98

The principal cost areas were:

- EC2 Other
- NAT Gateway
- EBS
- Amazon EKS
- EC2 compute
- Amazon VPC
- AWS KMS

The initial analysis identified NAT Gateway hours as the largest avoidable
recurring cost driver.

## Current-Month Forecast

The integrated report generated on October 2, 2026 UTC returned:

- Month start: October 1, 2026
- Forecast start: October 2, 2026
- Forecast end: November 1, 2026
- Projected month total: USD 42.46
- Monthly budget: USD 50

Cost Explorer dates were changed to UTC after validation exposed a local-date
and AWS-billing-date boundary mismatch.

## Budget Validation

Budget:

- Name: `baba-app-monthly-budget`
- Type: Cost
- Period: Monthly
- Limit: USD 50

Notifications:

- Actual spend greater than 50%
- Actual spend greater than 80%
- Actual spend greater than 100%
- Forecasted spend greater than 100%

No budget notification is permitted to destroy infrastructure automatically.

## Cost Anomaly Detection

The existing daily email subscription was validated and adjusted to require:

- Absolute impact greater than or equal to USD 5
- Percentage impact greater than or equal to 20%

The earlier USD 100 and 40% thresholds were too high for the scale of the
development account.

## Tag Compliance

Required standard:

| Tag | Required value |
|---|---|
| Project | `baba-app` |
| Environment | `dev` |
| ManagedBy | `Terraform` |
| Owner | `platform-engineering` |
| CostCenter | `portfolio` |
| Phase | Owning portfolio phase |

Final result:

- Discovered resources: 28
- Pending-deletion KMS exceptions: 2
- Active in-scope resources: 26
- Compliant resources: 26
- Noncompliant resources: 0
- Compliance: 100%

## Least-Privilege FinOps Role

The dedicated role successfully executed:

- Cost baseline generation
- Budget inspection
- Anomaly inspection
- Tag audit
- Regional waste audit
- ECR inventory

Positive IAM simulation returned `allowed` for the required Cost Explorer,
Budgets, tagging, KMS-description, EC2-description, ECR-description,
EKS-listing, ELB-description, and RDS-description actions.

Negative IAM simulation returned `implicitDeny` for destructive actions,
including infrastructure and ECR deletion.

## EKS Lifecycle Validation

The Infrastructure Lifecycle workflow successfully:

1. Generated a destroy plan
2. Uploaded and transferred the reviewed saved plan
3. Applied the exact saved plan
4. Removed the development EKS runtime
5. Validated EKS destruction

The workflow completed successfully after the required Terraform refresh and
IAM deletion-check permissions were added.

## NAT Lifecycle Validation

Terraform was updated so the NAT Gateway, NAT Elastic IP, and private default
route follow `enable_eks`.

The saved optimization plan contained exactly three managed-resource deletions:

- NAT Gateway
- NAT Elastic IP
- Private default route

Post-apply validation confirmed:

- All three resources were removed from Terraform state
- The Elastic IP allocation no longer existed
- The private route table had no NAT default route
- The NAT Gateway reached the deleted state
- The retained configuration was drift-free

## Legacy Resource Cleanup

Ownership and dependency validation preceded every deletion.

Removed resources:

- Eight unattached legacy EBS volumes
- Eight legacy EBS snapshots
- One unused and unassociated legacy Elastic IP
- One retired `Amazon-Clone-DevSecOps` ECR repository

The ECR repository had no current project reference, ECS consumer,
image-based Lambda function, App Runner service, repository policy, recent
image push, or recent image pull.

## Baba App ECR Review

The backend and frontend repositories were retained.

Lifecycle preview found no safely expiring records because the untagged records
included:

- OCI platform image manifests
- Docker attestations
- Sigstore bundles

Deleting these solely because they were untagged could break multi-platform
images or supply-chain verification.

## Final Waste Audit

The read-only waste audit returned `PASS` with:

- 0 stopped instances
- 0 unattached volumes
- 0 snapshots older than 90 days
- 0 idle Elastic IPs
- 0 active NAT Gateways
- 0 modern load balancers
- 0 classic load balancers
- 0 RDS database instances
- 0 EKS clusters
- 2 retained ECR repositories

## Consolidated Reporting Validation

The final report includes:

- Baseline costs
- Daily costs
- Service costs
- Key cost centers
- Current-month projection
- Budget utilization
- Budget notifications
- Anomaly findings
- Tag compliance
- Waste findings
- ECR inventory
- Optimization actions
- Savings-verification status

Both the output file and standard-output JSON passed `jq empty`.

## Terraform Validation

Final checks completed successfully:

- `terraform fmt -check -recursive 03-terraform`
- `terraform validate`
- Full non-targeted plan with `enable_eks=false`
- No Terraform drift
- No saved plan files left in the repository
- `git diff --check`

## Savings Measurement

Recurring savings are not claimed prematurely.

The report retains:

```text
verified_monthly_savings_usd: null
```

A verified savings value requires a complete post-EKS and post-NAT billing
period compared with an appropriate pre-optimization baseline.

## Final Status

Phase 10 meets its acceptance criteria.

Cost visibility, tagging, budget controls, anomaly detection, waste discovery,
least-privilege reporting, EKS lifecycle management, and NAT lifecycle
optimization are implemented and validated without weakening the security
baseline.
