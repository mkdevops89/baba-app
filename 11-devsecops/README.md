# Phase 11: DevSecOps Security Governance

Phase 11 turns Baba App's security scanners into a governed, fail-closed
DevSecOps program. It defines what blocks delivery, how vulnerabilities are
triaged, how temporary exceptions are approved and expired, who owns sensitive
paths, and what evidence is retained for review.

This phase does not claim that every finding is immediately fixable. It ensures
that fixable findings are remediated, unresolved risk is visible and
time-limited, and a scanner ignore cannot silently bypass governance.

## Outcomes

- Six security-gate categories are defined in machine-readable policy.
- Native scanner suppressions are reconciled with a central exception registry.
- Expired, undocumented, duplicated, or stale exceptions fail validation.
- Positive and fail-closed negative policy tests run on every pull request.
- `Validate Security Governance` is required by the protected `main` ruleset.
- Governance evidence is uploaded with 90-day retention, including failed runs.
- Dependabot covers GitHub Actions, npm, Maven, Docker, and Terraform.
- CODEOWNERS assigns accountability for every path and security-sensitive areas.
- Private vulnerability reporting, secret scanning, and push protection are
  enabled for the public portfolio repository.
- Pull requests and security remediation issues use structured templates.
- The backend was migrated to patched Spring Boot 4 dependencies and now has
  seven integration tests covering startup, routing, security, input validation,
  seed data, and CORS.

## Security Gates

| Gate | Scanner | Blocking behavior |
| --- | --- | --- |
| Secret detection | Gitleaks | Suspected committed secrets fail the workflow. |
| Static analysis | CodeQL | Reported application findings require review and remediation. |
| Dependency vulnerability | Trivy and Dependabot | HIGH and CRITICAL fixable findings block delivery. |
| Container vulnerability | Trivy | HIGH and CRITICAL findings block unless a current governed exception exists. |
| Terraform misconfiguration | Checkov and Trivy | Reviewed checks remain blocking except for registered suppressions. |
| Kubernetes misconfiguration | Checkov and Trivy | Rendered manifests are scanned; reviewed suppressions require governance records. |

## Repository Structure

| Path | Purpose |
| --- | --- |
| `policies/security-gates.json` | Gate definitions, remediation targets, exception requirements, and evidence policy. |
| `policies/security-exceptions.json` | System of record for accepted, planned, false-positive, expired, and closed findings. |
| `scripts/validate-security-policy.sh` | Validates policy structure, dates, uniqueness, and suppression reconciliation. |
| `scripts/test-security-policy.sh` | Runs the valid baseline and four fail-closed negative controls. |
| `docs/exception-process.md` | Exception request, review, renewal, and closure procedure. |
| `docs/architecture.md` | Governance data flow, trust boundaries, and evidence architecture. |
| `docs/security-controls.md` | Implemented controls, responsibilities, and known boundaries. |
| `docs/validation.md` | Commands and evidence used to validate Phase 11. |
| `.github/workflows/devsecops-governance.yml` | Always-running required policy check and evidence collection. |
| `.github/dependabot.yml` | Scheduled dependency update configuration. |
| `.github/CODEOWNERS` | Repository and security-sensitive path ownership. |
| `.github/SECURITY.md` | Private reporting guidance and remediation targets. |

## Remediation Targets

| Severity | Target |
| --- | ---: |
| Critical | 1 day |
| High | 7 days |
| Medium | 30 days |
| Low | 90 days |

The target begins after a finding is confirmed. When no safe fix exists, an
exception may document the affected scope, rationale, compensating controls,
owner, review evidence, and expiration. Exceptions are limited to 90 days and
must be reassessed before renewal.

## Run Locally

Validate the current policy and suppression inventory:

```bash
11-devsecops/scripts/validate-security-policy.sh
```

Run the positive control and all negative controls:

```bash
11-devsecops/scripts/test-security-policy.sh
```

Run the backend integration suite:

```bash
mvn -f 01-application/backend/pom.xml clean verify
```

Run the governed backend image scan:

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignorefile 05-cicd/trivy-container-ignore.yaml \
  --exit-code 1 \
  baba-app-backend:phase11-final
```

## Pull-Request Flow

1. A developer or scanner identifies a finding.
2. The finding is validated for affected version, scope, reachability, and risk.
3. A fix is preferred and is tested through the applicable CI workflows.
4. If no safe fix exists, the native suppression and governance record are
   changed together.
5. Policy validation rejects missing, stale, expired, or orphaned records.
6. The protected branch requires the governance result before merge.
7. Run metadata and validation logs are retained as workflow evidence.

## Known Boundaries

- Baba App is a single-maintainer portfolio, so production separation of duties
  is documented but cannot be demonstrated by one account.
- GitHub's non-provider secret patterns and validity checks are unavailable for
  the current repository plan; provider scanning, push protection, and Gitleaks
  remain enabled.
- GitHub Actions are version-tag pinned. Commit-SHA pinning is deferred to Phase
  16 Supply Chain Security.
- Four Debian runtime CVEs currently have no vendor fix. They are covered by
  time-limited records that expire on November 7, 2026. Five earlier runtime
  records were closed on October 18 after current scans stopped reporting them.
- Authentication of state-changing application endpoints is addressed in Phase
  15 Application Security. Current integration tests document existing behavior.
- This implementation supports security and compliance objectives but does not
  by itself make an organization compliant with a framework or regulation.

## Related Documentation

- [Architecture](docs/architecture.md)
- [Security Controls](docs/security-controls.md)
- [Security Exception Process](docs/exception-process.md)
- [Validation Evidence](docs/validation.md)
