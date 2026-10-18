# Phase 11 Validation

## Validation Scope

This document records validation performed for Phase 11 DevSecOps governance
and the October 8-18, 2026 hardening work. Evidence covers policy enforcement,
repository controls, dependency remediation, regression tests, container
scanning, reporting safeguards, and documentation quality.

## Result Summary

| Area | Result |
| --- | --- |
| Governance registry | PASS: 20 active native suppressions map to 20 active records; 5 closed records are retained as audit history. |
| Positive policy control | PASS: current policy accepted. |
| Negative policy controls | PASS: four invalid conditions rejected. |
| Required merge control | PASS: governance check required by active `main` ruleset. |
| Backend build | PASS: Maven `clean verify`. |
| Backend tests | PASS: 7 run, 0 failures, 0 errors, 0 skipped. |
| Backend governed image scan | PASS: 0 ungoverned HIGH or CRITICAL findings. |
| Backend application JAR | PASS: 0 HIGH or CRITICAL findings. |
| Frontend lint | PASS: 0 errors; 3 reviewed image-optimization warnings. |
| Frontend production build | PASS: Next.js 16.4.0 build completed. |
| Frontend production npm audit | PASS: 0 vulnerabilities. |
| Frontend Trivy dependency scan | PASS: 0 HIGH or CRITICAL findings. |
| Frontend production image scan | PASS: 0 HIGH or CRITICAL findings. |
| Development-tooling review | REVIEWED: issue #70 remains open with a November 9, 2026 review date. |
| Remaining runtime findings | REVIEWED: 4 Debian findings, all without vendor fixes. |
| Runtime finding reconciliation | PASS: raw scan IDs exactly match governed native suppressions. |
| Private vulnerability reporting | PASS: enabled. |
| Secret alerts | PASS: no open repository secret-scanning alerts. |
| Dependabot alerts after remediation | PASS: zero open alerts. |
| Routine dependency updates | REVIEWED: 14 open Dependabot version-update PRs are tracked separately from vulnerability alerts. |
| YAML and JSON syntax | PASS. |
| Whitespace validation | PASS: `git diff --check`. |

## Policy Validation

The validator confirmed:

- policy files contain valid JSON;
- required gate and exception structures exist;
- identifiers and scanner/finding combinations are unique;
- severities and statuses are supported;
- dates are valid and chronologically ordered;
- validity periods do not exceed 90 days;
- no active exception is expired;
- every native suppression has a governance record; and
- every active governance record has a native suppression.

The negative test harness confirmed that validation rejects:

1. expired active exceptions;
2. exceptions without owners;
3. native suppressions without governance records; and
4. active governance records without native suppressions.

Run both controls:

```bash
11-devsecops/scripts/validate-security-policy.sh
11-devsecops/scripts/test-security-policy.sh
```

## Dependency and Application Remediation

Fresh scans identified fixable application-layer findings. The backend was
migrated and verified with these effective versions:

| Component | Validated version |
| --- | --- |
| Spring Boot | 4.0.8 |
| Spring Framework / Spring MVC | 7.0.9 |
| Apache Tomcat | 11.0.25 |
| Jackson BOM | 3.1.7 |
| Java | 17 |

An October 10 reassessment identified new fixable production findings in
Next.js, `sharp`, and `source-map-js`. They were remediated without suppressions:

| Component | Validated version |
| --- | --- |
| Next.js | 16.4.0 |
| eslint-config-next | 16.4.0 |
| sharp | 0.35.5 |
| source-map-js | 1.2.2 |

After remediation, the production-only npm audit returned zero vulnerabilities.
Lint completed with zero errors and three non-blocking image-optimization
warnings, and the optimized Next.js production build completed successfully.

The complete npm audit continues to report five HIGH entries inherited through
the ESLint-only `braces` dependency chain. The latest published `braces` release
remains 3.0.3, so no compatible upstream fix exists. The finding is absent from
production dependencies and the final runtime image. Issue #70 was reassessed
on October 10, 2026, remains open, and is scheduled for review on November 9,
2026. `npm audit fix --force` and an incompatible ESLint downgrade were rejected.

## Backend Integration Tests

`BackendSecurityIntegrationTest` loads the complete Boot 4 context and validates:

1. application, database, repositories, and security configuration start;
2. the public product catalog returns all 12 seeded products;
3. an anonymous cart without a session ID is rejected;
4. an invalid cart mutation is rejected before persistence;
5. an anonymous request outside permitted routes is forbidden;
6. the approved frontend CORS origin is allowed; and
7. an unapproved CORS origin is rejected.

Command:

```bash
mvn -f 01-application/backend/pom.xml clean verify
```

