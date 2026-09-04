# Phase 03 - Terraform Infrastructure Foundation

## Overview

Phase 03 establishes the AWS infrastructure foundation for Baba App using Terraform.

The goal of this phase is to create a reusable, modular, secure, and cost-conscious AWS foundation that will support later phases including:

- Amazon EKS
- CI/CD
- GitOps
- Observability
- Identity and Access Management
- DevSecOps
- Cloud Security
- Kubernetes Security
- Incident Response
- Disaster Recovery

The infrastructure is deployed in AWS `us-east-1` and managed using Terraform with remote state stored securely in Amazon S3.

---

## Phase Objectives

This phase focuses on:

- Building reusable Terraform modules
- Creating a multi-AZ VPC architecture
- Separating public and private network tiers
- Providing controlled outbound internet access
- Creating secure container registries
- Enabling VPC network logging
- Encrypting sensitive infrastructure resources
- Securing Terraform remote state
- Running Infrastructure-as-Code security scanning
- Evaluating scanner findings using risk-based security decisions

---

## Architecture

Phase 03 provisions the following AWS infrastructure:

- Amazon VPC
- Two public subnets
- Two private subnets
- Internet Gateway
- NAT Gateway
- Elastic IP
- Public route table
- Private route table
- Application security group
- Amazon ECR frontend repository
- Amazon ECR backend repository
- VPC Flow Logs
- CloudWatch Log Group
- IAM role and policy for VPC Flow Logs
- Customer-managed AWS KMS keys
- Secure Terraform S3 remote state backend

---

## Directory Structure

