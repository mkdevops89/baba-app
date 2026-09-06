# Phase 05 - CI/CD Pipeline Design

## Purpose

Phase 05 establishes the Baba App continuous integration and continuous delivery foundation.

The goal is not only to automate application builds and container publishing, but to create a secure software delivery workflow that demonstrates modern DevSecOps practices.

The Phase 05 pipeline is designed to:

- Build and test the backend and frontend applications
- Scan application code and dependencies
- Scan Terraform and Kubernetes configuration
- Detect secrets before they reach the repository
- Build container images
- Scan container images for vulnerabilities
- Generate software bills of materials
- Sign container artifacts
- Publish approved images to Amazon ECR
- Use temporary AWS credentials through GitHub OpenID Connect
- Enforce security gates that can fail the pipeline
- Preserve artifact traceability
- Support immutable artifact promotion
- Hand deployment responsibility to the GitOps phase

This design creates a reusable secure-delivery model that can later be implemented across GitHub Actions, Jenkins, and GitLab CI.

---

## CI/CD Objectives

The primary objectives of Phase 05 are:

- Automate application build and test workflows
- Introduce security scanning as part of normal software delivery
- Shift security controls earlier into the development lifecycle
- Prevent vulnerable or misconfigured artifacts from progressing through the pipeline
- Eliminate long-lived AWS credentials from CI/CD
- Publish only validated container images
- Maintain traceability between source code, workflow run, image tag, image digest, SBOM, and signature
- Separate continuous integration from Kubernetes deployment
- Prepare the project for GitOps-based deployment in Phase 06
- Demonstrate secure CI/CD patterns across multiple platforms over the life of the project

---

## Primary CI/CD Platform

The primary CI/CD platform for Phase 05 is:

```text
GitHub Actions
```

GitHub Actions is used first because the Baba App source repository is hosted on GitHub and the workflows can be reviewed directly with the rest of the project code.

The initial implementation will establish the secure pipeline pattern.

Later implementations using Jenkins and GitLab CI will demonstrate that the same DevSecOps controls can be translated across different CI/CD platforms.

---

## Future CI/CD Platform Breadth

The project will later demonstrate similar secure-delivery principles using:

```text
GitHub Actions
Jenkins
GitLab CI
```

The intent is not to create three identical pipelines solely for tool coverage.

Each platform should demonstrate the same underlying engineering principles:

```text
Build
Test
Scan
Gate
Package
Sign
Publish
Promote
```

This provides platform breadth while maintaining a consistent security model.

---

## CI/CD Architecture

The high-level Phase 05 workflow is:

```text
Developer
   |
   v
Git Push / Pull Request
   |
   v
GitHub Actions
   |
   +--> Backend Build and Test
   |
   +--> Frontend Build and Test
   |
   +--> SAST
   |
   +--> SCA / Dependency Scanning
   |
   +--> Secrets Scanning
   |
   +--> Terraform Security Scanning
   |
   +--> Kubernetes Manifest Scanning
   |
   v
Security Gate
   |
   +--> FAIL --> Stop Pipeline
   |
   +--> PASS
          |
          v
   Container Build
          |
          v
   Container Vulnerability Scan
          |
          v
   SBOM Generation
          |
          v
   Artifact Signing
          |
          v
   Amazon ECR
          |
          v
   Immutable Image Digest
          |
          v
   GitOps Handoff
          |
          v
   Phase 06 - Argo CD
```

---

## Pipeline Stages

The secure delivery workflow is divided into the following logical stages.

### 1. Source

The pipeline starts when source code changes are introduced through:

- Pull requests
- Pushes to approved branches
- Manual workflow execution where appropriate

The pipeline should record:

- Commit SHA
- Branch
- Pull request number when applicable
- Workflow run ID
- Build timestamp
- Repository

These identifiers support artifact traceability.

---

### 2. Build

The backend and frontend are built independently.

Backend:

```text
Java
Maven
Spring Boot
```

Frontend:

```text
Node.js
Next.js
npm
```

Build failures should stop the pipeline.

A container image must never be published when the corresponding application build fails.

---

### 3. Test

Automated tests are executed before packaging.

Testing may include:

- Backend unit tests
- Frontend unit tests
- Build-time validation
- Static compilation checks
- Future integration tests