Result: 7 tests, 0 failures, 0 errors, and 0 skipped.

The Actuator health endpoint runs on the separate management port. A container
smoke test mapped that port and returned `status: UP` with liveness and
readiness groups.

## Container Vulnerability Evidence

A fresh no-cache build on October 18 produced the final backend image:

```text
sha256:8f5330fc5a48c1d5ac0ae5e12b2df32c8cd6192fab0927be43f97bc285207b3c
```

The governed Trivy scan returned zero ungoverned HIGH or CRITICAL findings for
both the Debian layer and `app/app.jar`. A second unsuppressed JSON scan returned
four findings, all in Debian packages, all with empty fixed-version fields:

- CVE-2026-76642;
- CVE-2026-78408;
- CVE-2026-78409;
- CVE-2026-78410.

The scan ID set exactly matched the four active runtime entries in
`05-cicd/trivy-container-ignore.yaml`. Corresponding `SEC-EXC-017` through
`SEC-EXC-020` records remain active and expire on November 7, 2026.

The refreshed October 18 base image and vulnerability databases no longer
reported `CVE-2026-66046`, `CVE-2026-76956`, `CVE-2026-76957`,
`CVE-2026-77214`, or `CVE-2026-93990`. Their native suppressions were removed,
and `SEC-EXC-021` through `SEC-EXC-025` were closed with image and scan
evidence. Closure records state only that the current scanner no longer reports
the findings; they do not claim a vendor patch when none was observed.

The final frontend image was rebuilt without cache on October 18 from the
Distroless Node.js 24 Debian 13 non-root runtime. Its local image ID was:

```text
sha256:2e100ece749f85cd147ffe90ccfd970a30883c75ec1e251e4e5c9bd2212c3ac4
```

The final image contained Next.js 16.4.0, `sharp` 0.35.5, and only production
standalone dependencies. Trivy reported zero HIGH or CRITICAL findings in the
Debian layer and every detected Node.js package. The Trivy filesystem scan also
reported zero HIGH or CRITICAL production dependency findings.

## Repository Security Validation

Repository API inspection confirmed:

- Dependabot vulnerability alerts and security updates are enabled;
- the dependency graph is available;
- secret scanning and push protection are enabled;
- private vulnerability reporting is enabled;
- the protected `main` ruleset has no bypass actors; and
- `Validate Security Governance` is a strict required status check.

The October 10 API review returned zero open Dependabot vulnerability alerts.
Fourteen open Dependabot pull requests remain for routine dependency version
updates. They are not active vulnerability alerts and will be reviewed and
tested independently rather than bulk-merged into this hardening change.

GitHub's non-provider secret patterns and validity checks remained disabled
after an attempted enablement because those features are unavailable for the
current repository plan. This is documented as a known boundary, not reported
as an implemented control.

## Evidence Retention

The governance workflow prepares run metadata plus Bash syntax, direct policy,
and negative-control logs. The upload step runs with `if: always()`, fails when
no evidence files exist, and requests 90-day retention.

The updated artifact behavior must be confirmed in the pull-request workflow
run after this branch is pushed. Until then, local syntax and configuration
validation prove the workflow definition, not remote artifact availability.

## Final Validation Commands

```bash
ruby -e '
  require "yaml"
  YAML.parse_file(".github/workflows/devsecops-governance.yml")
  YAML.parse_file(".github/ISSUE_TEMPLATE/security-remediation.yml")
'

jq empty \
  11-devsecops/policies/security-gates.json \
  11-devsecops/policies/security-exceptions.json

bash -n \
  11-devsecops/scripts/validate-security-policy.sh \
  11-devsecops/scripts/test-security-policy.sh

11-devsecops/scripts/test-security-policy.sh

mvn -f 01-application/backend/pom.xml clean verify

(
  cd 01-application/frontend
  npm run lint
  npm run build
  npm audit --omit=dev
)

trivy fs \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignorefile 05-cicd/trivy-container-ignore.yaml \
  --exit-code 1 \
  01-application/frontend

trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignorefile 05-cicd/trivy-container-ignore.yaml \
  --exit-code 1 \
  baba-app-backend:phase11-final-20261018

trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  baba-app-frontend:phase11-final-20261018

git diff --check
```

## Deferred Validation

- Independent production exception approval requires a multi-user production
  organization and is not claimed by this portfolio.
- Application authentication and authorization tests are scheduled for Phase
  15 Application Security.
- Commit-SHA pinning and provenance-policy enforcement are scheduled for Phase
  16 Supply Chain Security.
- Long-term immutable evidence retention beyond 90 days requires a production
  archive and is not implemented here.
