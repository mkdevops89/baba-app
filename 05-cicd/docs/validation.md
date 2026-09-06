# Phase 05 - CI/CD Validation

## Purpose

This document records validation evidence for the Baba App Phase 05 secure CI/CD and software supply-chain implementation.

The goal is to verify that the pipeline performs required build, security, artifact, and publication controls, and that security gates can both pass clean changes and block controlled findings.

Phase 05 validation is divided into:

- application CI validation
- secrets-scanning validation
- SAST validation
- dependency-scanning validation
- infrastructure security validation
- container security validation
- SBOM validation
- AWS OIDC and IAM validation
- ECR publication validation
- image signing and provenance validation
- risk exception tracking
- known gaps and deferred controls

---

## Validation Status Summary

| Control | Status | Notes |
| --- | --- | --- |
| Backend CI | PASS | Compile, test command, and package stages validated |
| Frontend CI | PASS | `npm ci`, lint, and production build validated |
| Gitleaks baseline | PASS | Clean repository scan passed |
| Gitleaks controlled failure | PASS | Synthetic secret-like value successfully blocked workflow |
| Gitleaks remediation | PASS | Workflow returned to green after removal |
| CodeQL Java/Kotlin | PASS | Static analysis completed successfully |
| CodeQL JavaScript/TypeScript | PASS | Static analysis completed successfully |
| Backend dependency scan | PASS | Trivy SCA passed |
| Frontend dependency scan | PASS | Trivy SCA passed |
| Terraform Checkov | PASS | Required checks passed with reviewed exceptions |
| Terraform Trivy | PASS | Required checks passed with reviewed exceptions |
| Kubernetes Checkov | PASS | Required checks passed with documented NetworkPolicy deferral |
| Kubernetes Trivy | PASS | Required checks passed with documented EKS exceptions |
| Backend container scan | PASS | Application vulnerabilities remediated; reviewed runtime exceptions retained |
| Frontend container scan | PASS | No blocking HIGH/CRITICAL findings |
| Backend SBOM | PASS | CycloneDX artifact generated |
| Frontend SBOM | PASS | CycloneDX artifact generated |
| Live AWS OIDC provider / IAM role | PASS | Terraform provisioned and live policy verified |
| ECR IAM least privilege | PASS | Live policy verified against exact Baba App repositories |
| Main-branch ECR publication | PENDING POST-MERGE VALIDATION | Workflow is intentionally restricted to `main` |
| Publication SBOMs | PENDING POST-MERGE VALIDATION | Implemented in main-only publish workflow |
| Cosign signing | PENDING POST-MERGE VALIDATION | Implemented but requires main publication run |
| Signature verification | PENDING POST-MERGE VALIDATION | Implemented but requires signed ECR artifacts |
| Build provenance attestation | PENDING POST-MERGE VALIDATION | Implemented in main-only publish workflow |
| Provenance verification | PENDING POST-MERGE VALIDATION | Implemented but requires successful attestation publication |

---

## Backend CI Validation

The backend CI workflow was validated using GitHub Actions.

Validated stages:

- repository checkout
- Java 17 setup
- Maven dependency caching
- Maven compilation
- Maven test command execution
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

- repository checkout
- Node.js 24 setup
- npm dependency caching
- deterministic dependency installation using `npm ci`
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

The workflow checks out full Git history using:

```yaml
fetch-depth: 0
```

The workflow uses minimal permissions:

```yaml
permissions:
  contents: read
```

`GITHUB_TOKEN` is provided only to authenticate required GitHub API access.

PR comments are disabled because this workflow functions as a blocking security gate rather than a notification mechanism.

No AWS credentials are requested by the secrets-scanning workflow.

---

## Gitleaks Baseline Validation

The repository was first scanned in its normal state.

Result:

```text
Gitleaks Secret Scan: PASS
```

This established the clean baseline before testing enforcement behavior.

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

## Gitleaks Remediation Validation

After the intentional failure was captured:

- the synthetic sentinel was removed
- the temporary Gitleaks rule was removed
- the changes were committed
- the workflow was rerun

Result:

```text
Gitleaks Secret Scan: PASS
```

The full enforcement cycle was:

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
Finding reviewed
      |
      v
Finding remediated
      |
      v