```text
03-terraform/
├── README.md
├── bootstrap/
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── versions.tf
│   └── .terraform.lock.hcl
├── docs/
│   └── security-remediation.md
├── environments/
│   └── dev/
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars.example
│       ├── variables.tf
│       ├── versions.tf
│       └── .terraform.lock.hcl
└── modules/
    ├── ecr/
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── security/
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── vpc/
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

---

# Terraform Backend

## Remote State

Terraform state is stored remotely in Amazon S3 rather than on the local workstation.

The development environment uses:

```text
State Key: environments/dev/terraform.tfstate
Region: us-east-1
Locking: Native S3 lockfile
Encryption: SSE-KMS
```

The S3 backend is configured with Terraform native locking using:

```hcl
use_lockfile = true
```

This removes the need for the older DynamoDB-based state locking design.

---

## Terraform State Security

The Terraform state bucket includes the following protections:

- S3 versioning enabled
- Block Public Access enabled
- Customer-managed AWS KMS encryption
- KMS automatic key rotation
- Native S3 state locking
- Terraform `prevent_destroy`
- No hard-coded AWS credentials
- AWS IAM Identity Center authentication
- Explicit KMS configuration in the development backend

Terraform state contains sensitive infrastructure metadata, so the backend is treated as a security-critical component.

---

# Networking

## VPC

The Baba App development VPC uses:

```text
CIDR: 10.0.0.0/16
Region: us-east-1
```

The VPC has:

- DNS support enabled
- DNS hostnames enabled

---

## Availability Zones

The network spans two Availability Zones:

```text
us-east-1a
us-east-1b
```

This provides a foundation for higher availability when EKS and application workloads are introduced.

---

## Public Subnets

Public subnet CIDRs:

```text
10.0.1.0/24
10.0.2.0/24
```

Each subnet is deployed in a different Availability Zone.

The public subnets contain the Kubernetes tag:

```text
kubernetes.io/role/elb = 1
```

This prepares them for future internet-facing Kubernetes load balancers.

Automatic public IPv4 assignment is disabled:

```hcl
map_public_ip_on_launch = false
```

A subnet is still considered public because its route table contains a route to the Internet Gateway.

This design reduces accidental public exposure by requiring resources to explicitly receive public addressing when needed.

---

## Private Subnets

Private subnet CIDRs:

```text
10.0.11.0/24
10.0.12.0/24
```

Each private subnet is deployed in a separate Availability Zone.

The private subnets contain:

```text
kubernetes.io/role/internal-elb = 1
```

This prepares them for future internal Kubernetes load balancers.

Application and EKS workloads will primarily run in private subnets.

---

## Internet Gateway

An Internet Gateway is attached to the VPC.

The public route table contains:

```text
0.0.0.0/0 -> Internet Gateway
```

Both public subnets are associated with the public route table.

---

## NAT Gateway

A NAT Gateway provides outbound internet access for workloads running in the private subnets.

The development environment uses:

```text
1 NAT Gateway
1 Elastic IP
```

The NAT Gateway is located in the first public subnet.

The private route table contains:

```text
0.0.0.0/0 -> NAT Gateway
```

Both private subnets share this route table.

### Development Cost Decision

Only one NAT Gateway is used in the development environment to reduce AWS cost.

A production architecture would typically deploy one NAT Gateway per Availability Zone to improve availability and remove cross-AZ dependency.

This is an intentional development-environment tradeoff.

---

# Security Groups

An internal application security group is provisioned for future Baba App workloads.

## Backend Ingress

```text
Protocol: TCP
Port: 8080
Source: 10.0.0.0/16
```

## Frontend Ingress

```text
Protocol: TCP
Port: 3000
Source: 10.0.0.0/16
```

Both application ports are restricted to traffic originating from inside the VPC.

There is no unrestricted internet ingress.

---

## Outbound HTTPS

Outbound application traffic is currently restricted to:

```text
Protocol: TCP
Port: 443
Destination: 0.0.0.0/0
```

This allows HTTPS connectivity required for:

- AWS APIs
- software repositories
- package repositories
- container registries
- external HTTPS APIs

This rule is reviewed as an accepted development-environment risk and is documented later in this README.

---

# Amazon ECR

Two private Amazon ECR repositories are provisioned:

```text
baba-app-dev-frontend
baba-app-dev-backend
```

These repositories will store the Baba App frontend and backend container images.

---

## ECR Security Controls

The repositories include:

- Image tag immutability
- Image scanning on push
- Customer-managed AWS KMS encryption
- KMS automatic key rotation
- ECR lifecycle policies

---

## Immutable Image Tags

Image tag mutation is disabled.

This helps prevent an existing image tag from being silently replaced with different image content.

---

## Image Scanning

ECR image scanning is enabled on push.

This provides an additional vulnerability detection layer when application images are uploaded.

---

## ECR Encryption

Both repositories are encrypted using a dedicated customer-managed KMS key.

Controls include:

- Symmetric KMS encryption key
- Automatic key rotation
- KMS alias
- Encryption applied to both frontend and backend repositories

---

## ECR Lifecycle Management

Each ECR repository retains only the most recent:

```text
20 images
```

Older images are automatically expired.

This limits unnecessary storage growth and supports cost control.

---

# VPC Flow Logs

VPC Flow Logs are enabled for the Baba App VPC.

The configuration captures:

```text
Traffic Type: ALL
Destination: CloudWatch Logs
```

This provides visibility into accepted and rejected network traffic within the VPC.

---

## CloudWatch Log Group

The Flow Logs destination is:

```text
/aws/vpc/baba-app-dev/flow-logs
```

The log group uses:

```text
Retention: 365 days
Encryption: Customer-managed AWS KMS key
```

---

## Flow Log KMS Encryption

The CloudWatch Log Group is encrypted using a dedicated customer-managed KMS key.

The KMS policy allows the regional CloudWatch Logs service to use the key and restricts use through the CloudWatch Logs encryption context.

The KMS key also has:

- Automatic rotation enabled
- 30-day deletion window
- Dedicated alias
- Account administrative access

---

## Flow Log IAM Permissions

The VPC Flow Logs service assumes a dedicated IAM role.

The role trust policy allows:

```text
vpc-flow-logs.amazonaws.com
```

The IAM policy grants only the CloudWatch Logs actions required for Flow Log delivery:

```text
logs:CreateLogStream
logs:PutLogEvents
logs:DescribeLogGroups
logs:DescribeLogStreams
```

Permissions are scoped to the Flow Log CloudWatch Log Group.

---

# Infrastructure Security Scanning

Infrastructure-as-Code security validation was performed using:

- Checkov
- Trivy

These tools were used throughout Phase 03 rather than only at the end of development.

Findings were reviewed individually and classified based on:

- Actual security risk
- Development environment requirements
- Application functionality
- AWS architecture
- Operational impact
- Cost
- Compensating controls
- Future security improvements

The objective was not to blindly produce zero scanner findings.

---

# Checkov Results

## Initial Findings

Initial Checkov scanning identified issues including:

- ECR repositories using AES256 instead of customer-managed KMS
- Public subnets automatically assigning public IPv4 addresses
- CloudWatch Log Group retention below one year
- CloudWatch Log Group not encrypted with KMS

These findings were remediated.

---

## Final Checkov Result

```text
Passed checks: 59
Failed checks: 0
Skipped checks: 0
```

The final Checkov result confirms all evaluated Terraform controls pass the current policy set.

---

# Trivy Results

Initial Trivy scanning identified findings involving:

- ECR encryption
- Public subnet addressing
- Missing VPC Flow Logs
- CloudWatch Log encryption
- Terraform state encryption
- Terraform state logging
- Broad outbound HTTPS access

Most findings were remediated.

---

## Final Trivy Result

After remediation and removal of temporary Terraform plan files, two unique findings remain:

```text
AWS-0089 - LOW
Terraform state S3 bucket does not have server access logging enabled.

