# Phase 11 Security Controls

## Control Objectives

Phase 11 implements preventive, detective, corrective, and governance controls
for changes entering the Baba App repository. The design prioritizes fail-closed
validation, least privilege, traceable risk decisions, and reproducible evidence.

## Implemented Controls

| Control | Implementation | Validation |
| --- | --- | --- |
| Required governance gate | Stable `Validate Security Governance` job with no path filters; required by the `main` ruleset. | Successful push and pull-request runs; ruleset API inspection. |
| Least-privilege workflow | Governance workflow has only `contents: read`. | Workflow review and permission grep. |
| Policy as code | JSON policy defines gates, severity SLAs, required fields, statuses, and validity limits. | JSON parsing and structural validation. |
| Exception reconciliation | Native suppressions and active `SEC-EXC` records must map in both directions. | Positive baseline plus missing-record and stale-record negative tests. |
| Expiration enforcement | Active exceptions past their date fail validation; validity is limited to 90 days. | Simulated future-date negative test. |
| Ownership enforcement | CODEOWNERS covers all paths and explicitly lists security-sensitive directories. | Ownership-file validation. |
| Dependency maintenance | Dependabot covers seven roots across five ecosystems. | Configuration parsing, file existence checks, and generated PRs. |
| Dependency visibility | GitHub dependency graph and SBOM endpoint enabled. | GitHub SBOM returned 419 packages and 845 relationships during Phase 11 validation. |
| Secret prevention | GitHub secret scanning, push protection, and blocking Gitleaks workflow. | Repository-setting inspection and zero open secret alerts. |
| Private reporting | GitHub private vulnerability reporting and repository security policy. | Repository API returned `enabled: true`. |
| Evidence retention | Metadata and three validation logs uploaded even when controls fail; retained 90 days. | Workflow syntax and configuration validation; PR run required after push. |
| Backend regression tests | Full Boot 4 context with real MVC, security chain, H2, repositories, seed data, validation, and CORS. | Seven tests, zero failures, errors, or skips. |
| Runtime vulnerability gate | Trivy blocks ungoverned HIGH and CRITICAL image findings. | Clean governed scan and raw-to-policy CVE reconciliation. |

## Branch Protection

The active `Protect main` ruleset provides:

- pull-request-only changes;
- required review-thread resolution;
- squash-only merge policy;
- branch deletion protection;
- non-fast-forward protection;
- no configured bypass actors; and
- strict `Validate Security Governance` status enforcement.

The portfolio has one maintainer, so an approving-review count of zero avoids a
false claim of independent peer approval. A production repository should
require another authorized reviewer and CODEOWNER approval.

## Exception Controls

An active exception requires a unique ID, scanner, finding ID, affected scope,
risk, rationale, compensating controls, owner, lifecycle status, creation date,
expiration date, and review reference. Reassessed runtime exceptions also record
the last review date and evidence from the fresh image scan.

Verified secrets are not eligible for exception. Fixable vulnerabilities are
remediated rather than suppressed. When no upstream fix exists, the exception
must be shorter than or equal to 90 days and must be reviewed again before it
expires.

## Backend Remediation Controls

The Phase 11 backend response removed fixable findings through supported version
updates instead of adding ignores:

- Spring Boot 3.5.16 to 4.0.8;
- Spring MVC 6.2.19 to Spring Framework 7.0.9;
- Tomcat to 11.0.25;
- Jackson to 3.1.7; and
- `spring-boot-starter-web` to the Boot 4 servlet-specific
  `spring-boot-starter-webmvc`.

Temporary Tomcat and Jackson BOM overrides are documented in the POM and should
be removed when the selected Spring Boot BOM manages equal or newer safe
versions.

## Known Limitations and Deferred Work

| Boundary | Treatment |
| --- | --- |
| Independent production approval | Required by policy but not representable in a single-maintainer portfolio. Must be enforced for commercial deployments. |
| Enhanced secret patterns and validity checks | Unavailable on the current GitHub plan. Provider scanning, push protection, and Gitleaks remain active. |
| Action commit-SHA pinning | Deferred to Phase 16 Supply Chain Security. Current actions use reviewed version tags. |
| Application authentication | State-changing demo endpoints remain public and are explicitly deferred to Phase 15 Application Security. |
| Debian no-fix CVEs | Four current findings are time-limited through November 7, 2026 and protected by Distroless, non-root execution, read-only filesystems, and repeat scanning. Five earlier records were closed after refreshed scans stopped reporting them. |
| JPA open-in-view | Warning remains enabled until entity serialization and transaction boundaries are tested in the application-security phase. |
| Long-term evidence archive | GitHub artifacts retain 90 days. Production evidence should be copied to an access-controlled immutable archive. |

## Framework Alignment

These controls support common practices in NIST secure development, NIST CSF,
CIS, SOC 2, and regulated cloud environments: change control, vulnerability
management, least privilege, audit evidence, ownership, and risk acceptance.
They are control-aligned, not a certification or compliance determination.