PASS
```

The temporary test branch was removed locally and remotely after validation.

---

## CodeQL SAST Validation

Static Application Security Testing is implemented with GitHub CodeQL.

Languages validated:

```text
java-kotlin
javascript-typescript
```

The Java job performs an explicit Maven build before analysis.

The JavaScript/TypeScript job uses direct CodeQL analysis.

Results:

```text
CodeQL - java-kotlin: PASS
CodeQL - javascript-typescript: PASS
```

The workflow was also updated from CodeQL action v3 to v4 after deprecation warnings were observed.

Final validation completed without the previous version warning.

---

## Software Composition Analysis Validation

Trivy is used for dependency vulnerability scanning.

Backend target:

```text
01-application/backend
```

Frontend target:

```text
01-application/frontend
```

Policy:

```text
HIGH     -> Fail
CRITICAL -> Fail
```

Configuration:

```yaml
ignore-unfixed: false
```

Results:

```text
Backend dependency scan: PASS
Frontend dependency scan: PASS
```

This validates that known high-impact dependency findings can block CI before artifact publication.

---

## Infrastructure Security Validation

Infrastructure security is validated with both Checkov and Trivy.

Targets:

```text
03-terraform/
04-eks/
```

Validated jobs:

```text
Terraform - Checkov
Terraform - Trivy
Kubernetes - Checkov
Kubernetes - Trivy
```

Final result:

```text
All four infrastructure security jobs: PASS
```

Global soft-fail behavior is not enabled.

Targeted exceptions are documented and remain narrowly scoped.

---

## Infrastructure Security Remediation Evidence

Security scanning produced actionable findings that resulted in real infrastructure changes.

### Default VPC Security Group

Finding:

The default VPC security group was unmanaged by Terraform.

Remediation:

Terraform now explicitly manages the default security group with:

```hcl
ingress = []
egress  = []
```

Outcome:

```text
Remediated and revalidated
```

---

## ECR KMS Policy Remediation

Finding:

The ECR customer-managed KMS key did not include an explicit policy acceptable to the scanner.

Remediation:

Terraform now:

- retrieves the current AWS account ID
- builds an explicit KMS administration policy
- assigns the account root principal
- retains key rotation

Outcome:

```text
Remediated and revalidated
```

---

## Unused Security Group Removal

Finding:

An internal application security group was instantiated but not attached to any workload.

The group also included an unrestricted HTTPS egress rule.

Remediation:

- removed the active `module "security"` composition from the development environment
- removed the related environment output
- retained the reusable module source for future use

Outcome:

```text
Remediated and revalidated
```

This prevents unused infrastructure from creating misleading architecture or unnecessary attack surface.

---

## Terraform CI Variable Context

Real administrative EKS API access uses a private value stored in the ignored:

```text
terraform.tfvars
```

CI security scanners require a representative variable value.

The tracked example now uses a synthetic documentation-only `/32` CIDR:

```hcl
cluster_public_access_cidrs = [
  "203.0.113.10/32"
]
```

This allows scanners to evaluate the intended restricted-access pattern without exposing the real administrative source address.

---

## Infrastructure Security Exception Register

The CI/CD security gate uses targeted exceptions only after findings are reviewed and classified.

Global soft-fail behavior is not enabled.

| Scanner | Finding | Disposition | Rationale |
| --- | --- | --- | --- |
| Checkov | CKV_AWS_39 | Accepted - dev | EKS public API retained for development administration; access restricted to approved /32 CIDRs and private endpoint remains enabled. |
| Checkov | CKV_AWS_58 | Accepted / deferred | EKS 1.36 uses AWS-managed default envelope encryption; customer-managed KMS encryption is deferred to later production/compliance hardening. |
| Checkov | CKV_AWS_339 | Scanner limitation | EKS 1.36 was reviewed against AWS support rather than changed solely for scanner policy. |
| Checkov | CKV_AWS_109 | Accepted | Reviewed KMS key-policy account administration statement. |
| Checkov | CKV_AWS_111 | Accepted | Reviewed KMS key-policy account administration statement. |
| Checkov | CKV_AWS_356 | Accepted | KMS key policies use resource `*` to refer to the KMS key controlled by the policy. |
| Checkov | CKV2_K8S_6 | Deferred | Kubernetes NetworkPolicies are scheduled for Phase 14. |
| Trivy | AWS-0039 | Accepted / deferred | Customer-managed KMS encryption for Kubernetes API data is deferred to later hardening. |
| Trivy | AWS-0040 / AWS-0041 | Accepted - dev | Public EKS API remains explicitly CIDR-restricted with private endpoint access enabled. |

---

## Container Vulnerability Validation

Trivy is used to scan final production-oriented backend and frontend images.

Policy:

```text
HIGH     -> Fail
CRITICAL -> Fail
```

Configuration:

```yaml
ignore-unfixed: false
```

---

## Backend Container Initial Failure

The first backend container scan identified vulnerabilities in:

- embedded Tomcat dependencies
- Debian runtime packages

The application JAR included vulnerabilities tied to Tomcat 10.1.55.

The runtime image was based on:

```text
gcr.io/distroless/java17-debian12:nonroot
```

This was treated as a real security finding rather than a scanner-only issue.

---

## Backend Container Remediation

Application remediation:

```text
Tomcat 10.1.55 -> 10.1.59
```

Runtime remediation:

```text
gcr.io/distroless/java17-debian12:nonroot
        |
        v