AWS-0104 - CRITICAL
Application security group permits outbound TCP/443 to 0.0.0.0/0.
```

These findings are intentionally reviewed and documented rather than automatically suppressed.

---

# Security Remediation Summary

## ECR Customer-Managed KMS Encryption

### Original Finding

ECR repositories used AWS-managed S3-style encryption rather than customer-managed KMS encryption.

### Status

```text
Remediated
```

### Resolution

A dedicated customer-managed KMS key was created and applied to:

```text
baba-app-dev-frontend
baba-app-dev-backend
```

KMS key rotation is enabled.

---

## Public Subnet Automatic Public IP Assignment

### Original Finding

Public subnets automatically assigned public IPv4 addresses.

### Status

```text
Remediated
```

### Resolution

Changed:

```hcl
map_public_ip_on_launch = true
```

to:

```hcl
map_public_ip_on_launch = false
```

The subnets remain public because they retain their Internet Gateway routing.

---

## Missing VPC Flow Logs

### Original Finding

VPC Flow Logs were not enabled.

### Status

```text
Remediated
```

### Resolution

VPC Flow Logs were enabled for:

```text
Traffic Type: ALL
```

with delivery to CloudWatch Logs.

---

## CloudWatch Flow Log Retention

### Original Finding

Flow Log retention was:

```text
30 days
```

### Status

```text
Remediated
```

### Resolution

Retention was increased to:

```text
365 days
```

---

## CloudWatch Flow Log KMS Encryption

### Original Finding

The Flow Log CloudWatch Log Group did not use a customer-managed KMS key.

### Status

```text
Remediated
```

### Resolution

A dedicated KMS key was created and attached to the Flow Log Log Group.

Controls include:

- Automatic rotation
- Regional CloudWatch Logs service principal
- Encryption context restriction
- Dedicated KMS alias

---

## Terraform State Customer-Managed KMS Encryption

### Original Finding

The Terraform state bucket used:

```text
AES256
```

rather than a customer-managed KMS key.

### Status

```text
Remediated
```

### Resolution

The Terraform state bucket was migrated to:

```text
SSE-KMS
```

using a dedicated customer-managed AWS KMS key.

The development Terraform backend was also updated to explicitly use the KMS key.

Terraform backend initialization, validation, and planning were successfully tested following the change.

---

# Accepted Risk

## AWS-0104 - Unrestricted HTTPS Egress

### Severity

```text
Critical
```

### Resource

```text
aws_vpc_security_group_egress_rule.https
```

### Configuration

```text
Protocol: TCP
Port: 443
Destination: 0.0.0.0/0
```

### Decision

```text
Accepted Development Risk
```

The application environment currently requires outbound HTTPS connectivity to support:

- AWS service APIs
- software package repositories
- container registries
- application dependencies
- external HTTPS APIs

The rule does not permit all outbound ports or protocols.

Outbound access is limited specifically to TCP port 443.

---

## Future Egress Hardening

Later phases can reduce public internet dependency through:

- AWS PrivateLink
- VPC endpoints
- ECR API endpoint
- ECR DKR endpoint
- Amazon S3 Gateway Endpoint
- AWS STS endpoint
- CloudWatch endpoints
- tighter network policies
- more restrictive security-group egress rules

The finding is therefore considered a known and tracked development-environment risk rather than an unidentified vulnerability.

---

# Deferred Control

## AWS-0089 - Terraform State S3 Logging Disabled

### Severity

```text
Low
```

### Decision

```text
Deferred
```

The Terraform state bucket currently includes:

- Block Public Access
- Versioning
- Customer-managed KMS encryption
- KMS automatic rotation
- Native Terraform S3 state locking
- `prevent_destroy`

S3 server access logging would require additional logging resources and result in additional storage and request costs.

Centralized AWS audit logging will be evaluated during later security-monitoring phases.

Potential future controls include:

- AWS CloudTrail
- S3 object-level data events
- centralized security logging
- log archival
- alerting for unauthorized state access

---

# Security Decision Model

Infrastructure scanner findings are classified into four categories:

```text
1. Remediate
2. Accepted Risk
3. Deferred Control
4. False Positive / Not Applicable
```

Scanner severity alone does not determine whether a control should be implemented.

Each finding is evaluated using:

- Attack surface
- Environment
- Business/application need
- Compensating controls
- AWS architecture
- Operational complexity
- Cost
- Planned future controls

This approach reflects real-world cloud security and DevSecOps risk management.

---

# Cost Optimization

Phase 03 includes several cost-conscious architecture decisions.

## Single NAT Gateway

The development environment uses a single NAT Gateway rather than one NAT Gateway per Availability Zone.

This reduces cost while accepting reduced high-availability characteristics in the development environment.

---

## ECR Lifecycle Policies

Only the most recent:

```text
20 images
```

are retained in each ECR repository.

This prevents unlimited image storage growth.

---

## KMS Costs

Customer-managed KMS keys were implemented selectively for security-sensitive resources including:

- Amazon ECR
- VPC Flow Logs
- Terraform state

Customer-managed keys may generate monthly AWS charges and API request charges.

These controls were implemented where the additional security value justified the cost.

---

## CloudWatch Costs

VPC Flow Logs generate:

- CloudWatch log ingestion charges
- CloudWatch storage charges

Retention is configured at 365 days to satisfy the desired security baseline.

---

## NAT Gateway Costs

The NAT Gateway is one of the more significant continuously billed resources in the development architecture.

Future FinOps automation can shut down or redesign development infrastructure when not required.

---

# Terraform Workflow

## Bootstrap

The Terraform backend infrastructure is managed separately.

Navigate to:

```bash
cd 03-terraform/bootstrap
```

Initialize:

```bash
terraform init
```

Validate:

```bash
terraform validate
```

Plan:

```bash
terraform plan \
  -var="state_bucket_name=${TF_STATE_BUCKET}"
