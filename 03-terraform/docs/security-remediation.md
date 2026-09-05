# Phase 03 - Terraform Security Remediation Report

## Overview

This document records the Infrastructure-as-Code security findings identified during Phase 03 of the Baba App project and the remediation decisions made for each finding.

Terraform configuration was evaluated using:

- Checkov

- Trivy

Findings were reviewed based on:

- actual security risk

- environment

- application requirements

- operational impact

- AWS architecture

- compensating controls

- cost

- future remediation opportunities

The goal was not to force all scanners to report zero findings. The goal was to make risk-based security decisions and document the outcome.

---

# Final Security Scan Results

## Checkov

Final Checkov result:

```text

Passed checks: 59

Failed checks: 0

Skipped checks: 0

```

All Checkov findings identified during Phase 03 were remediated.

---

## Trivy

Final Trivy result:

```text

AWS-0089 - LOW

Terraform state S3 bucket does not have server access logging enabled.

AWS-0104 - CRITICAL

Application security group permits outbound TCP/443 to 0.0.0.0/0.

```

Both remaining findings were reviewed and assigned documented risk dispositions.

---

# Remediated Findings

## 1. ECR Repositories Not Using Customer-Managed KMS Encryption

### Original Finding

Amazon ECR repositories were encrypted using AES256 instead of a customer-managed AWS KMS key.

### Affected Resources

```text

baba-app-dev-frontend

baba-app-dev-backend

```

### Status

```text

Remediated

```

### Remediation

A dedicated customer-managed KMS key was created for the ECR repositories.

The repositories were configured with:

```text

Encryption Type: KMS

Customer-Managed Key: Enabled

KMS Key Rotation: Enabled

```

Both repositories also retain the following controls:

- immutable image tags

- scan on push

- lifecycle policies

- private repository configuration

### Result

The ECR KMS findings no longer appear in Checkov or Trivy.

---

# 2. Public Subnets Automatically Assigning Public IPv4 Addresses

### Original Finding

The public subnets were configured with:

```hcl

map_public_ip_on_launch = true

```

This meant instances launched into the subnets could automatically receive public IPv4 addresses.

### Status

```text

Remediated

```

### Remediation

The configuration was changed to:

```hcl

map_public_ip_on_launch = false

```

The subnets remain public because their route table still includes:

```text

0.0.0.0/0 -> Internet Gateway

```

This allows resources that genuinely require public access to be configured explicitly instead of receiving public IP addresses automatically.

### Result

The subnet findings no longer appear in Checkov or Trivy.

---

# 3. VPC Flow Logs Missing

### Original Finding

The VPC did not have Flow Logs enabled.

### Status

```text

Remediated

```

### Remediation

VPC Flow Logs were enabled with:

```text

Traffic Type: ALL

Destination: CloudWatch Logs

```

This provides visibility into accepted and rejected network traffic across the VPC.

### Supporting Resources

The implementation includes:

- CloudWatch Log Group

- IAM role for VPC Flow Logs

- IAM policy scoped to CloudWatch Logs

- VPC Flow Log resource

### Result

The missing VPC Flow Logs finding was eliminated.

---

# 4. CloudWatch Flow Log Retention Too Short

### Original Finding

The CloudWatch Log Group used:

```text

30-day retention

```

Checkov required at least one year of retention.

### Status

```text

Remediated

```

### Remediation

Retention was increased to:

```text

365 days

```

### Result

The CloudWatch retention finding now passes Checkov.

---

# 5. CloudWatch Flow Log Group Missing Customer-Managed KMS Encryption

### Original Finding

The VPC Flow Log CloudWatch Log Group was not encrypted with a customer-managed KMS key.

### Status

```text

Remediated

```

### Remediation

A dedicated KMS key was created for VPC Flow Logs.

The key includes:

- automatic KMS key rotation

- 30-day deletion window

- dedicated KMS alias

- CloudWatch Logs service access

- encryption-context restriction

- account administrative access

The CloudWatch Log Group was updated with:

```hcl

kms_key_id = aws_kms_key.vpc_flow_logs.arn

```

### Result

The CloudWatch KMS encryption finding now passes Checkov and no longer appears in Trivy.

---

# 6. Terraform State Bucket Using AES256 Instead of Customer-Managed KMS

### Original Finding

The Terraform state S3 bucket used:

```text

AES256

```

rather than a customer-managed AWS KMS key.

### Status

```text

Remediated

```

### Remediation

A dedicated customer-managed KMS key was created for Terraform state.

The S3 encryption configuration was changed to:

```text

SSE-KMS

```

The development backend was also updated to explicitly use the Terraform state KMS key.

### Additional State Security Controls

The state backend also includes:

- S3 versioning

- Block Public Access

- native S3 state locking

- `prevent_destroy`

- no hard-coded AWS credentials

- AWS IAM Identity Center authentication

- KMS key rotation

### Validation

After migration to SSE-KMS, the backend was reinitialized and validated successfully.

Terraform was able to:

```text

initialize

validate

read remote state

generate plans

```

without loss of state access.

### Result

The previous Trivy HIGH finding for lack of customer-managed KMS encryption was eliminated.

---

# Accepted Risk

## AWS-0104 - Security Group Allows Unrestricted HTTPS Egress

### Scanner Severity

```text

Critical

```

### Resource

```text

aws_vpc_security_group_egress_rule.https

```

### Current Configuration

```text

Protocol: TCP

Port: 443

Destination: 0.0.0.0/0

```

### Status

```text

Accepted Development Risk

```

### Rationale

The development environment currently requires outbound HTTPS connectivity for:

- AWS APIs

- package repositories

- container registries

- software dependencies

- external HTTPS APIs

The rule does not permit unrestricted access across all ports and protocols.

Outbound access is limited to:

```text

TCP 443

```

### Security Consideration

The finding is valid.

Allowing HTTPS egress to any IPv4 destination provides broader network access than would normally be desirable in a tightly controlled production environment.

It is therefore not classified as a false positive.

### Future Remediation

Later phases can reduce this exposure using:

- AWS PrivateLink

- VPC interface endpoints

- Amazon S3 Gateway Endpoint

- ECR API endpoint

- ECR DKR endpoint

- AWS STS endpoint

- CloudWatch endpoints

- more restrictive destination controls

- Kubernetes NetworkPolicies

- centralized egress filtering

### Risk Disposition

```text

Accepted for the development environment.

Future hardening planned.

```

---

# Deferred Control

## AWS-0089 - Terraform State Bucket Logging Disabled

### Scanner Severity

```text

Low

```

### Resource

```text

Terraform state S3 bucket

```

### Status

```text

Deferred

```

### Rationale

The Terraform state bucket already includes the following protections:

- S3 versioning

- Block Public Access

- customer-managed KMS encryption

- automatic KMS key rotation

- native S3 state locking

- Terraform `prevent_destroy`

S3 server access logging would require additional logging resources and introduce additional storage and request costs.

For the current development environment, the additional control was not considered necessary enough to justify expanding the infrastructure solely to eliminate a LOW scanner finding.

### Future Remediation

Centralized audit logging will be evaluated in later phases using controls such as:

- AWS CloudTrail

- S3 object-level data events

- centralized log aggregation

- log archival

- security alerts

- SIEM integration

### Risk Disposition

```text

Deferred control.

Revisit during security monitoring and centralized logging phases.

```

---

# Security Decision Model

Infrastructure security findings in Baba App are classified into one of four categories:

```text

1\. Remediate

2\. Accepted Risk

3\. Deferred Control

4\. False Positive / Not Applicable

```

The scanner severity alone does not determine the final implementation decision.

Each finding is reviewed using:

- actual attack surface

- likelihood

- technical impact

- environment

- business/application need

- compensating controls

- cost

- architecture

- future controls

This reflects a practical DevSecOps and cloud security risk-management approach.

---

# Remediation Summary

