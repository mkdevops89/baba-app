# Security Policy

## Purpose

Baba App is a cloud-security and DevSecOps reference implementation. This
policy explains how to report suspected vulnerabilities safely and how
security reports are evaluated and remediated.

## Supported Version

Security fixes are applied to the current `main` branch. Historical branches,
commits, generated artifacts, and retired environments are not independently
supported.

## Reporting a Vulnerability

Do not disclose an unpatched vulnerability through a public GitHub issue,
discussion, pull request, commit message, or social-media post.

Submit the finding through the repository's private vulnerability-reporting
channel:

https://github.com/mkdevops89/baba-app/security/advisories/new

A useful report should include:

- the affected component, file, package, image, or cloud resource
- the vulnerability or weakness being reported
- steps required to reproduce or validate the finding
- the expected and observed behavior
- the potential confidentiality, integrity, or availability impact
- affected versions, branches, or deployment environments
- supporting logs, screenshots, or proof-of-concept details
- suggested remediation or compensating controls, when available

Do not include active credentials, access tokens, private keys, personal
information, customer data, or unrelated sensitive information in the report.

## Response Process

The maintainer will:

1. acknowledge the report when it is received
2. validate the finding and affected scope
3. assign a risk rating and remediation owner
4. determine whether containment or compensating controls are required
5. implement and validate remediation
6. coordinate disclosure after the risk has been addressed

Target remediation periods are:

| Severity | Target |
|---|---:|
| Critical | 1 day |
| High | 7 days |
| Medium | 30 days |
| Low | 90 days |

These targets reflect the repository's DevSecOps security-gate policy.
Remediation timing may be adjusted when no vendor fix exists, provided the
risk is documented through the governed exception process.

## Security Exceptions

A scanner suppression does not, by itself, constitute risk acceptance.

Every active exception must:

- have an owner and documented rationale
- identify the affected scope and finding
- record compensating controls
- reference the applicable scanner suppression
- have an expiration date of no more than 90 days
- be reassessed before expiration

The authoritative exception process is documented in
`11-devsecops/docs/exception-process.md`.

## Public Remediation Tracking

After a vulnerability has been disclosed publicly or no longer requires
confidential handling, remediation may be tracked with the repository's
Security Remediation issue template.

The public issue template must not be used for:

- previously undisclosed vulnerabilities
- active secrets or credentials
- exploit code that creates unnecessary risk
- sensitive infrastructure or account information

## Safe-Harbor Intent

Good-faith security research that avoids privacy violations, service
disruption, data destruction, unauthorized persistence, and unnecessary
access will be treated as an effort to improve the project.

This statement does not authorize testing against systems or accounts that
the researcher does not own or have explicit permission to test.
