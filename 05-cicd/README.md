# Phase 05 - Secure CI/CD Pipeline and Software Supply Chain

## Overview

Phase 05 establishes the Baba App secure CI/CD foundation using GitHub Actions.

The implementation integrates application build validation, security scanning, container vulnerability analysis, SBOM generation, AWS OIDC authentication, Amazon ECR publishing, keyless image signing, and build provenance.

The design intentionally separates validation from privileged artifact publication.

Feature and security branches perform build and security validation.

The `main` branch is the only branch permitted to assume the AWS CI/CD role and publish container images to Amazon ECR.

---

## Phase 05 Objectives

Phase 05 is designed to:

- Automate backend and frontend build validation
- Introduce security controls directly into CI/CD
- Detect secrets before changes reach `main`
- Perform Static Application Security Testing
- Perform Software Composition Analysis
- Scan Terraform and Kubernetes configuration
- Scan final container images for vulnerabilities
- Fail workflows when required security conditions are violated
- Generate Software Bills of Materials
- Eliminate long-lived AWS credentials from CI/CD
- Publish traceable and immutable images to Amazon ECR
- Sign published images using keyless signing
- Generate and verify build provenance
- Maintain separation between CI artifact publication and Kubernetes deployment
- Prepare the project for GitOps-based deployment in Phase 06

---

## CI/CD Platform

The primary CI/CD platform used in Phase 05 is:

```text
GitHub Actions
```

GitHub Actions was selected because the Baba App repository is hosted on GitHub and workflow code can be reviewed alongside the application and infrastructure code.

Later phases may reproduce the same secure-delivery principles using Jenkins and GitLab CI to demonstrate platform portability.

The goal is not to duplicate identical pipelines simply for tool coverage.

The secure-delivery pattern is:

```text
Build
  |
  v
Test
  |
  v
Scan
  |
  v
Gate
  |
  v
Package
  |
  v
SBOM
  |
  v
Publish
  |
  v
Attest
  |
  v
Sign
  |
  v
Verify
```

---

## Implemented GitHub Actions Workflows

Phase 05 includes the following workflows:

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

Each workflow has a focused responsibility rather than placing all CI/CD functions into one oversized pipeline.

---

## Backend CI

The backend CI workflow validates the Java and Spring Boot application.

Implemented stages include:

- Repository checkout
- Java 17 configuration
- Maven dependency caching
- Maven compilation
- Maven test command execution
- Spring Boot package creation

The workflow runs for backend changes on:

```text
feature/**
pull requests targeting main
```

The backend currently has no automated test sources, so Maven reports:

```text
No tests to run.
```

The test stage itself is operational, but meaningful backend test coverage remains future work.

---

## Frontend CI

The frontend CI workflow validates the Next.js application.

Implemented stages include:

- Repository checkout
- Node.js 24 configuration
- npm dependency caching
- Deterministic dependency installation using `npm ci`
- ESLint validation
- Production Next.js build

Initial linting identified blocking errors that were remediated before the workflow was allowed to pass.

Non-blocking image optimization warnings remain documented as technical debt.

---

## Secrets Scanning

Secrets scanning is implemented with:

```text
Gitleaks
```

The workflow scans:

```text
feature/**
security/**
pull requests targeting main
```

The repository history is retrieved using:

```yaml
fetch-depth: 0
```

The Gitleaks workflow uses an authenticated GitHub token for API access while retaining minimal workflow permissions.

PR comments are disabled because the workflow is intended to function as a blocking security gate rather than a notification mechanism.

No long-lived AWS credentials are required by the secrets-scanning workflow.

---

## Controlled Secret-Scanning Validation

The Gitleaks gate was deliberately tested using a synthetic secret pattern.

The validation sequence was:

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
Finding reviewed
      |
      v
Finding removed
      |
      v
PASS
```

No real credential was introduced.

This demonstrated that the secrets-scanning control can actively stop the workflow rather than merely report findings.

---

## Static Application Security Testing

Static Application Security Testing is implemented using:

```text
GitHub CodeQL
```

Languages analyzed:

- Java / Kotlin
- JavaScript / TypeScript

The workflow runs CodeQL independently for the backend and frontend application stacks.

CodeQL publishes security analysis into GitHub code scanning and provides source-level security visibility before application artifacts are published.

---

## Software Composition Analysis

Software Composition Analysis is implemented using:

```text
Trivy
```

Dependency sources scanned include:

```text
Backend
→ Maven dependencies