A failing required test should block artifact publication.

---

### 4. Security Scan

Security scanning occurs before an artifact is approved for publication.

The security pipeline includes:

- Static Application Security Testing
- Software Composition Analysis
- Secrets scanning
- Infrastructure-as-Code scanning
- Kubernetes manifest scanning
- Container vulnerability scanning

Security tools provide detection.

Pipeline policy determines whether a finding is severe enough to fail the build.

---

### 5. Security Gate

The security gate evaluates scan results.

The pipeline must be capable of failing when findings exceed an approved threshold.

Example policy:

```text
Critical finding -> Fail
High finding -> Fail unless explicitly approved
Medium finding -> Review or policy-dependent
Low finding -> Record and track
```

The exact threshold may vary depending on:

- Scanner type
- Environment
- Exploitability
- Application impact
- Compensating controls
- Accepted risk

The project should not blindly suppress findings only to make the pipeline pass.

---

### 6. Package

After build, testing, and pre-package security checks pass, the backend and frontend are packaged as container images.

Container builds should:

- Use the hardened Dockerfiles created in Phase 02
- Produce Linux AMD64-compatible images for the EKS worker architecture
- Avoid embedding secrets
- Use deterministic image metadata where possible
- Preserve source-to-image traceability

---

### 7. Container Security Scan

Container images are scanned before publication.

The scan should detect:

- Known operating-system vulnerabilities
- Application dependency vulnerabilities
- Vulnerable libraries
- Package-level CVEs
- High-risk image content

The preferred container scanner for the project is:

```text
Trivy
```

The pipeline should fail when vulnerabilities exceed the approved severity threshold.

---

### 8. SBOM Generation

A Software Bill of Materials is generated for approved container artifacts.

The SBOM should provide visibility into:

- Application packages
- Operating-system packages
- Libraries
- Dependency versions
- Component inventory

The project may use tools such as:

```text
Syft
Trivy
```

The generated SBOM should remain associated with the exact image digest it describes.

---

### 9. Artifact Signing

Approved container images should be cryptographically signed.

The preferred signing tool is:

```text
Cosign
```

The project should prefer keyless or identity-based signing where practical rather than maintaining static private signing keys inside CI/CD.

The signature should allow later verification that the artifact:

- Came from an approved CI/CD workflow
- Was not modified after publication
- Matches the expected image digest

Image verification will become increasingly important during the software supply-chain security phase.

---

### 10. Publish

Validated images are published to:

```text
Amazon Elastic Container Registry
```

Repositories:

```text
baba-app-dev-backend
baba-app-dev-frontend
```

The repositories already provide:

- Immutable image tags
- Scan-on-push
- Customer-managed KMS encryption
- Lifecycle policies

CI/CD should publish only artifacts that have passed the required gates.

---

### 11. Promote

Artifacts should be promoted using immutable references.

The preferred artifact identity is:

```text
repository@sha256:<digest>
```

Tags may be used for human readability and lifecycle management, but deployment should ultimately reference the immutable digest.

Promotion should not require rebuilding the artifact.

A validated image should move through environments as the same artifact.

---

## Backend Pipeline

The backend CI workflow should include:

```text
Checkout source
      |
      v
Configure Java
      |
      v
Restore Maven cache
      |
      v
Compile
      |
      v
Run tests
      |
      v
SAST
      |
      v
Dependency scan
      |
      v
Secrets scan
      |
      v
Security gate
      |
      v
Docker build
      |
      v
Container scan
      |
      v
SBOM
      |
      v
Sign
      |
      v
Publish to ECR
```

The backend pipeline should use the hardened backend Dockerfile from Phase 02.

---

## Frontend Pipeline

The frontend CI workflow should include:

```text
Checkout source
      |
      v
Configure Node.js
      |
      v
Restore npm cache
      |
      v
Install dependencies
      |
      v
Run tests
      |
      v
Build Next.js application
      |
      v
SAST
      |
      v
Dependency scan
      |
      v
Secrets scan
      |
      v
Security gate
      |
      v
Docker build
      |
      v
Container scan
      |
      v
SBOM
      |
      v
Sign
      |
      v
Publish to ECR
```

The frontend pipeline should use the hardened frontend Dockerfile from Phase 02.

