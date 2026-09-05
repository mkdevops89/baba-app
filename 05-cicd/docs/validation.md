# Phase 05 - CI/CD Validation

## Purpose

This document records validation evidence for the Baba App Phase 05 CI/CD implementation.

The goal is to verify both successful pipeline execution and intentional failure behavior for security controls.

---

## Backend CI Validation

The backend CI workflow was validated using GitHub Actions.

Validated stages:

- Repository checkout
- Java 17 setup
- Maven dependency caching
- Backend compilation
- Backend test command execution
- Spring Boot package creation

Result:

```text
Backend CI: PASS
```

The backend currently contains no automated test sources, so Maven reports:

```text
No tests to run.
```

The test stage itself is functioning correctly, but meaningful backend test coverage should be added later so the CI test gate validates actual application behavior.

---

## Frontend CI Validation

The frontend CI workflow was validated using GitHub Actions.

Validated stages:

- Repository checkout
- Node.js setup
- Dependency installation using `npm ci`
- ESLint validation
- Next.js production build

Initial lint validation identified:

```text
2 errors
3 warnings
```

The two blocking errors were remediated before the workflow was allowed to pass.

After remediation:

```text
0 errors
3 warnings
```

The remaining warnings are related to use of the HTML `<img>` element instead of Next.js image optimization.

These warnings are currently treated as non-blocking technical debt.

Result:

```text
Frontend CI: PASS
```

---

## Gitleaks Secret-Scanning Validation

The repository secrets-scanning workflow uses Gitleaks as a required CI security control.

The workflow scans:

```text
feature/**
security/**
pull requests targeting main
```

The GitHub Actions token permission is limited to:

```yaml
permissions:
  contents: read
```

No AWS credentials are requested by the secrets-scanning workflow.

---

## Gitleaks Baseline Validation

The repository was first scanned in its normal state.

Result:

```text
Gitleaks Secret Scan: PASS
```

This established the clean baseline before testing the enforcement behavior.

---

## Controlled Security-Gate Failure Test

A temporary branch was created specifically for security-control validation:

```text
security/gitleaks-gate-test
```

A temporary custom Gitleaks rule and synthetic sentinel value were introduced.

No real credential was used.

The controlled sentinel matched the temporary test rule and caused Gitleaks to report a finding.

Expected result:

```text
Gitleaks Secret Scan: FAIL
```

Observed result:

```text
Gitleaks Secret Scan: FAIL
Leaks detected
```

This demonstrated that the workflow is capable of blocking a change when secret-scanning policy is violated.

---

## Remediation Validation

After the intentional failure was captured:

- The synthetic sentinel was removed
- The temporary Gitleaks rule was removed
- The changes were committed
- The workflow was rerun

Result:

```text
Gitleaks Secret Scan: PASS
```

This completed the full enforcement validation cycle:

```text
Clean repository
      |
      v
PASS
      |
      v
Controlled secret-like value introduced
      |
      v
FAIL
      |
      v
Finding remediated
      |
      v
PASS
```

---

## Security-Gate Outcome

The Gitleaks validation demonstrated that the Phase 05 pipeline is not merely reporting security findings.

It can actively enforce policy and stop a workflow when a defined security condition is violated.

The validated process was:

```text
Detect
  |
  v
Fail
  |
  v
Review
  |
  v
Remediate
  |
  v
Revalidate
```

This pattern will be reused for additional Phase 05 security controls.

---

## Temporary Test Branch Cleanup

The temporary security validation branch was removed after testing:

```text
security/gitleaks-gate-test
```

The branch was deleted locally and from the remote repository.

Temporary validation artifacts were not retained in the Phase 05 implementation branch.

The permanent improvement retained from the test was support for secrets scanning on:

```text
security/**
```

branches.

---

## Current Phase 05 Validation Status

```text
Backend CI                  PASS
Frontend CI                 PASS
Gitleaks baseline           PASS
Gitleaks controlled failure PASS - failure successfully enforced
Gitleaks remediation        PASS
```

Additional validation will be added as Phase 05 introduces:

- SAST
- SCA
- Terraform security scanning
- Kubernetes manifest scanning
- Container vulnerability scanning
- SBOM generation
- Artifact signing
- AWS OIDC authentication
- Amazon ECR publishing

## Infrastructure Security Exception Register

The CI/CD security gate uses targeted exceptions only after findings are
reviewed and classified. Global soft-fail behavior is not enabled.

| Scanner | Finding | Disposition | Rationale |
| --- | --- | --- | --- |
| Checkov | CKV_AWS_39 | Accepted - dev | EKS public API retained for development administration; access restricted to approved /32 CIDRs and private endpoint remains enabled. |
| Checkov | CKV_AWS_58 | Accepted / deferred | EKS 1.36 receives AWS-managed default envelope encryption; customer-managed KMS encryption is deferred to later production/compliance hardening. |
| Checkov | CKV_AWS_339 | Scanner limitation | EKS 1.36 is currently supported by AWS. |
| Checkov | CKV_AWS_109 | Accepted | Reviewed KMS key-policy account administration statement. |
| Checkov | CKV_AWS_111 | Accepted | Reviewed KMS key-policy account administration statement. |
| Checkov | CKV_AWS_356 | Accepted | KMS key policies use resource "*" to refer to the KMS key controlled by the policy. |
| Checkov | CKV2_K8S_6 | Deferred | Kubernetes NetworkPolicies are scheduled for Phase 14. |
| Trivy | AWS-0039 | Accepted / deferred | EKS 1.36 uses AWS-managed default envelope encryption; customer-managed KMS encryption is deferred to later production/compliance hardening. |
| Trivy | AWS-0040 / AWS-0041 | Accepted - dev | EKS public API is explicitly CIDR-restricted and paired with private endpoint access. |