```

---

## Development Environment

Navigate to:

```bash
cd 03-terraform/environments/dev
```

Initialize:

```bash
terraform init
```

If backend configuration changes:

```bash
terraform init -reconfigure
```

Validate:

```bash
terraform validate
```

Plan:

```bash
terraform plan
```

Apply:

```bash
terraform apply
```

---

# Terraform Validation

Before committing infrastructure changes:

```bash
terraform fmt -recursive
terraform validate
terraform plan
```

Terraform plans should always be reviewed before applying.

Special attention should be given to:

```text
destroy
replace
force replacement
```

actions.

For infrastructure security changes, the preferred plan is generally:

```text
0 to destroy
```

unless resource replacement has been intentionally reviewed.

---

# Security Validation

Run Checkov from the repository root:

```bash
checkov -d 03-terraform
```

Run Trivy:

```bash
trivy config 03-terraform
```

Temporary Terraform plan files should be deleted before the final Trivy scan because Trivy can scan them as separate Terraform plan snapshots and duplicate findings.

---

# Terraform Files That Must Not Be Committed

The repository ignores:

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
tfplan
*.tfplan
tfplan.json
*.tfplan.json
```

Terraform provider lock files should remain committed:

```text
.terraform.lock.hcl
```

This preserves reproducible provider dependency selection.