---

## Infrastructure Security Pipeline

Infrastructure code should be scanned independently of application container builds.

The infrastructure security workflow will cover:

```text
03-terraform/
04-eks/
```

The pipeline should validate:

- Terraform formatting
- Terraform validation
- Terraform security configuration
- Kubernetes manifest security configuration

Initial tools:

```text
terraform fmt
terraform validate
Checkov
Trivy
```

Later controls may include:

```text
tfsec
OPA
Kyverno
Conftest
```

where they add meaningful value rather than duplicating checks unnecessarily.

---

## Static Application Security Testing

Static Application Security Testing examines source code for insecure coding patterns before the application is executed.

The exact SAST tool may differ between backend and frontend.

Potential tooling includes:

```text
CodeQL
Semgrep
SonarQube
SonarCloud
```

The project should prioritize tools that integrate cleanly into CI/CD and provide actionable findings.

SAST findings should be tracked by:

- Rule
- File
- Severity
- Remediation
- Final disposition

---

## Software Composition Analysis

Software Composition Analysis identifies known vulnerabilities in third-party dependencies.

Backend dependency sources include:

```text
Maven dependencies
```

Frontend dependency sources include:

```text
npm dependencies
```

Potential tools include:

```text
Trivy
Dependabot
OWASP Dependency-Check
npm audit
```

The project should avoid using multiple tools solely to increase tool count.

The preferred approach is to demonstrate clear detection, gating, remediation, and validation.

---

## Secrets Scanning

The pipeline should detect credentials and sensitive values before they are merged or published.

Potential tools include:

```text
Gitleaks
TruffleHog
GitHub secret scanning
```

The pipeline should protect against accidental commits of:

- AWS access keys
- API tokens
- passwords
- private keys
- connection strings
- application secrets

Production credentials should never be embedded in:

- source code
- Terraform files
- workflow YAML
- Dockerfiles
- Kubernetes manifests

---

## Infrastructure-as-Code Scanning

Terraform security scanning should continue using:

```text
Checkov
Trivy
```

Findings should continue to use the risk disposition model established during Phases 03 and 04:

```text
Remediated
Accepted Risk
Deferred Control
False Positive / Not Applicable
```

The CI pipeline should distinguish between:

- scanner detection
- enforcement policy
- risk disposition

A scanner finding does not automatically mean a control should be changed without architectural review.

---

## Kubernetes Manifest Scanning

Kubernetes manifests should be scanned before merge.

Important controls include:

- non-root containers
- privilege escalation disabled
- read-only root filesystem
- seccomp
- dropped Linux capabilities
- resource requests
- resource limits
- health probes
- service account token hardening
- immutable image references

The hardened Phase 04 manifests provide the initial secure baseline.

---

## Container Vulnerability Scanning

Container images should be scanned using Trivy after build and before publication.

The pipeline should evaluate vulnerabilities by severity.

Example policy:

```text
CRITICAL -> Fail
HIGH     -> Fail
MEDIUM   -> Record
LOW      -> Record
```

The final policy may evolve based on:

- fix availability
- exploitability
- environment
- application exposure
- business risk

The project should include at least one controlled example showing that a vulnerable build is rejected by the pipeline.

---

## Deliberate Security-Gate Validation

Phase 05 should prove that the security gate actually works.

A temporary test branch may intentionally introduce a controlled insecure condition.

Examples may include:

- An intentionally vulnerable dependency
- A deliberately insecure Terraform configuration
- A Kubernetes manifest missing a required security control
- A test secret pattern that does not expose a real credential

The expected pipeline behavior is:

```text
Introduce controlled finding
        |
        v
Security scanner detects finding
        |
        v
Pipeline fails
        |
        v
Finding is reviewed
        |
        v
Code is remediated
        |
        v
Pipeline is rerun
        |
        v
Pipeline passes
```

The insecure test condition must never introduce a real credential or intentionally deploy a vulnerable workload into a public environment.

This exercise provides evidence that the pipeline is enforcing security rather than merely reporting findings.

---

## Supply-Chain Security Controls

Phase 05 establishes the initial Baba App software supply-chain security foundation.

Implemented controls include:

- Immutable container tags
- Image digest tracking
- SBOM generation
- Exact-image vulnerability scanning before publication
- Keyless artifact signing with Cosign
- Signature verification
- Build provenance attestations
- Provenance verification
- Build traceability
- Controlled Amazon ECR publication
- Security gates
- GitHub OIDC authentication to AWS

The privileged publication workflow follows:

```text
Build exact image
      |
      v
Scan exact image
      |
      v
Generate SBOM
      |
      v
Push same image
      |
      v
Resolve immutable digest
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
---

## GitHub Actions AWS Authentication

GitHub Actions should not use long-lived AWS IAM access keys.

The preferred authentication mechanism is:

```text
GitHub Actions
      |
      v
GitHub OIDC Token
      |
      v
AWS IAM Identity Provider
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

This removes the need to store:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

as long-lived GitHub secrets.

---

## GitHub OIDC Trust Design

AWS will contain an IAM OpenID Connect provider for:

```text
token.actions.githubusercontent.com
```

A dedicated CI/CD IAM role will trust only approved GitHub repository identities.

The trust policy should be restricted using claims such as:

- Repository
- Branch
- Environment
- Workflow context where practical

The role should not trust every GitHub repository.

The CI/CD role should follow least privilege.

Initial permissions should be limited to the AWS operations required by the pipeline.

For container publication, permissions may include:

- ECR authorization
- Upload image layers
- Put image
- Retrieve repository metadata

Additional AWS permissions should be added only when a pipeline stage requires them.

---

## GitHub Actions Permissions

Workflow permissions should be explicitly defined.

Example baseline:

```yaml
permissions:
  contents: read
  id-token: write
```

Additional permissions should only be granted when required.

Workflows should not rely on unnecessarily broad default GitHub token permissions.

---

## Amazon ECR Integration

The pipeline publishes approved container images to the Phase 03 Amazon ECR repositories.

Authentication uses temporary AWS credentials obtained through GitHub OIDC.

The final publication workflow is:

```text
GitHub Actions
      |
      v
Assume AWS CI/CD role through OIDC
      |
      v
Authenticate to Amazon ECR
      |
      v
Build exact container images
      |
      v
Scan exact images with Trivy
      |
      v
Generate CycloneDX SBOMs
      |
      v
Push the same images to ECR
      |
      v
Resolve SHA256 image digests
      |
      v
Generate build provenance
      |
      v
Sign immutable digests with Cosign
      |
      v
Verify signatures
      |
      v
Verify provenance
```

---

## Image Tagging Strategy

Human-readable tags should preserve traceability.

Potential tags include:

```text
sha-<short-commit>
pr-<pull-request-number>
build-<workflow-run-id>
```

Mutable tags such as:

```text
latest
```

should not be the primary deployment reference.

The final image digest is the authoritative artifact identity.

---

## Immutable Artifact Promotion

The same built artifact should move through environments.

The pipeline should avoid:

```text
Build Dev Image
Build Test Image
Build Production Image
```

Instead:

```text
Build Once
    |
    v
Scan
    |
    v
Approve
    |
    v
Publish
    |
    v
Promote Same Digest
```

This reduces the risk that the artifact tested is different from the artifact eventually deployed.

---

## Separation of CI and Deployment

Phase 05 focuses on:

```text
Continuous Integration
Artifact Security
Artifact Publication
```

The long-term deployment model is GitOps.

Phase 06 will introduce:

```text
Argo CD
```

Therefore the preferred model is:

```text
CI Pipeline
     |
     v
Build + Test + Scan + Sign
     |
     v
Amazon ECR
     |
     v
Update approved deployment reference
     |
     v
Git Repository
     |
     v
Argo CD
     |
     v
Amazon EKS
```

The CI pipeline should not become permanently responsible for directly running:

```text
kubectl apply
```

against production-style environments.

This keeps build concerns separate from deployment reconciliation.

---

## Approval Gates

Explicit environment or production-promotion approval gates are not implemented in Phase 05.

Phase 05 focuses on:

- pull-request validation
- required CI and security checks
- protected `main` branch workflow
- secure artifact publication
- immutable artifact identity
- GitOps handoff

The repository already uses pull-request-based change control and successful CI/security checks before merge.

Additional promotion controls will be introduced when higher-environment and GitOps deployment workflows require them.

