# Phase 10 — FinOps Security Controls

## Overview

Phase 10 applies least privilege, separation of duties, human approval, and
evidence-based remediation to cloud cost management.

## Dedicated FinOps Identity

The FinOps role is separate from:

- The GitHub Actions ECR publishing role
- The GitHub Actions infrastructure role
- EKS human-access roles
- Kubernetes workload identities

This prevents reporting access from inheriting deployment or administrative
permissions.

The FinOps role may call `ce:ListCostAllocationTags` to inspect whether required
billing tag keys are active. It is not permitted to call
`ce:UpdateCostAllocationTagsStatus`; activation and deactivation remain
administrative operations.

Budget subscriber validation exposes only counts and delivery types. Email
addresses and other subscriber destinations are not written to consolidated
report artifacts.

## Trust Policy

Only the AWS IAM Identity Center `AdministratorAccess` permission-set role in
the same AWS account can assume the FinOps role.

The role session duration is limited to one hour.

## Allowed Access

The FinOps policy permits read-only access to:

- Cost Explorer reports, dimensions, tags, forecasts, and anomalies
- AWS Budgets configuration and notifications
- Resource Groups Tagging API data
- KMS key state
- EC2, EBS, snapshot, Elastic IP, and NAT inventory
- Load balancer inventory
- RDS inventory
- EKS cluster listing
- ECR repository and image metadata

## Denied Access

Validation confirmed that the role cannot:

- Terminate EC2 instances
- Delete EBS volumes or snapshots
- Release Elastic IPs
- Delete NAT Gateways
- Delete load balancers
- Delete RDS instances
- Delete EKS clusters
- Delete ECR images
- Create IAM roles
- Attach administrative policies
- Modify the AWS budget

These operations remain implicitly denied.

## Human-Approved Remediation

Waste findings are not deleted automatically.

Before removal, the operator verifies:

1. Ownership and project tags
2. Runtime attachment or association state
3. Repository and infrastructure references
4. DNS or service dependencies where applicable
5. Recent image-pull or resource-usage evidence
6. Terraform state ownership
7. The exact deletion target

## Terraform Plan Integrity

Infrastructure changes use saved Terraform plans whenever practical.

The NAT optimization was validated to contain only:

- NAT Gateway deletion
- NAT Elastic IP release
- Private default-route deletion

The reviewed plan was applied without replacing or deleting retained
infrastructure.

## Cost-Safe Runtime Default

`enable_eks=false` remains the cost-safe development default.

The GitHub Actions lifecycle workflow explicitly passes the requested value as
a Terraform command-line variable, preventing the local default from
overriding approved provisioning.

## Security-Control Retention

Cost optimization does not remove:

- CloudTrail management-event auditing
- CloudWatch audit logs
- KMS encryption
- Terraform state protection
- ECR encryption and scanning
- VPC flow logging
- IAM separation
- GitHub OIDC authentication

## Tag Governance

Terraform provider default tags enforce ownership and cost-allocation metadata.
Module-level Phase tags identify the portfolio phase responsible for each
resource.

The project-filtered tag audit has a documented discovery limitation: resources
without `Project=baba-app` are not returned by that query. This prevents the
compliance percentage from being interpreted as a complete account-wide
inventory assertion.

## Credential Handling

Temporary STS credentials used during validation were:

- Written only to a temporary file
- Restricted with mode `600`
- Used in a subshell
- Deleted immediately after testing
- Never committed to the repository

## Reporting Data

Reports contain resource metadata and cost information. They do not contain
AWS secret keys, session tokens, passwords, or application secrets.

Generated reports are written outside the repository unless intentionally
selected for evidence publication.

## Destructive Automation Boundary

Budget alerts and anomaly alerts notify humans. They do not invoke Terraform,
delete resources, or bypass approval controls.

This preserves availability and reduces the risk of cost signals causing
unintended outages.
