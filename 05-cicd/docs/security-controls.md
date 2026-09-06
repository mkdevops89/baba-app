# Phase 05 - Security Controls

## Purpose

This document records the security controls implemented in the Baba App Phase 05 CI/CD pipeline.

The controls are designed to detect security issues early, enforce pipeline policy, preserve artifact traceability, reduce software supply-chain risk, and limit privileged access during artifact publication.

---

## Security Control Summary

Phase 05 implements security controls across:

- Source control
- Application code
- Third-party dependencies
- Terraform
- Kubernetes manifests
- Container images
- Software Bills of Materials
- AWS authentication
- Amazon ECR publication
- Artifact signing
- Build provenance
- Risk acceptance and exception handling

The overall model is:

```text
Detect
  |
  v
Evaluate
  |
  v
Remediate / Accept / Defer
  |
  v
Revalidate
  |
  v
Publish Approved Artifact
```

---

## Secrets Scanning

### Tool

```text
Gitleaks
```

### Control Objective

Detect accidental exposure of sensitive values before changes reach the protected default branch.

### Workflow Scope

The Gitleaks workflow scans:

```text
feature/**
security/**
pull requests targeting main
```

The workflow checks out full repository history using:

```yaml
fetch-depth: 0
```

This allows Gitleaks to inspect committed history rather than only the most recent snapshot.

### Workflow Permissions

The workflow uses:

```yaml
permissions:
  contents: read
```

The GitHub token is provided only to authenticate required GitHub API requests.

PR comments are disabled because the workflow is used as a blocking security control rather than a notification mechanism.

### Validation

A controlled synthetic secret test was used to prove enforcement.

```text
Clean repository
      |
      v
PASS
      |
      v
Synthetic secret-like value introduced
      |
      v
FAIL
      |
      v
Finding removed
      |
      v
PASS
```

No real credential was introduced.

### Security Outcome

The workflow demonstrated that secret scanning can actively block a change instead of only reporting findings.

---

## Static Application Security Testing

### Tool

```text
GitHub CodeQL
```

### Languages

- Java / Kotlin
- JavaScript / TypeScript

### Control Objective

Identify insecure coding patterns before application artifacts are published.

### Implementation

The CodeQL workflow:

- checks out source code
- initializes CodeQL by language
- performs a Java build for compiled-code analysis
- analyzes Java/Kotlin
- analyzes JavaScript/TypeScript
- publishes results into GitHub code scanning

### Workflow Permissions

CodeQL uses only the permissions required for source access and security-result publication.

### Security Outcome

SAST is integrated directly into the CI process instead of being performed as a separate manual activity.

---

## Software Composition Analysis

### Tool

```text
Trivy
```

### Targets

Backend:

```text
Maven dependencies
```

Frontend:

```text
npm dependencies
```

### Control Objective

Identify known vulnerabilities in third-party application dependencies.

### Severity Policy

```text
HIGH     -> Fail
CRITICAL -> Fail
```

The workflows retain:

```yaml
ignore-unfixed: false
```

This prevents the pipeline from automatically ignoring vulnerabilities merely because a fixed version is not yet available.

### Security Outcome

Known high-impact dependency vulnerabilities can block the CI pipeline before container publication.

---

## Terraform Security Scanning

### Tools

```text
Checkov
Trivy
```

### Control Objective

Detect insecure Infrastructure-as-Code configuration before changes are merged.

### Scan Scope

```text
03-terraform/
```

The CI workflow provides Terraform variable context using the tracked example configuration rather than exposing the real administrative CIDR stored in the ignored `terraform.tfvars` file.

### Blocking Behavior

Checkov uses:

```yaml
soft_fail: false
```

Trivy uses:

```yaml
exit-code: "1"
```

New unreviewed findings remain blocking.

---

## Kubernetes Security Scanning

### Tools

```text
Checkov
Trivy
```

### Control Objective

Identify insecure Kubernetes workload configuration before deployment.

### Scan Scope

```text
04-eks/
```

### Reviewed Controls

The Kubernetes baseline includes review of:

- non-root execution
- privilege escalation restrictions
- read-only root filesystem
- seccomp
- dropped Linux capabilities
- resource requests
- resource limits
- health probes
- service account token usage
- immutable image references

### Deferred Control

Kubernetes NetworkPolicies are intentionally deferred to:

```text
Phase 14 - Kubernetes Security
```