Future controls may include:

- GitHub Environments
- Required deployment reviewers
- Environment protection rules
- Manual production promotion
- Policy-based artifact approval

Development automation can remain relatively fast, while higher-risk environments should require stronger approval controls.

These controls are intentionally deferred rather than represented as completed Phase 05 functionality.

---

## Branch Strategy

The repository continues to use:

```text
main
feature/*
security/*
fix/*
docs/*
```

Phase 05 implementation branch:

```text
feature/cicd-foundation
```

Security validation should run on pull requests before changes reach:

```text
main
```

The main branch should remain protected from direct uncontrolled changes.

---

## Pull Request Controls

Recommended pull-request controls include:

- Require pull request before merge
- Require successful CI checks
- Require security checks
- Require conversation resolution
- Block force pushes
- Block branch deletion where appropriate
- Prefer squash merging for clean phase history

No workflow should allow an unreviewed failing build to merge into the protected default branch.

---

## Failure Criteria

The pipeline should fail when required conditions are not met.

Examples:

```text
Application does not compile
Required tests fail
Critical SAST finding detected
Critical dependency vulnerability detected
Secret detected
Terraform validation fails
Critical IaC finding exceeds policy
Kubernetes manifest violates required policy
Critical container vulnerability detected
Artifact signing fails
ECR publication fails
```

Failure conditions should be documented and predictable.

---

## Risk-Based Security Decisions

Security scanners assist engineering decisions but do not replace them.

Every finding should be evaluated based on:

- Actual attack surface
- Severity
- Exploitability
- Environment
- Operational impact
- Application requirements
- Compensating controls
- Cost
- Compliance requirements

Where appropriate, findings may be classified as:

```text
Remediated
Accepted Risk
Deferred Control
False Positive / Not Applicable
```

The final decision should be documented.

---

## Artifact Traceability

The pipeline should allow a reviewer to trace an artifact back to its origin.

An image should be associated with:

```text
Git repository
Commit SHA
Workflow run
Build timestamp
Image tag
Image digest
Security scan results
SBOM
Signature
```

This supports:

- Incident investigation
- Rollback
- Vulnerability response
- Compliance evidence
- Supply-chain assurance

---

## Workflow Security

GitHub Actions workflows should follow secure workflow practices.

Controls include:

- Minimal GitHub token permissions
- OIDC instead of long-lived AWS credentials
- Pin third-party actions to trusted versions or immutable commit references where practical
- Avoid printing secrets
- Avoid untrusted pull-request data in shell commands
- Restrict privileged workflow triggers
- Use protected environments for sensitive actions
- Separate validation workflows from privileged publication workflows where appropriate

---

## Third-Party GitHub Actions

Third-party actions introduce software supply-chain risk.

The project should evaluate:

- Publisher reputation
- Action permissions
- Release history
- Marketplace verification where available
- Version pinning
- Commit-SHA pinning for sensitive workflows

High-privilege workflows should avoid unnecessary third-party actions.

---

## CI/CD Secrets Strategy

The preferred security model is:

```text
No long-lived AWS access keys
```

Where secrets are unavoidable:

- Store them in GitHub encrypted secrets or approved secret-management systems
- Scope them narrowly
- Rotate them regularly
- Do not print them in logs
- Do not make them available to untrusted pull-request workflows

Later project phases may integrate:

```text
AWS Secrets Manager
AWS Systems Manager Parameter Store
```

where appropriate.

---

## Logging and Auditability

CI/CD activity should provide sufficient evidence for troubleshooting and security review.

Important records include:

- Workflow initiator
- Commit SHA
- Job result
- Scan result
- Artifact digest
- Publication event
- Approval event
- Failure reason

Future security-monitoring phases may correlate CI/CD activity with:

- AWS CloudTrail
- ECR events
- Kubernetes audit logs
- SIEM alerts

---

## Cost Strategy

Most Phase 05 work does not require the Amazon EKS cluster to remain online.

The cost-conscious implementation strategy is:

```text
Build pipeline
      |
      v
Implement security gates
      |
      v
Validate scans
      |
      v
Publish artifacts to ECR
      |
      v
Complete most CI/CD testing
      |
      v
Recreate EKS only when deployment validation is required
      |
      v
Validate deployment
      |
      v
Destroy EKS again
```