Frontend
→ npm dependencies
```

The configured policy is:

```text
HIGH     → Fail
CRITICAL → Fail
```

This allows third-party dependency vulnerabilities to block the CI pipeline before container publication.

---

## Infrastructure Security Scanning

Infrastructure security scanning is performed using:

```text
Checkov
Trivy
```

Targets include:

```text
03-terraform/
04-eks/
```

The workflow includes:

- Terraform Checkov scanning
- Terraform Trivy misconfiguration scanning
- Kubernetes Checkov scanning
- Kubernetes Trivy misconfiguration scanning

The scans remain blocking.

Global soft-fail behavior is not enabled.

---

## Infrastructure Security Remediation

Security scanning identified several real infrastructure findings.

Remediation performed during Phase 05 included:

- Explicitly restricting the default VPC security group
- Adding an explicit ECR KMS key policy
- Removing an unused and unattached internal application security group
- Removing the unrestricted HTTPS egress rule associated with that unused security group
- Providing accurate Terraform variable context to CI scanners

The process followed:

```text
Detect
  |
  v
Review
  |
  v
Remediate or classify
  |
  v
Revalidate
```

Findings were not blindly suppressed simply to produce green workflows.

---

## Reviewed Infrastructure Exceptions

Some findings were retained as reviewed exceptions because they represented intentional development architecture, future controls, or scanner limitations.

Examples include:

- Restricted public EKS API access for development administration
- Customer-managed EKS Secrets encryption deferred to later hardening
- Kubernetes NetworkPolicies deferred to Phase 14
- Scanner-policy lag for the configured EKS Kubernetes version
- Reviewed KMS policy behavior

These exceptions are documented in:

```text
05-cicd/docs/validation.md
```

---

## Container Image Security

Container vulnerability scanning is implemented using:

```text
Trivy
```

Both production-oriented container images are scanned:

```text
baba-app-backend
baba-app-frontend
```

The policy is:

```text
HIGH     → Fail
CRITICAL → Fail
```

The final runtime images are scanned rather than only scanning application source dependencies.

---

## Backend Container Vulnerability Remediation

The backend container scan initially failed due to vulnerabilities in both the application and runtime layers.

The embedded Tomcat version was updated to:

```text
10.1.59
```

The backend runtime was also migrated from:

```text
gcr.io/distroless/java17-debian12:nonroot
```

to:

```text
gcr.io/distroless/java17-debian13:nonroot
```

CI also performs:

```text
docker build --pull
```

to reduce the likelihood of repeatedly scanning a stale base-image layer.

After remediation, the application JAR reported:

```text
0 HIGH/CRITICAL vulnerabilities
```

---

## Temporary Runtime CVE Exceptions

The Debian 13 runtime currently contains four reviewed HIGH vulnerabilities for which no fixed package version was available at the time of implementation:

```text
CVE-2026-76642
CVE-2026-78408
CVE-2026-78409
CVE-2026-78410
```

These are not globally ignored.

They are defined in:

```text
05-cicd/trivy-container-ignore.yaml
```

The exceptions are:

- CVE-specific
- package-specific
- documented
- time-bound
- configured to expire on `2026-10-06`

The pipeline retains:

```yaml
ignore-unfixed: false
```

Therefore, new unfixed HIGH or CRITICAL vulnerabilities are not automatically suppressed.

---

## Software Bill of Materials

Software Bills of Materials are generated using:

```text
Anchore Syft
```

through:

```text
anchore/sbom-action
```

Format:

```text
CycloneDX JSON
```

SBOMs are generated for:

- backend image
- frontend image

Feature and pull-request workflows generate SBOM artifacts for security validation.

The privileged `main` publication workflow also generates SBOMs from the exact container images that are approved for publication.

This preserves alignment between the component inventory and the artifact that is actually shipped.

---

## GitHub Actions Artifact Evidence

Phase 05 generates several forms of security evidence.

Examples include:

- Backend CycloneDX SBOM
- Frontend CycloneDX SBOM
- Publication SBOMs
- Security scanner reports
- Code scanning output
- Build provenance attestations
- Container signatures

These artifacts provide evidence that security controls executed and that published software can be traced back to its source and workflow.

---

## AWS Authentication

GitHub Actions authenticates to AWS using OpenID Connect.

No long-lived AWS access keys are stored in GitHub.

The authentication model is:

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
      |
      v
Amazon ECR
```

