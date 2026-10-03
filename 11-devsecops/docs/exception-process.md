# Phase 11 Security Exception Process

## Purpose

This procedure governs security findings that cannot be remediated immediately
without creating a documented, time-limited exception.

An exception does not declare a finding safe. It records why the risk is being
temporarily accepted or deferred, who owns it, which controls reduce exposure,
and when the decision must be reviewed again.

## Scope

This process applies to findings suppressed or excluded from Baba App security
scanning, including:

- secret detection;
- static application security testing;
- dependency and container vulnerability scanning;
- Terraform and AWS misconfiguration scanning;
- Kubernetes manifest scanning; and
- scanner false positives or scanner-version limitations.

Verified secrets are not eligible for exceptions. A verified secret must be
revoked or rotated, removed from the repository and history where appropriate,
and investigated before delivery continues.

## Governing Files

| File | Purpose |
| --- | --- |
| `11-devsecops/policies/security-gates.json` | Defines gates, severities, remediation targets, exception requirements, and evidence expectations. |
| `11-devsecops/policies/security-exceptions.json` | Provides the central inventory of approved, planned, false-positive, expired, and closed exceptions. |
| `11-devsecops/scripts/validate-security-policy.sh` | Validates the policies and reconciles the registry with scanner-native suppressions. |
| `05-cicd/trivy-container-ignore.yaml` | Supplies Trivy with package-specific CVE exceptions required during scanning. |

Scanner-native ignore files and inline suppression comments are enforcement
inputs, not the system of record. Every active suppression must also have a
matching record in `security-exceptions.json`.

## Roles and Responsibilities

| Role | Responsibility |
| --- | --- |
| Finding owner | Investigates the finding, attempts remediation, and documents the proposed treatment. |
| Platform Security | Reviews severity, exploitability, scope, compensating controls, and expiration. |
| Technical owner | Confirms operational impact and owns planned remediation. |
| Independent approver | Approves risk acceptance for production or customer environments. |

Baba App is currently a single-maintainer portfolio environment. Its exception
records therefore represent documented owner review, not independent separation
of duties. A commercial or production deployment must assign exception approval
to someone other than the requester or code author.

## Remediation Targets

The following targets begin when a finding is confirmed:

| Severity | Target |
| --- | ---: |
| Critical | 1 day |
| High | 7 days |
| Medium | 30 days |
| Low | 90 days |

Remediation is preferred over suppression. When remediation is unavailable, the
owner must document the reason before the applicable target expires.

## Exception Requirements

Every exception must contain:

- a unique exception ID;
- scanner and finding ID;
- affected file, package, resource, or deployment scope;
- risk severity;
- technical and business rationale;
- compensating controls;
- accountable owner;
- lifecycle status;
- creation and expiration dates; and
- a review, ticket, pull request, or backlog reference.

Exceptions may remain active for no more than 90 days. A shorter period should
be used when a patch or planned phase is expected sooner.

## Lifecycle Statuses

| Status | Meaning |
| --- | --- |
| `accepted` | The risk was reviewed and is temporarily accepted within the documented scope. |
| `remediation-planned` | Corrective work is scheduled but cannot be completed immediately. |
| `false-positive` | The scanner result does not accurately represent the implemented control or current platform state. |
| `expired` | The review window ended and the record is retained as historical evidence. |
| `closed` | The finding was remediated or the suppression was removed. |

Only `accepted`, `remediation-planned`, and `false-positive` records are treated
as active by the validator.

## Request and Review Workflow

1. Reproduce the finding with the relevant scanner.
2. Confirm the affected component, version, resource, and deployment context.
3. Check whether an upgrade, configuration change, or code change can remediate
   the finding safely.
4. Determine severity using exploitability, exposure, data sensitivity, blast
   radius, and existing protections.
5. Document why immediate remediation is unavailable or why the result is a
   false positive.
6. Identify concrete compensating controls already implemented.
7. Assign an owner and expiration date.
8. Add the governance record and scanner-native suppression in the same pull
   request.
9. Run the security policy validator and applicable scanner workflows.
10. Obtain the approval required for the target environment before merge.

Adding only a scanner ignore is prohibited. Adding only a registry record is
also invalid because it creates a stale active exception.

## Validation

Run the validator from the repository root:

```bash
11-devsecops/scripts/validate-security-policy.sh
```

The command fails when it detects:

- malformed policy JSON;
- missing required fields;
- duplicate record or gate identifiers;
- unsupported severities or statuses;
- invalid or reversed dates;
- validity periods longer than 90 days;
- expired active exceptions;
- native suppressions without governance records; or
- active governance records without native suppressions.

`VALIDATION_DATE` can test expiration behavior without changing the workstation
clock:

```bash
VALIDATION_DATE=2026-10-07 \
  11-devsecops/scripts/validate-security-policy.sh
```

With the current records, that test is expected to fail because the four
`libuuid1` CVE exceptions expire on October 6, 2026.

## Renewal

Before renewal, the owner must rerun the scanner and determine whether:

- a fixed dependency or base image is available;
- the affected component remains deployed;
- exploitability or severity changed;
- compensating controls remain effective; and
- the planned remediation milestone remains valid.

A renewal must update the rationale where conditions changed, set a new review
date within the 90-day maximum, and produce a new review reference. Expiration
must not be extended automatically merely to keep CI passing.

## Closure

When a finding is remediated:

1. remove the scanner-native suppression;
2. change the registry record to `closed`;
3. retain the finding and remediation reference as evidence;
4. rerun the validator and affected scanner; and
5. confirm that the scanner succeeds without the suppression.

Closed records remain in the registry to preserve the decision history.

## Phase-Deferred Findings

Several current exceptions represent explicit roadmap commitments:

| Target phase | Planned control |
| --- | --- |
| Phase 12 â€” Security Monitoring | CloudTrail and audit-event alerting. |
| Phase 14 â€” Kubernetes Security | Kubernetes NetworkPolicies and additional cluster hardening. |
| Phase 18 â€” Disaster Recovery | Cross-Region audit archive replication and recovery validation. |

Phase deferral does not make an exception permanent. Each record still expires
and must be reviewed even when its target phase has not started.

## Evidence

Retain the following evidence with the pull request or validation documentation:

- original scanner finding;
- remediation investigation;
- exception record;
- approval or owner-review reference;
- passing policy-validation output;
- applicable CI scan results; and
- closure or renewal evidence.

The repository currently documents policy and validation evidence, but required
merge checks and independent production approval remain Phase 11 hardening work.