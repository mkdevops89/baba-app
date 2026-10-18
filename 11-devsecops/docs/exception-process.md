# Phase 11 Security Exception Process

## Purpose

This procedure governs security findings that cannot be remediated immediately.
An exception does not declare a finding safe. It records why risk is temporarily
accepted or deferred, who owns it, what limits exposure, and when it must be
reviewed again.

## Scope

The process applies to suppressions for secret detection, static analysis,
dependency and container scanning, Terraform scanning, Kubernetes manifest
scanning, false positives, and scanner limitations. Verified secrets are never
eligible: they must be revoked or rotated, removed where appropriate, and
investigated before delivery continues.

## Systems of Record

| File | Purpose |
| --- | --- |
| `11-devsecops/policies/security-gates.json` | Gate definitions, severity targets, required fields, and evidence expectations. |
| `11-devsecops/policies/security-exceptions.json` | Central exception inventory and lifecycle history. |
| `11-devsecops/scripts/validate-security-policy.sh` | Structural, date, and bidirectional reconciliation validation. |
| `05-cicd/trivy-container-ignore.yaml` | Package-scoped enforcement entries consumed by Trivy. |

Native ignores and inline comments are enforcement inputs, not risk approvals.
Every active suppression must have a matching registry record, and every active
registry record must map to an enforcement input.

## Responsibilities

| Role | Responsibility |
| --- | --- |
| Finding owner | Reproduce the finding, attempt remediation, and document treatment. |
| Platform Security | Review severity, exploitability, scope, controls, and expiration. |
| Technical owner | Confirm operational impact and own planned remediation. |
| Independent approver | Approve production or customer risk acceptance. |

Baba App is a single-maintainer portfolio. Its records demonstrate owner review,
not production separation of duties. Commercial deployments must ensure the
requester or code author cannot independently approve their own exception.

## Remediation Targets

| Severity | Target |
| --- | ---: |
| Critical | 1 day |
| High | 7 days |
| Medium | 30 days |
| Low | 90 days |

## Required Fields

Every exception includes a unique ID, scanner, finding ID, affected scope, risk,
rationale, compensating controls, owner, lifecycle status, creation date,
expiration date, and review reference. A reassessment should also record
`last_reviewed_date` and `review_evidence` so an extension is distinguishable
from an automatic date change.

Exceptions may remain active for no more than 90 days. Use a shorter period when
an upstream patch or planned phase is expected sooner.

## Lifecycle Statuses

| Status | Meaning |
| --- | --- |
| `accepted` | Temporarily accepted within the documented scope. |
| `remediation-planned` | Corrective work is scheduled but not immediately available. |
| `false-positive` | The scanner result does not represent the implemented control or state. |
| `expired` | The review window ended; the record remains as history. |
| `closed` | The finding was remediated or its suppression was removed. |

Only `accepted`, `remediation-planned`, and `false-positive` are active.

## Request and Review Workflow

1. Reproduce the finding with the relevant scanner.
2. Confirm the affected component, version, scope, and environment.
3. Attempt an upgrade, configuration change, or code remediation.
4. Evaluate severity, reachability, exposure, data sensitivity, and blast radius.
5. Document why immediate remediation is unavailable or why the result is false.
6. Record concrete compensating controls.
7. Assign an owner and expiration no more than 90 days away.
8. Add the governance record and native suppression in the same pull request.
9. Run policy tests and all applicable scanners.
10. Obtain the approval required for the target environment.

Adding only an ignore is prohibited. Adding only an active registry record is
also invalid because it misrepresents actual scanner enforcement.

## Validation

```bash
11-devsecops/scripts/validate-security-policy.sh
11-devsecops/scripts/test-security-policy.sh
```

The validator rejects malformed policy, missing fields, duplicate identifiers,
unsupported values, invalid dates, validity beyond 90 days, expired active
records, undocumented suppressions, and active records without suppressions.

Test expiration behavior without changing the workstation clock:

```bash
VALIDATION_DATE=2026-11-08 \
  11-devsecops/scripts/validate-security-policy.sh
```

With the October 18 reconciliation, that command is expected to fail because
the four active Debian runtime exceptions expire on November 7, 2026. Five
earlier runtime records are retained with `closed` status as audit history.

## Renewal

Before renewal, rerun the scanner and determine whether a fixed component is
available, the component remains deployed, severity or exploitability changed,
controls remain effective, and the remediation milestone is still valid.

A renewal must update the expiration, `last_reviewed_date`, and
`review_evidence`, and revise the rationale or controls when circumstances
change. Never extend an expiration merely to keep CI passing.

## Closure

1. Remove the native suppression.
2. Change the registry record to `closed`.
3. Retain the finding and remediation reference.
4. Rerun the validator and applicable scanner.
5. Confirm the scanner succeeds without the suppression.

## Phase-Deferred Findings

| Target phase | Planned control |
| --- | --- |
| Phase 12 — Security Monitoring | CloudTrail and audit-event alerting. |
| Phase 14 — Kubernetes Security | NetworkPolicies and additional cluster hardening. |
| Phase 18 — Disaster Recovery | Cross-Region audit archive replication and recovery validation. |

Deferral never makes an exception permanent. Each record still expires and must
be reviewed even when its target phase has not begun.

## Evidence

Retain the original finding, remediation analysis, exception record, approval or
owner review, policy output, scanner output, and closure or renewal evidence.
The required governance check is implemented and retains workflow artifacts for
90 days. Independent production approval remains a deployment requirement.