This exception is documented rather than globally suppressing Kubernetes security scanning.

---

## Default VPC Security Group Hardening

### Control Objective

Prevent workloads from inheriting permissive default VPC security-group behavior.

### Implementation

Terraform explicitly manages the default VPC security group with:

```hcl
ingress = []
egress  = []
```

Purpose-built security controls must be used instead of relying on the default group.

### Security Outcome

The default security group is no longer an implicit network-access path.

---

## Unused Security Group Removal

An internal application security-group module was removed from the active development environment because it was not attached to a workload.

The removed configuration included an unrestricted HTTPS egress rule.

### Security Rationale

Keeping unused security infrastructure creates misleading architecture and unnecessary attack surface.

The module source can remain reusable, but it is not instantiated until a real workload requires it.

---

## ECR KMS Policy Hardening

### Control Objective

Ensure the customer-managed ECR KMS key has an explicit administrative policy.

### Implementation

Terraform now:

- retrieves the current AWS account ID dynamically
- constructs the root principal without hard-coding the account
- attaches an explicit key policy
- keeps automatic KMS key rotation enabled

### Security Outcome

The ECR encryption key has an explicit and reviewable administration policy.

---

## EKS API Endpoint Risk Treatment

The development EKS architecture retains public API access for administration.

This is an intentional development-environment decision.

Compensating controls include:

- private endpoint enabled
- public endpoint restricted to explicitly approved CIDRs
- production-style private-only access deferred to later hardening

The following scanner findings are documented as reviewed exceptions:

```text
CKV_AWS_39
AWS-0040
AWS-0041
```

---

## EKS Kubernetes API Data Encryption

EKS 1.36 uses AWS-managed default envelope encryption for Kubernetes API data.

Customer-managed KMS encryption is intentionally deferred to later production/compliance hardening.

Related reviewed findings include:

```text
CKV_AWS_58
AWS-0039
```

This is a deferred control, not an undocumented suppression.

---

## Scanner Limitation Handling

Some scanner findings can represent policy-version lag or architecture-specific behavior.

Example:

```text
CKV_AWS_339
```

The configured EKS Kubernetes version was reviewed against current AWS support rather than automatically changing infrastructure solely to satisfy the scanner.

### Security Principle

Scanner output informs engineering decisions but does not replace architectural review.

---

## Container Vulnerability Scanning

### Tool

```text
Trivy
```

### Targets

```text
baba-app-backend
baba-app-frontend
```

### Severity Policy

```text
HIGH     -> Fail
CRITICAL -> Fail
```

### Control Objective

Prevent known high-impact vulnerabilities in final runtime images from reaching Amazon ECR.

The scan targets the built production-oriented images rather than only source dependency files.

---

## Backend Container Remediation

The backend container scan identified vulnerabilities in both application and operating-system layers.

### Application Remediation

Embedded Tomcat was upgraded to:

```text
10.1.59
```

### Runtime Remediation

The backend runtime changed from:

```text
gcr.io/distroless/java17-debian12:nonroot
```

to:

```text
gcr.io/distroless/java17-debian13:nonroot
```

### Base Image Refresh

The publication and backend security workflows use:

```text
docker build --pull
```

This reduces reliance on stale locally cached base images.

### Result

The application JAR was revalidated after the Tomcat upgrade and reported no HIGH or CRITICAL application-layer vulnerabilities.

---

## Temporary Container CVE Exceptions

Four Debian runtime vulnerabilities had no fixed package version available at the time of implementation:

```text
CVE-2026-76642
CVE-2026-78408
CVE-2026-78409
CVE-2026-78410
```

The exceptions are defined in:

```text
05-cicd/trivy-container-ignore.yaml
```

Each exception is:

- CVE-specific
- package-specific
- documented
- time-bound
- configured to expire on `2026-10-06`

The affected package reference is limited to the reviewed Debian runtime dependency.

Global unfixed-vulnerability suppression remains disabled.

### Security Outcome

The pipeline can tolerate a reviewed upstream limitation without disabling protection against unrelated vulnerabilities.

---

## Software Bill of Materials

### Tool

```text
anchore/sbom-action
```

### Format

```text
CycloneDX JSON
```

### Control Objective

Maintain an auditable inventory of the components present in container artifacts.

### Generated SBOMs

SBOMs are generated for:

- backend image
- frontend image

