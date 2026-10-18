## Summary

<!-- Explain the problem and the outcome of this change. -->

## Change Type

<!-- Select every applicable category. -->

- [ ] Application
- [ ] Infrastructure
- [ ] CI/CD or automation
- [ ] Security control
- [ ] Vulnerability remediation
- [ ] Documentation
- [ ] Dependency update

## Security Impact

<!--
Describe how this change affects confidentiality, integrity, availability,
identity, logging, networking, secrets, dependencies, or deployment security.
Write "No material security impact" only after evaluating these areas.
-->

## Validation

<!-- List the commands, tests, scans, and runtime checks that were completed. -->

- [ ] Functional tests passed
- [ ] Relevant security scans passed
- [ ] Policy validation passed
- [ ] Documentation was updated
- [ ] No credentials or sensitive evidence were committed

## Security Findings and Exceptions

<!--
List related CVE, GHSA, Checkov, Trivy, CodeQL, Gitleaks, or policy finding IDs.
If a finding is suppressed, provide its SEC-EXC record and expiration date.
Use "None" when the change introduces no exception.
-->

## Evidence

<!--
Link non-sensitive workflow runs, issues, reports, plans, or validation output.
Do not paste credentials, tokens, account identifiers, or sensitive logs.
-->

## Reviewer Checklist

- [ ] The change is limited to the documented scope
- [ ] Least privilege is preserved
- [ ] Security controls were not silently weakened
- [ ] New suppressions have governance records
- [ ] Remediation claims are supported by validation evidence
- [ ] Rollback or recovery considerations were evaluated