gcr.io/distroless/java17-debian13:nonroot
```

The backend build also uses:

```text
docker build --pull
```

to reduce reliance on stale cached base-image layers.

After remediation, application-layer validation reported:

```text
app/app.jar: 0 vulnerabilities
```

---

## Temporary Runtime CVE Exceptions

After remediation, the Debian 13 Distroless runtime still contained four HIGH vulnerabilities in `libuuid1` / util-linux for which no fixed package version was available at the time of validation:

```text
CVE-2026-76642
CVE-2026-78408
CVE-2026-78409
CVE-2026-78410
```

These findings are handled using:

```text
05-cicd/trivy-container-ignore.yaml
```

Each exception is:

- specific to the CVE
- specific to the affected package
- documented
- time-bound
- configured to expire on `2026-10-06`

Global unfixed-vulnerability suppression remains disabled.

Result:

```text
Backend container scan: PASS with reviewed temporary exceptions
```

---

## Frontend Container Validation

The frontend production-oriented container image was built and scanned with Trivy.

Result:

```text
Frontend container scan: PASS
```

No temporary frontend CVE exception file is used.

---

## SBOM Validation

SBOM generation is implemented using:

```text
anchore/sbom-action
```

Format:

```text
CycloneDX JSON
```

Validated artifacts:

```text
baba-app-backend-sbom
baba-app-frontend-sbom
```

Result:

```text
Backend SBOM generation: PASS
Frontend SBOM generation: PASS
```

Both artifacts were successfully produced by GitHub Actions.

---

## Exact-Artifact Publication Model

The main publication workflow was improved during PR review to prevent a build/scan/publish mismatch.

The final sequence is:

```text
Build exact backend image
Build exact frontend image
        |
        v
Scan exact backend image
Scan exact frontend image
        |
        v
Generate backend publication SBOM
Generate frontend publication SBOM
        |
        v
Push the same images to ECR
        |
        v
Resolve registry digests
        |
        v
Generate provenance
        |
        v
Cosign sign
        |
        v
Verify signatures
        |
        v