Feature and pull-request workflows generate SBOM artifacts for validation.

The privileged `main` publication workflow also generates SBOMs from the exact images approved for publication.

### Security Outcome

The published artifact can be associated with a component inventory that describes the same image that passed security scanning.

---

## Build-Once Publication Security Model

The privileged publication workflow follows:

```text
Build exact image
      |
      v
Scan exact image
      |
      v
Generate SBOM from exact image
      |
      v
Push same image
      |
      v
Resolve registry digest
      |
      v
Generate provenance
      |
      v
Sign digest
      |
      v
Verify signature
      |
      v
Verify provenance
```

### Security Objective

Avoid a common CI/CD weakness where one artifact is scanned but a separately rebuilt artifact is ultimately published.

The image that passes Trivy and SBOM generation is the image pushed to Amazon ECR.

---

## GitHub Actions OIDC Authentication

### Control Objective

Eliminate long-lived AWS access keys from CI/CD.

### Authentication Model

```text
GitHub Actions
      |
      v
GitHub OIDC Token
      |
      v
AWS IAM OIDC Provider
      |
      v
AssumeRoleWithWebIdentity
      |
      v
Temporary AWS Credentials
```

No static:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

values are required for ECR publication.

---

## OIDC Trust Restriction

The AWS CI/CD role is restricted to the Baba App repository and `main` branch.

Trusted subject:

```text
repo:mkdevops89/baba-app:ref:refs/heads/main
```

OIDC audience:

```text
sts.amazonaws.com
```

### Security Outcome

Feature branches can perform CI validation but cannot assume the privileged AWS publishing role.

---

## Least-Privilege ECR IAM

The GitHub Actions IAM role is limited to the two Baba App repositories:

```text
baba-app-dev-backend
baba-app-dev-frontend
```

Repository-scoped permissions include:

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

Authentication uses:

```text
ecr:GetAuthorizationToken
```

with resource `"*"` because that API requires global resource scope.

### Security Outcome

The CI/CD role cannot publish to arbitrary ECR repositories in the AWS account.

---

## GitHub Workflow Permission Minimization

Most validation workflows use:

```yaml
permissions:
  contents: read
```

The privileged publication workflow adds only what it requires:

```yaml
permissions:
  contents: read
  id-token: write
  attestations: write
  packages: write
```

### Security Principle

GitHub token permissions are explicitly declared instead of relying on broad defaults.

---

## Immutable Image Tagging

Published images use the full Git commit SHA as the tag.

Example:

```text
baba-app-dev-backend:<full-git-sha>
baba-app-dev-frontend:<full-git-sha>
```

The ECR repositories use immutable image tags.

### Security Objective

Prevent a published tag from being overwritten with different image content.

---

## Registry Digest Resolution

After publication, the workflow queries ECR for each image digest.

Authoritative artifact identity:

```text
repository@sha256:<digest>
```

### Security Outcome

Signing, provenance, verification, and future deployment promotion can reference an immutable image identity rather than relying only on a human-readable tag.

---

## Keyless Image Signing

### Tool

```text
Cosign
```

### Signing Model

```text
Keyless signing using GitHub Actions OIDC
```

No static private signing key is stored in GitHub.

Images are signed by immutable ECR digest.

### Security Objective

Provide cryptographic evidence that a published artifact was signed by the expected CI/CD identity.

---

## Signature Verification

Cosign verification requires the exact expected workflow identity.

Expected certificate identity:

```text
https://github.com/mkdevops89/baba-app/.github/workflows/ecr-publish.yml@refs/heads/main
```

Expected issuer:

```text
https://token.actions.githubusercontent.com
```

### Security Outcome

The pipeline verifies that the signature was issued to the intended Baba App publication workflow rather than merely checking that some valid Sigstore signature exists.

---

## Build Provenance

### Tool

```text
GitHub Artifact Attestations
```

### Control Objective

Associate immutable container artifacts with evidence about the build that produced them.

Provenance is generated for both:

- backend image
- frontend image

Attestations use the exact ECR image digests as their subjects.

---

## Provenance Verification

The publication workflow verifies attestations using:

```text
gh attestation verify
```

Verification is restricted to:

```text
mkdevops89/baba-app
```

GitHub CLI is authenticated using the workflow token.

### Security Outcome

The pipeline does not merely create provenance; it validates that the published artifact has provenance associated with the expected repository identity.