| Finding | Severity | Status |

|---|---:|---|

| ECR repositories not using customer-managed KMS | High/Policy Failure | Remediated |

| Public subnets auto-assigning public IP addresses | High/Policy Failure | Remediated |

| VPC Flow Logs not enabled | Medium | Remediated |

| CloudWatch retention below one year | Policy Failure | Remediated |

| CloudWatch Flow Logs not using KMS | Low/Policy Failure | Remediated |

| Terraform state not using customer-managed KMS | High | Remediated |

| Terraform state S3 access logging disabled | Low | Deferred |

| HTTPS egress to `0.0.0.0/0` | Critical | Accepted Risk |

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

All remaining Trivy findings have been reviewed and have documented dispositions.

There are no remaining unidentified Terraform security findings.

---

# Key Security Improvements Completed

Phase 03 security remediation resulted in:

```text

✓ ECR customer-managed KMS encryption

✓ ECR immutable image tags

✓ ECR scan-on-push

✓ Public subnet automatic public IP assignment disabled

✓ VPC Flow Logs enabled

✓ ALL VPC traffic captured

✓ CloudWatch retention increased to 365 days

✓ CloudWatch Flow Log KMS encryption

✓ Dedicated Flow Log IAM role

✓ Least-privilege Flow Log IAM permissions

✓ Terraform state customer-managed KMS encryption

✓ Terraform state versioning

✓ Terraform state Block Public Access

✓ Native S3 state locking

✓ KMS key rotation

✓ Temporary Terraform plan files removed before final scanning

✓ Checkov security validation

✓ Trivy security validation

✓ Accepted-risk documentation

✓ Deferred-control documentation

```

---

# Cost Considerations

Security remediation was evaluated alongside AWS cost.

Controls that may introduce ongoing AWS charges include:

- customer-managed KMS keys

- NAT Gateway

- CloudWatch Logs

- S3 storage

- VPC Flow Logs

Security findings were therefore evaluated based on both risk reduction and operational cost.

The project intentionally avoids provisioning additional resources solely to make scanner output report zero findings when the security value does not justify the cost for the current development environment.

---

# Future Security Work

Later Baba App phases will revisit infrastructure security as additional capabilities are introduced.

Future improvements may include:

- VPC endpoints

- AWS PrivateLink

- centralized CloudTrail

- CloudTrail S3 data events

- GuardDuty

- AWS Security Hub

- AWS Config

- SIEM integration

- Kubernetes NetworkPolicies

- EKS security controls

- application security

- supply-chain security

- incident response

- centralized audit logging

- multi-account security architecture

---

# Phase 03 Security Conclusion

Phase 03 established a secure Terraform foundation for Baba App while demonstrating risk-based cloud security decision-making.

The project did not simply suppress or ignore scanner findings.

Each finding was:

```text

identified

reviewed

classified

remediated or documented

validated

```

The final result provides a strong infrastructure baseline for:

```text

Phase 04 - Amazon EKS

```

---

# Phase 04 - EKS Security Scan Review

## Scan Summary

### Checkov

Current result after enabling EKS control-plane logging:

```text
Passed checks: 74
Failed checks: 3
Skipped checks: 0
```

Remaining EKS findings:

- `CKV_AWS_39` - public EKS endpoint enabled
- `CKV_AWS_58` - explicit EKS secrets encryption configuration not present
- `CKV_AWS_339` - Kubernetes 1.36 reported as unsupported by the installed Checkov policy

### Trivy

EKS findings were reduced from seven to two after enabling all EKS control-plane log types.

Remaining EKS findings:

- `AWS-0039` - explicit secrets encryption configuration not present
- `AWS-0040` - public cluster endpoint enabled

---

## Remediated Finding

### EKS Control Plane Logging

**Status:** Remediated

**Findings:**

- Checkov `CKV_AWS_37`
- Trivy `AWS-0038`

**Remediation:**

All supported EKS control-plane log types were enabled:

- `api`
- `audit`
- `authenticator`
- `controllerManager`
- `scheduler`

**Rationale:**

Control-plane logging improves security auditing, authentication visibility, incident investigation, troubleshooting, and operational visibility.

**Result:**

Checkov now passes `CKV_AWS_37`, and the five Trivy control-plane logging findings no longer appear.

---

## Accepted / Documented Findings

### Public EKS API Endpoint

**Status:** Accepted Development Risk

**Findings:**

- Checkov `CKV_AWS_39`
- Trivy `AWS-0040`

**Current configuration:**

- private endpoint access enabled
- public endpoint access enabled
- public endpoint restricted to the administrator's approved `/32` CIDR
- `0.0.0.0/0` access is not permitted

**Rationale:**

The development cluster is administered from a local workstation outside the VPC. A private-only endpoint would require additional private connectivity such as a VPN, bastion host, or another private network path.

The public endpoint remains enabled for development administration, but exposure is reduced by restricting access to a single approved administrator CIDR.

**Future hardening:**

- move to private-only EKS API access
- use VPN or another private administrative path
- review administrator CIDRs regularly

**Risk disposition:**

```text
Accepted for the development environment.
Public access is restricted to an approved /32 CIDR.
```

---

### EKS Secrets Encryption

**Status:** Accepted Managed-Service Control

**Findings:**

- Checkov `CKV_AWS_58`
- Trivy `AWS-0039`

**Current configuration:**

- Kubernetes version: 1.36
- no additional customer-managed KMS key is configured specifically for Kubernetes API data

**Rationale:**

The development cluster relies on the encryption capabilities provided by modern Amazon EKS rather than adding another customer-managed KMS key solely to satisfy the scanner.

This avoids unnecessary KMS cost and operational overhead for the current development environment.

**Future hardening:**

Evaluate customer-managed KMS encryption when required by production architecture, compliance requirements, customer-managed key ownership requirements, or stricter separation-of-duties requirements.

**Risk disposition:**

```text
Accepted managed-service control for development.
Reevaluate for production or compliance-driven environments.
```

---

### Kubernetes Version Support

**Status:** Scanner Limitation / False Positive

**Finding:**

- Checkov `CKV_AWS_339`

**Current configuration:**

```text
Kubernetes version: 1.36
```

**Scanner context:**

The installed Homebrew Checkov package is version:

```text
3.3.10
```

The installed scanner policy does not currently recognize EKS 1.36 correctly.

**Rationale:**

The Terraform configuration intentionally uses Kubernetes 1.36. The project will not downgrade the cluster solely to satisfy a stale scanner policy.

**Action:**

- revalidate after the Checkov Homebrew package or policy data is updated
- continue monitoring the AWS EKS Kubernetes support lifecycle
- record the scanner version with future scan evidence

---

## Phase 04 Security Summary

| Finding | Scanner | Status | Disposition |
|---|---|---|---|
| EKS control-plane logging disabled | Checkov / Trivy | Remediated | All five log types enabled |
| Public EKS API endpoint enabled | Checkov / Trivy | Open | Accepted development risk with `/32` restriction |
| Explicit EKS secrets encryption block absent | Checkov / Trivy | Open | Accepted managed-service control |
| Kubernetes 1.36 reported unsupported | Checkov | Open | Scanner limitation / false positive |

---

## Phase 04 Current Security Posture

The EKS foundation currently includes:

- Kubernetes 1.36
- worker nodes in private subnets
- private EKS API endpoint access enabled
- public EKS API endpoint restricted to an approved administrator `/32`
- all five EKS control-plane log types enabled
- dedicated EKS control-plane IAM role
- dedicated managed-node IAM role
- ECR read-only permissions for worker nodes
- no implicit public SSH access to the managed node group
- Checkov validation
- Trivy validation
- documented dispositions for all remaining EKS findings

The Phase 04 review demonstrates risk-based cloud security decision-making rather than automatically suppressing findings or changing architecture solely to produce a zero-finding scanner report.