Verify provenance
```

This design avoids scanning one build and publishing a separately rebuilt artifact.

---

## AWS OIDC Validation

Terraform provisions the GitHub Actions OIDC provider and dedicated CI/CD IAM role.

OIDC provider:

```text
token.actions.githubusercontent.com
```

Audience:

```text
sts.amazonaws.com
```

Trusted repository identity:

```text
repo:mkdevops89/baba-app:ref:refs/heads/main
```

The trust policy intentionally excludes feature branches.

This means privileged AWS publication can only occur from `main`.

---

## Live ECR IAM Policy Validation

The live AWS IAM policy was queried directly after Terraform changes.

Verified authentication permission:

```text
ecr:GetAuthorizationToken
```

Verified repository-scoped permissions:

```text
ecr:BatchCheckLayerAvailability
ecr:BatchGetImage
ecr:CompleteLayerUpload
ecr:DescribeImages
ecr:GetDownloadUrlForLayer
ecr:InitiateLayerUpload
ecr:PutImage
ecr:UploadLayerPart
```

Verified repository scope:

```text
baba-app-dev-backend
baba-app-dev-frontend
```

Result:

```text
Live least-privilege ECR IAM policy: PASS
```

The role does not receive general ECR repository access.

---

## Main-Branch ECR Publication Validation

Status:

```text
PENDING POST-MERGE VALIDATION
```

Reason:

The ECR publication workflow is intentionally restricted to:

```text
main
```

The OIDC trust policy is also intentionally restricted to:

```text
refs/heads/main
```

The feature branch was not granted temporary AWS publishing permissions solely for testing.

This preserves the intended security boundary.

After merge, the main-branch workflow must validate:

- GitHub OIDC token issuance
- AWS `AssumeRoleWithWebIdentity`
- temporary AWS credentials
- ECR login
- backend image build
- frontend image build
- exact-image Trivy scans
- publication SBOM generation
- immutable SHA-tag push
- registry digest resolution
- provenance publication
- Cosign signing
- signature verification
- provenance verification

Phase 05 should not be described as fully publication-validated until this run succeeds.

---

## Publication SBOM Validation

Status:

```text
PENDING POST-MERGE VALIDATION
```

The main publication workflow now generates CycloneDX SBOMs from the exact local images that passed Trivy and are then pushed to ECR.

Expected artifacts:

```text
baba-app-backend-publication-sbom
baba-app-frontend-publication-sbom
```

This will be validated during the first successful main-branch publication run.

---

## Cosign Signing Validation

Status:

```text
PENDING POST-MERGE VALIDATION
```

The workflow is implemented to sign immutable ECR image digests using keyless Cosign signing.

No private signing key is stored in GitHub.

The expected signing identity is the GitHub Actions OIDC identity associated with the publication workflow.

---

## Signature Verification Validation

Status:

```text
PENDING POST-MERGE VALIDATION
```

Verification requires the exact certificate identity:

```text
https://github.com/mkdevops89/baba-app/.github/workflows/ecr-publish.yml@refs/heads/main
```

Expected OIDC issuer:

```text
https://token.actions.githubusercontent.com
```

The first main-branch ECR publication run will determine whether the signature and verification flow works end to end against Amazon ECR.

---

## Build Provenance Validation

Status:

```text
PENDING POST-MERGE VALIDATION
```

The workflow uses:

```text
actions/attest@v4
```

for both backend and frontend image digests.

Attestations are configured to be pushed to the registry.

The publication workflow later verifies provenance using:

```text
gh attestation verify
```

GitHub CLI authentication uses:

```yaml
GH_TOKEN: ${{ github.token }}
```

This flow must be validated against real published ECR digests after merge.

---

## GitHub Actions Workflow Review

Phase 05 currently includes:

```text
.github/workflows/
├── backend-ci.yml
├── codeql.yml
├── container-security.yml
├── dependency-security.yml
├── ecr-publish.yml
├── frontend-ci.yml
├── infrastructure-security.yml
├── sbom.yml
└── secrets-scan.yml
```

Validation and security workflows are intentionally separated from privileged artifact publication.

Most workflows use:

```yaml
permissions:
  contents: read
```

The publication workflow grants only the additional capabilities required for OIDC and attestations.

---

## Security-Gate Outcome

Phase 05 demonstrates that CI/CD security controls are capable of enforcement rather than only reporting.

The validated model is:

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
Remediate or formally classify
  |
  v
Revalidate
```

This pattern was demonstrated directly with Gitleaks and reused during infrastructure and container vulnerability remediation.

---

## Risk Treatment Model

Security findings are handled using the following dispositions:

```text
Remediated
Accepted Risk
Deferred Control
Scanner Limitation
Temporary Exception
```

The implementation does not use a global policy of suppressing findings to obtain green workflows.

New unreviewed findings remain subject to pipeline enforcement.

---

## Known Gaps

### Backend Automated Tests

Status:

```text
OPEN TECHNICAL DEBT
```

The backend Maven test stage executes successfully, but no backend test sources currently exist.

Meaningful automated backend tests should be added in a later application-quality improvement.

---

## Frontend Automated Tests

Status:

```text
OPEN TECHNICAL DEBT
```

The frontend currently validates:

- dependency installation
- ESLint
- production build

Dedicated frontend unit tests are not yet implemented.

---

## Approval / Promotion Controls

Status:

```text
DEFERRED
```

Explicit GitHub Environment approvals, required deployment reviewers, or production-style manual promotion controls are not implemented in Phase 05.