---

## CI and Deployment Separation

Phase 05 ends at secure artifact publication.

It does not make GitHub Actions permanently responsible for Kubernetes deployment.

The intended architecture is:

```text
GitHub Actions
      |
      v
Build + Test + Scan
      |
      v
Publish + Sign + Attest
      |
      v
Amazon ECR
      |
      v
Immutable Digest
      |
      v
GitOps
      |
      v
Argo CD
      |
      v
Amazon EKS
```

Phase 06 will implement GitOps-based deployment reconciliation.

### Security Benefit

Separating CI from cluster reconciliation reduces the number of CI/CD credentials and permissions required for direct Kubernetes access.

---

## Security Exception Model

Security findings are classified using the following dispositions:

```text
Remediated
Accepted Risk
Deferred Control
Scanner Limitation
Temporary Exception
```

A finding is not suppressed merely because it causes a workflow failure.

The expected process is:

```text
Finding detected
      |
      v
Review exploitability and context
      |
      +----> Remediate
      |
      +----> Accept with documented rationale
      |
      +----> Defer to planned security phase
      |
      +----> Temporary time-bound exception
      |
      v
Revalidate
```

---

## Infrastructure Security Exception Register

The following findings have been reviewed:

| Scanner | Finding | Disposition | Rationale |
| --- | --- | --- | --- |
| Checkov | CKV_AWS_39 | Accepted - dev | EKS public API retained for development administration; access restricted to approved /32 CIDRs and private endpoint remains enabled. |
| Checkov | CKV_AWS_58 | Accepted / deferred | EKS 1.36 uses AWS-managed default envelope encryption; customer-managed KMS encryption is deferred to later hardening. |
| Checkov | CKV_AWS_339 | Scanner limitation | EKS 1.36 was reviewed against current AWS support rather than changed solely for scanner policy. |
| Checkov | CKV_AWS_109 | Accepted | Reviewed KMS key-policy account administration statement. |
| Checkov | CKV_AWS_111 | Accepted | Reviewed KMS key-policy account administration statement. |
| Checkov | CKV_AWS_356 | Accepted | KMS key policies use resource `*` to refer to the key controlled by the policy. |
| Checkov | CKV2_K8S_6 | Deferred | Kubernetes NetworkPolicies are scheduled for Phase 14. |
| Trivy | AWS-0039 | Accepted / deferred | Customer-managed KMS encryption for Kubernetes API data is deferred to later hardening. |
| Trivy | AWS-0040 / AWS-0041 | Accepted - dev | Public EKS API remains explicitly CIDR-restricted with private endpoint access enabled. |

---

## Known Gaps and Deferred Controls

### Backend Automated Testing

The Maven test stage is implemented, but the backend currently contains no automated test sources.

Meaningful backend test coverage remains technical debt.

### Frontend Automated Testing

The frontend currently validates:

- dependency installation
- linting
- production build

Dedicated frontend unit tests are not yet implemented.

### Kubernetes NetworkPolicies

Deferred to:

```text
Phase 14 - Kubernetes Security
```

### Policy-as-Code Admission Controls

Future controls may include:

```text
Kyverno
OPA Gatekeeper
```

### Workload Identity

EKS Pod Identity / IRSA hardening will be added in later Kubernetes/cloud security work.

### Advanced Software Supply-Chain Enforcement

Phase 16 will extend:

- SBOM policy enforcement
- signature policy
- provenance policy
- admission-time artifact verification
- artifact promotion controls
- immutable GitHub Action pinning where practical

### Production Approval Gates

Explicit environment or production-promotion approval controls are not yet implemented in Phase 05.

They should be introduced when the project adds higher-environment promotion and GitOps deployment controls.

---

## Phase 05 Security Outcome

Phase 05 establishes a CI/CD security foundation capable of demonstrating:

```text
Secrets detection
SAST
SCA
IaC security scanning
Kubernetes manifest scanning
Container vulnerability scanning
Risk-based finding disposition
Time-bound vulnerability exceptions
SBOM generation
OIDC-based AWS authentication
Least-privilege ECR permissions
Immutable image publication
Digest-based artifact identity
Keyless image signing
Signature verification
Build provenance
Provenance verification
CI / deployment separation
```

The phase demonstrates that CI/CD is a security enforcement layer within the software-development lifecycle, not only a mechanism for building and publishing software.