---

## AWS OIDC Trust Restriction

The dedicated CI/CD IAM role trusts only the Baba App repository on the `main` branch.

Trusted subject:

```text
repo:mkdevops89/baba-app:ref:refs/heads/main
```

The OIDC audience is restricted to:

```text
sts.amazonaws.com
```

Feature branches cannot use the CI/CD role to publish images.

This creates an intentional boundary between:

```text
Feature branches
→ build and security validation

main
→ privileged artifact publication
```

---

## Least-Privilege ECR IAM

The GitHub Actions role is scoped to the Baba App ECR repositories.

Repositories:

```text
baba-app-dev-backend
baba-app-dev-frontend
```

The role includes only the ECR capabilities required for authentication, image publication, digest resolution, and artifact retrieval.

Repository-scoped actions include:

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

`ecr:GetAuthorizationToken` uses resource `"*"` because ECR authentication requires that resource scope.

---

## Main-Branch Publication Workflow

Container publication occurs only from:

```text
main
```

The workflow uses immutable Git commit SHA tags.

Example artifact model:

```text
baba-app-dev-backend:<full-git-sha>
baba-app-dev-frontend:<full-git-sha>
```

The workflow does not rely on:

```text
latest
```

as the authoritative deployment identity.

---

## Build-Once Publication Model

The privileged publication workflow follows a build-once model.

The sequence is:

```text
Source Commit
      |
      v
Build Backend Image
      |
      v
Build Frontend Image
      |
      v
Scan Exact Backend Image
      |
      v
Scan Exact Frontend Image
      |
      v
Generate Backend SBOM
      |
      v
Generate Frontend SBOM
      |
      v
Push Same Images to ECR
      |
      v
Resolve Immutable SHA256 Digests
      |
      v
Generate Build Provenance
      |
      v
Cosign Sign Digests
      |
      v
Verify Signatures
      |
      v
Verify Provenance
```

This reduces the risk of scanning one artifact and publishing a different artifact.

---

## Immutable Artifact Identity

Container tags provide traceability, but the authoritative artifact identity is the registry digest:

```text
repository@sha256:<digest>
```

After each image is pushed, the workflow queries Amazon ECR and records the assigned digest.

Subsequent signing, provenance, and verification operations use the immutable digest rather than the mutable concept of a tag.

---

## Keyless Container Signing

Container signing is implemented using:

```text
Cosign
```

The signing model is:

```text
Keyless signing using GitHub Actions OIDC
```

No private Cosign signing key is stored in GitHub.

The immutable backend and frontend image digests are signed after publication.

---

## Signature Verification

Cosign verification checks that the image signature was issued to the exact expected workflow identity.

Expected certificate identity:

```text
https://github.com/mkdevops89/baba-app/.github/workflows/ecr-publish.yml@refs/heads/main
```

Expected OIDC issuer:

```text
https://token.actions.githubusercontent.com
```

This is more restrictive than accepting any generic GitHub Actions identity.

---

## Build Provenance

Build provenance is generated using:

```text
GitHub Artifact Attestations
```

Attestations are created for:

- backend image digest
- frontend image digest

The attestation links the artifact to build identity information such as:

- repository
- commit
- workflow
- GitHub Actions identity

The attestations are pushed alongside the container artifact.

---

## Provenance Verification

The publication workflow verifies build provenance using:

```text
gh attestation verify
```

Verification is restricted to:

```text
mkdevops89/baba-app
```

The workflow authenticates GitHub CLI using the workflow GitHub token.

This provides an independent verification step rather than merely generating provenance and assuming it is valid.

---

## Security Gate Philosophy

Phase 05 does not treat security scanners as tools that must always report zero findings.

The security model distinguishes:

```text
Detection
Enforcement
Risk disposition
```

A finding may be:

```text
Remediated
Accepted Risk
Deferred Control
Scanner Limitation
Temporary Exception
```

The expected process is:

```text
Scanner detects finding
        |
        v
Engineering review
        |
        +------> Remediate
        |
        +------> Accept with justification
        |
        +------> Defer to planned phase
        |
        +------> Temporary exception
        |
        v
Revalidate
```

This supports risk-based engineering while keeping new, unreviewed findings blocking.

---

## Workflow Permissions

GitHub Actions workflows explicitly define token permissions.

Most validation workflows use:

```yaml
permissions:
  contents: read
```

Privileged publication adds only the capabilities it requires:

```yaml
permissions:
  contents: read
  id-token: write
  attestations: write
  packages: write
```

This follows least-privilege workflow design.

---

## CI and Deployment Separation

Phase 05 does not perform direct Kubernetes deployment.

The publication pipeline ends at Amazon ECR.

The architecture is intentionally:

```text
CI Pipeline
     |
     v
Build + Test + Scan
     |
     v
SBOM + Publish + Sign + Attest
     |
     v
Amazon ECR
     |
     v
Immutable Image Digest
     |
     v
GitOps Handoff
```

Phase 06 will introduce:

```text
Argo CD
```

for Kubernetes deployment reconciliation.

The CI pipeline does not permanently use:

```text
kubectl apply
```

as the production-style deployment mechanism.

---

## Cost Strategy

Most Phase 05 development does not require the EKS cluster to remain online.

The EKS cluster is intentionally destroyed while CI/CD work is performed.

This avoids continuously paying for:

- EKS control plane
- EKS worker nodes

Phase 03 foundation resources remain active and may still generate AWS charges.

The NAT Gateway remains one of the primary ongoing costs.

---

## Known Gaps and Deferred Controls

The following items are intentionally deferred or remain incomplete:

### Application Testing

Backend:

```text
Maven test stage exists
No backend test sources currently exist
```

Frontend:

```text
Lint and production build are validated
Dedicated frontend unit tests are not currently implemented
```

### Kubernetes Network Security

Kubernetes NetworkPolicies are deferred to:

```text
Phase 14 - Kubernetes Security
```

### EKS Control Plane Hardening

Development currently retains restricted public API access.

Production-style private-only control-plane access remains future hardening.

### EKS Customer-Managed Secrets Encryption

Customer-managed KMS encryption for Kubernetes API data is deferred to later production/compliance hardening.

### Policy-as-Code

Admission enforcement using tools such as:

```text
Kyverno
OPA Gatekeeper
```

is deferred to later Kubernetes security work.

### Advanced Supply-Chain Enforcement

Phase 16 will extend:

- SBOM policy
- signature enforcement
- provenance policy
- admission-time artifact verification
- software supply-chain controls

---

## Phase 05 Documentation

The Phase 05 documentation structure is:

```text
05-cicd/
├── README.md
├── docs/
│   ├── pipeline-design.md
│   ├── security-controls.md
│   └── validation.md
├── trivy-ci.yaml
└── trivy-container-ignore.yaml
```

GitHub Actions workflows are located in:

```text
.github/workflows/
```

---

## Security Controls Reference

Detailed security-control documentation is maintained in:

```text
05-cicd/docs/security-controls.md
```

Validation evidence and exception tracking are maintained in:

```text
05-cicd/docs/validation.md
```

The overall architecture and design rationale are maintained in:

```text
05-cicd/docs/pipeline-design.md
```

---

## Phase 05 Outcome

Phase 05 establishes a secure CI/CD and software-supply-chain foundation capable of demonstrating:

```text
Automated backend build validation
Automated frontend build validation
Secrets scanning
SAST
SCA
Terraform security scanning
Kubernetes security scanning
Container vulnerability scanning
Enforceable security gates
Risk-based vulnerability remediation
SBOM generation
GitHub OIDC authentication
Least-privilege AWS IAM
Immutable ECR publication
Image digest traceability
Keyless container signing
Signature verification
Build provenance
Provenance verification
GitOps-ready artifact delivery
```

The completed phase demonstrates that CI/CD is not simply a mechanism for building and deploying software.

It is also a security enforcement point within the software-development lifecycle.