This phase establishes artifact publication and GitOps handoff.

Approval controls should be introduced when higher-environment promotion and GitOps deployment workflows require them.

Phase 05 documentation should not claim that explicit promotion approval gates are already implemented.

---

## Kubernetes NetworkPolicies

Status:

```text
DEFERRED TO PHASE 14
```

NetworkPolicies are intentionally deferred to the Kubernetes Security phase.

The Checkov exception is documented as:

```text
CKV2_K8S_6
```

---

## Advanced Supply-Chain Controls

Status:

```text
DEFERRED TO PHASE 16
```

Phase 16 will extend:

- SBOM policy enforcement
- signature policy enforcement
- provenance policy enforcement
- artifact admission verification
- promotion controls
- stronger third-party GitHub Action pinning where practical

Phase 05 provides the initial foundation.

---

## Post-Merge Validation Checklist

After the Phase 05 pull request is merged into `main`, validate the main-only publication workflow.

Required evidence:

```text
[ ] GitHub OIDC authentication succeeds
[ ] AWS temporary credentials are issued
[ ] ECR authentication succeeds
[ ] Backend image builds successfully
[ ] Frontend image builds successfully
[ ] Exact backend image passes Trivy
[ ] Exact frontend image passes Trivy
[ ] Backend publication SBOM is generated
[ ] Frontend publication SBOM is generated
[ ] Both images push to ECR
[ ] Full Git SHA tags exist
[ ] Backend digest resolves
[ ] Frontend digest resolves
[ ] Backend provenance attestation succeeds
[ ] Frontend provenance attestation succeeds
[ ] Backend Cosign signature succeeds
[ ] Frontend Cosign signature succeeds
[ ] Backend signature verification succeeds
[ ] Frontend signature verification succeeds
[ ] Backend provenance verification succeeds
[ ] Frontend provenance verification succeeds
```

Any failure in this list must be remediated and rerun before Phase 05 publication validation is considered complete.

---

## Current Phase 05 Validation State

The current state before merge is:

```text
Application CI                      PASS
Secrets scanning                    PASS
Controlled security-gate test       PASS
SAST                                PASS
SCA                                 PASS
Terraform security scanning         PASS
Kubernetes security scanning        PASS
Container security scanning         PASS
PR / feature SBOM generation        PASS
AWS OIDC infrastructure             PASS
Live ECR IAM policy                 PASS
Exact-image publication design      IMPLEMENTED
Main ECR publication                PENDING POST-MERGE
Publication SBOMs                   PENDING POST-MERGE
Cosign signing                      PENDING POST-MERGE
Signature verification              PENDING POST-MERGE
Build provenance                    PENDING POST-MERGE
Provenance verification             PENDING POST-MERGE
```

This distinction is intentional.

Phase 05 implementation is ready for merge, but the privileged main-only artifact publication chain must still be validated after merge before the phase is considered fully validated end to end.

## Post-Merge Publication Validation

The main-only ECR publication workflow was successfully validated after Phase 05 was merged.

Workflow:

```text
ECR Publish
```

Run ID:

```text
34058566383
```

Final result:

```text
SUCCESS
```

Validated end-to-end stages:

```text
GitHub OIDC authentication        PASS
AWS temporary credentials         PASS
Amazon ECR authentication         PASS
Backend image build               PASS
Frontend image build              PASS
Exact backend image scan          PASS
Exact frontend image scan         PASS
Backend publication SBOM          PASS
Frontend publication SBOM         PASS
Amazon ECR image publication      PASS
Backend digest resolution         PASS
Frontend digest resolution        PASS
Backend provenance attestation    PASS
Frontend provenance attestation   PASS
Cosign image signing              PASS
Signature verification            PASS
Provenance verification           PASS
```

The initial publication attempt failed during AWS role assumption with:

```text
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

The root cause was an OIDC subject mismatch.

AWS initially trusted the legacy repository subject:

```text
repo:mkdevops89/baba-app:ref:refs/heads/main
```

GitHub emitted the immutable repository subject:

```text
repo:mkdevops89@251259091/baba-app@1355057456:ref:refs/heads/main
```

The Terraform trust policy was updated to use the immutable GitHub owner and repository IDs.

After the trust policy update, the same publication workflow completed successfully end to end.

This completed Phase 05 publication validation.