This allows CI/CD development to continue without continuously paying for:

- EKS control plane
- EC2 worker nodes

Phase 03 infrastructure remains active and may continue to generate AWS charges, particularly the NAT Gateway.

---

## Validation Plan

Phase 05 validation should demonstrate that the pipeline works under both success and failure conditions.

### Successful Pipeline

```text
Build passes
Tests pass
Security scans pass
Container builds
Container scan passes
SBOM generated
Artifact signed
Image published to ECR
Digest recorded
```

### Failed Security Pipeline

```text
Controlled insecure change introduced
Scanner detects finding
Security gate fails
Artifact is not published
Finding is remediated
Pipeline reruns
Pipeline passes
```

### AWS Authentication Validation

```text
GitHub OIDC succeeds
Temporary AWS credentials issued
No long-lived AWS access keys stored
ECR authentication succeeds
```

### Artifact Validation

```text
Image exists in ECR
Expected commit tag exists
SHA256 digest recorded
SBOM associated with artifact
Signature verification succeeds
```

---

## Phase 05 Documentation

The Phase 05 documentation set should include:

```text
05-cicd/
├── README.md
├── docs/
│   ├── pipeline-design.md
│   ├── security-controls.md
│   └── validation.md
└── scripts/
```

GitHub Actions workflows will be stored under:

```text
.github/
└── workflows/
```

Potential workflows include:

```text
backend-ci.yml
frontend-ci.yml
infrastructure-security.yml
container-build.yml
```

The final workflow structure may be adjusted as the implementation develops.

---

## Future Jenkins Implementation

A later implementation will reproduce the secure delivery pattern using Jenkins.

Potential Jenkins capabilities include:

- Jenkinsfile pipeline-as-code
- Maven and npm builds
- Security scan stages
- Docker build
- Trivy gating
- SBOM generation
- ECR publishing
- AWS authentication
- Approval stages
- Artifact promotion

The goal is to demonstrate portability of DevSecOps practices rather than dependence on a single CI/CD platform.

---

## Future GitLab CI Implementation

A later implementation will reproduce the same security principles using GitLab CI.

Potential capabilities include:

- `.gitlab-ci.yml`
- GitLab stages
- Dependency caching
- Security jobs
- Container builds
- Security gates
- ECR publication
- Artifact handling
- Approval controls

The implementation should demonstrate that secure software-delivery concepts are platform-independent.

---

## Relationship to Later Phases

Phase 05 creates foundations used by multiple later phases.

### Phase 06 - GitOps

Argo CD will consume approved deployment state and reconcile Kubernetes environments.

### Phase 11 - DevSecOps

Security automation and advanced pipeline controls will be expanded.

### Phase 14 - Kubernetes Security

Policy-as-code, NetworkPolicies, admission controls, and workload identity will strengthen cluster security.

### Phase 15 - Application Security

Application-focused SAST, DAST, API security, and secure coding controls will expand.

### Phase 16 - Supply Chain Security

SBOMs, signing, provenance, attestation, and artifact-verification controls will become more advanced.

### Phase 17 - Incident Response

CI/CD logs and artifact metadata will support investigation and response exercises.

---

## Phase 05 Target Outcome

At the end of Phase 05, Baba App should have a CI/CD and software supply-chain foundation capable of demonstrating:

```text
Automated backend build validation
Automated frontend build validation
CI test-stage execution
Security scanning
Enforceable security gates
Secrets protection
Static Application Security Testing
Software Composition Analysis
Terraform security scanning
Kubernetes manifest scanning
Container vulnerability scanning
SBOM generation
Exact-image publication controls
AWS OIDC authentication
Least-privilege Amazon ECR access
Immutable image publication
Image digest traceability
Keyless artifact signing
Signature verification
Build provenance
Provenance verification
Risk-based security exception handling
CI and deployment separation
GitOps-ready artifact delivery
```
Meaningful backend and frontend automated test coverage remains technical debt and should not be represented as complete application test coverage.

Explicit environment or production-promotion approval gates are deferred until later deployment and GitOps workflows require them.

The completed phase should demonstrate that CI/CD is not merely a mechanism for building and publishing software.

It is also a security enforcement point within the software-development lifecycle.