---

# AWS Authentication

AWS access is performed using AWS IAM Identity Center rather than long-lived hard-coded IAM credentials.

Terraform and AWS CLI operations use the configured AWS CLI SSO profile.

When the SSO session expires:

```bash
aws sso login --profile baba-admin
```

No AWS access keys or secret access keys are stored in Terraform configuration.

---

# Security Controls Implemented

Phase 03 now includes the following controls:

```text
✓ Terraform remote state
✓ Native S3 state locking
✓ S3 versioning
✓ S3 Block Public Access
✓ Terraform state KMS encryption
✓ KMS key rotation
✓ Terraform prevent_destroy
✓ Multi-AZ subnet design
✓ Disabled automatic public IP assignment
✓ Private workload subnets
✓ Restricted application ingress
✓ No SSH exposure
✓ No RDP exposure
✓ ECR immutable tags
✓ ECR image scanning
✓ ECR KMS encryption
✓ ECR lifecycle management
✓ VPC Flow Logs
✓ ALL traffic flow logging
✓ CloudWatch 365-day retention
✓ CloudWatch KMS encryption
✓ Restricted Flow Log IAM permissions
✓ Checkov IaC scanning
✓ Trivy IaC scanning
✓ Risk-based finding review
```

---

# Final Security Posture

## Checkov

```text
Passed: 59
Failed: 0
Skipped: 0
```

## Trivy

```text
1 Critical - Accepted development risk
1 Low      - Deferred control
```

There are no remaining unidentified Terraform security findings.

All remaining findings have documented dispositions and future remediation paths.

---

# Key Architecture Decisions

## Development vs Production

This phase intentionally distinguishes between development and production architecture.

### Development

Current design:

```text
Single NAT Gateway
Broad HTTPS egress
Cost-conscious resource deployment
```

### Production Direction

A production environment would likely introduce:

```text
NAT Gateway per Availability Zone
VPC endpoints
More restrictive egress
Centralized audit logging
Enhanced monitoring and alerting
Multi-account architecture
Additional IAM boundaries
Additional network segmentation
```

---

# Phase 03 Accomplishments

Phase 03 established a secure AWS Terraform foundation for Baba App.

Major accomplishments include:

- Created reusable Terraform modules
- Deployed a multi-AZ VPC architecture
- Separated public and private subnets
- Implemented controlled outbound internet access
- Created secure ECR repositories
- Added VPC Flow Logs
- Implemented CloudWatch log encryption
- Hardened Terraform state
- Implemented customer-managed KMS encryption
- Integrated Checkov and Trivy security validation
- Remediated identified IaC weaknesses
- Documented accepted and deferred risks
- Balanced security controls against development cost

---

# Phase Status

```text
Phase 03 - Terraform Infrastructure Foundation
Status: COMPLETE
```

---

# Next Phase

```text
Phase 04 - Amazon EKS
```

Phase 04 will build the Kubernetes platform on top of the AWS infrastructure foundation created during this phase.