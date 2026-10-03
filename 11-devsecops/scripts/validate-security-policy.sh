#!/usr/bin/env bash

# Validate Phase 11 security gates and exception governance.
#
# The script performs two kinds of checks:
#   1. It validates the structure, values, dates, and lifecycle of the JSON
#      policy records.
#   2. It reconciles those records with scanner-native suppressions in the
#      repository so undocumented or stale exceptions cannot go unnoticed.

set -euo pipefail

# Resolve paths relative to this script so the validator works from any
# directory, including a developer workstation or a GitHub Actions runner.
SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

REPOSITORY_ROOT="$(
  cd "${SCRIPT_DIR}/../.."
  pwd
)"

# Allow CI or local callers to validate alternate policy files without changing
# the repository defaults.
GATE_POLICY="${SECURITY_GATE_POLICY:-${REPOSITORY_ROOT}/11-devsecops/policies/security-gates.json}"
EXCEPTION_POLICY="${SECURITY_EXCEPTION_POLICY:-${REPOSITORY_ROOT}/11-devsecops/policies/security-exceptions.json}"

# Allow deterministic expiration testing by overriding the current date.
VALIDATION_DATE="${VALIDATION_DATE:-$(date +%F)}"

# -----------------------------------------------------------------------------
# Result helpers
# -----------------------------------------------------------------------------

# Accumulate policy failures so the script can report every discovered problem
# in one run rather than stopping at the first invalid record.
FAILURES=0

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

pass() {
  echo "PASS: $*"
}

# -----------------------------------------------------------------------------
# Dependency and input validation
# -----------------------------------------------------------------------------

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required." >&2
  exit 1
}

# Stop immediately when an input file is unavailable or malformed. The
# remaining checks depend on both documents being valid JSON.
for policy_file in \
  "${GATE_POLICY}" \
  "${EXCEPTION_POLICY}"
do
  if [[ ! -s "${policy_file}" ]]; then
    echo "ERROR: required policy file is missing or empty: ${policy_file}" >&2
    exit 1
  fi

  if ! jq empty "${policy_file}" >/dev/null 2>&1; then
    echo "ERROR: invalid JSON: ${policy_file}" >&2
    exit 1
  fi
done

pass "policy files contain valid JSON"

# -----------------------------------------------------------------------------
# Security gate policy validation
# -----------------------------------------------------------------------------

# Confirm the gate policy exposes the fields needed by all later checks.
if jq -e '
  (.schema_version | type == "string" and length > 0)
  and
  (.policy_id | type == "string" and length > 0)
  and
  (.effective_date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
  and
  (.gates | type == "array" and length > 0)
  and
  (.severity_levels | type == "array" and length > 0)
  and
  (.exception_requirements.required_fields | type == "array")
  and
  (.exception_requirements.allowed_statuses | type == "array")
  and
  (
    .exception_requirements.maximum_validity_days |
    type == "number" and . > 0
  )
' "${GATE_POLICY}" >/dev/null
then
  pass "security gate policy contains the required structure"
else
  fail "security gate policy is missing required attributes"
fi

# Duplicate gate identifiers make reports and CI enforcement ambiguous.
if jq -e '
  [.gates[].id] as $ids |
  ($ids | length) == ($ids | unique | length)
' "${GATE_POLICY}" >/dev/null
then
  pass "security gate IDs are unique"
else
  fail "security gate policy contains duplicate gate IDs"
fi

# Verify every declared severity has a positive remediation deadline.
if jq -e '
  .remediation_sla_days as $sla |
  all(
    .severity_levels[];
    ($sla[.] | type == "number" and . > 0)
  )
' "${GATE_POLICY}" >/dev/null
then
  pass "every supported severity has a positive remediation SLA"
else
  fail "one or more severity levels lack a valid remediation SLA"
fi

# -----------------------------------------------------------------------------
# Security exception registry validation
# -----------------------------------------------------------------------------

# Validate the registry envelope before inspecting individual exceptions.
if jq -e '
  (.schema_version | type == "string" and length > 0)
  and
  (.generated_for | type == "string" and length > 0)
  and
  (.last_reviewed | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
  and
  (.exceptions | type == "array")
' "${EXCEPTION_POLICY}" >/dev/null
then
  pass "security exception registry contains the required structure"
else
  fail "security exception registry is missing required attributes"
fi

# Dynamically enforce the required fields declared by security-gates.json.
# This avoids maintaining a second, potentially inconsistent field list here.
MISSING_FIELDS="$(
  jq -n \
    --slurpfile gates "${GATE_POLICY}" \
    --slurpfile exceptions "${EXCEPTION_POLICY}" '
      def missing:
        . == null or
        . == "" or
        . == [] or
        . == {};

      $gates[0]
        .exception_requirements
        .required_fields as $required |

      [
        $exceptions[0].exceptions[] as $exception |
        $required[] as $field |
        select($exception[$field] | missing) |
        {
          exception:
            ($exception.id // "unknown"),
          missing_field: $field
        }
      ]
    '
)"

if [[ "$(jq 'length' <<< "${MISSING_FIELDS}")" -eq 0 ]]; then
  pass "every exception contains all required fields"
else
  fail "one or more exceptions have missing required fields"
  jq . <<< "${MISSING_FIELDS}" >&2
fi

# Each governance record needs a stable identifier for reviews and evidence.
if jq -e '
  [.exceptions[].id] as $ids |
  ($ids | length) == ($ids | unique | length)
' "${EXCEPTION_POLICY}" >/dev/null
then
  pass "exception record IDs are unique"
else
  fail "exception registry contains duplicate record IDs"
fi

# A finding may exist in multiple scanners, but the same scanner/finding pair
# must not have more than one active governance record.
if jq -e '
  [
    .exceptions[] |
    "\(.scanner)::\(.finding_id)"
  ] as $findings |
  ($findings | length) == ($findings | unique | length)
' "${EXCEPTION_POLICY}" >/dev/null
then
  pass "scanner and finding combinations are unique"
else
  fail "exception registry contains duplicate scanner/finding combinations"
fi

# Risk ratings must use the severity vocabulary declared by the gate policy.
if jq -n -e \
  --slurpfile gates "${GATE_POLICY}" \
  --slurpfile exceptions "${EXCEPTION_POLICY}" '
    $gates[0].severity_levels as $allowed |
    all(
      $exceptions[0].exceptions[];
      .risk as $risk |
      $allowed | index($risk) != null
    )
  ' >/dev/null
then
  pass "all exception risk ratings use supported severity values"
else
  fail "one or more exceptions use an unsupported risk rating"
fi

# Exception lifecycle states must use the values approved by policy.
if jq -n -e \
  --slurpfile gates "${GATE_POLICY}" \
  --slurpfile exceptions "${EXCEPTION_POLICY}" '
    $gates[0]
      .exception_requirements
      .allowed_statuses as $allowed |

    all(
      $exceptions[0].exceptions[];
      .status as $status |
      $allowed | index($status) != null
    )
  ' >/dev/null
then
  pass "all exception statuses are allowed by policy"
else
  fail "one or more exceptions use an unsupported status"
fi

# Verify ISO date formatting, real calendar dates, and chronological ordering.
if jq -e '
  all(
    .exceptions[];
    (.created_date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
    and
    (.expires_date | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
    and
    (
      try (
        (.created_date + "T00:00:00Z" | fromdateiso8601) <=
        (.expires_date + "T00:00:00Z" | fromdateiso8601)
      ) catch false
    )
  )
' "${EXCEPTION_POLICY}" >/dev/null
then
  pass "all exception dates are valid and chronologically ordered"
else
  fail "one or more exceptions contain invalid or reversed dates"
fi

# Prevent exceptions from remaining valid longer than the maximum review window
# defined in the security gate policy.
if jq -n -e \
  --slurpfile gates "${GATE_POLICY}" \
  --slurpfile exceptions "${EXCEPTION_POLICY}" '
    $gates[0]
      .exception_requirements
      .maximum_validity_days as $maximum |

    all(
      $exceptions[0].exceptions[];
      (
        (
          .expires_date + "T00:00:00Z" |
          fromdateiso8601
        )
        -
        (
          .created_date + "T00:00:00Z" |
          fromdateiso8601
        )
      ) <= ($maximum * 86400)
    )
  ' >/dev/null
then
  pass "exception validity periods do not exceed policy limits"
else
  fail "one or more exceptions exceed the maximum validity period"
fi

# Active exceptions must be reviewed, closed, or renewed before expiration.
# Historical records marked closed or expired remain available as audit evidence.
EXPIRED_ACTIVE="$(
  jq \
    --arg today "${VALIDATION_DATE}" '
      [
        .exceptions[] |
        select(
          .status == "accepted" or
          .status == "remediation-planned" or
          .status == "false-positive"
        ) |
        select(.expires_date < $today) |
        {
          id,
          finding_id,
          expires_date,
          status
        }
      ]
    ' "${EXCEPTION_POLICY}"
)"

if [[ "$(jq 'length' <<< "${EXPIRED_ACTIVE}")" -eq 0 ]]; then
  pass "no active security exceptions are expired"
else
  fail "one or more active security exceptions are expired"
  jq . <<< "${EXPIRED_ACTIVE}" >&2
fi

# -----------------------------------------------------------------------------
# Native suppression reconciliation
# -----------------------------------------------------------------------------
# Build an inventory from scanner-native configuration:
#   - workflow-level Checkov skip_check values;
#   - inline Terraform Checkov and Trivy suppressions; and
#   - Trivy container CVE ignore entries.
#
# Comparing this inventory with the registry prevents suppressions from being
# added without a documented owner, rationale, risk, controls, and expiration.

TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

NATIVE_RAW="${TEMP_DIR}/native-raw.txt"
NATIVE_FINDINGS="${TEMP_DIR}/native-findings.txt"
REGISTERED_FINDINGS="${TEMP_DIR}/registered-findings.txt"
MISSING_RECORDS="${TEMP_DIR}/missing-records.txt"
STALE_RECORDS="${TEMP_DIR}/stale-records.txt"

: > "${NATIVE_RAW}"

# Collect workflow-level suppression declarations.
if [[ -d "${REPOSITORY_ROOT}/.github/workflows" ]]; then
  grep -RhE \
    'skip_check:|checkov:skip=|trivy:ignore:' \
    "${REPOSITORY_ROOT}/.github/workflows" \
    >> "${NATIVE_RAW}" 2>/dev/null || true
fi

# Collect inline suppressions from Terraform source while excluding downloaded
# provider and module content under .terraform directories.
grep -RhoE \
  --include='*.tf' \
  --exclude-dir=.terraform \
  'checkov:skip=[A-Z0-9_]+|trivy:ignore:[A-Z0-9_-]+' \
  "${REPOSITORY_ROOT}/03-terraform" \
  >> "${NATIVE_RAW}" 2>/dev/null || true

# Collect vulnerability IDs from Trivy's scanner-native exception file.
if [[ -f "${REPOSITORY_ROOT}/05-cicd/trivy-container-ignore.yaml" ]]; then
  grep -E \
    '^[[:space:]]*-[[:space:]]+id:[[:space:]]+CVE-' \
    "${REPOSITORY_ROOT}/05-cicd/trivy-container-ignore.yaml" \
    >> "${NATIVE_RAW}" || true
fi

# Normalize all supported scanner identifiers into a unique sorted inventory.
grep -Eo \
  'CVE-[0-9]{4}-[0-9]+|CKV2?_[A-Z0-9_]+|AWS-[0-9]{4}' \
  "${NATIVE_RAW}" |
sort -u > "${NATIVE_FINDINGS}" || true

# Only active exception records should correspond to live scanner suppressions.
jq -r \
  '.exceptions[] |
   select(
     .status == "accepted" or
     .status == "remediation-planned" or
     .status == "false-positive"
   ) |
   .finding_id' \
  "${EXCEPTION_POLICY}" |
sort -u > "${REGISTERED_FINDINGS}"

# Native finding IDs without registry entries are undocumented suppressions.
comm -23 \
  "${NATIVE_FINDINGS}" \
  "${REGISTERED_FINDINGS}" \
  > "${MISSING_RECORDS}"

# Active registry entries without native suppressions are stale. After a
# suppression is removed, its governance record should be closed or expired.
comm -13 \
  "${NATIVE_FINDINGS}" \
  "${REGISTERED_FINDINGS}" \
  > "${STALE_RECORDS}"

if [[ ! -s "${MISSING_RECORDS}" ]]; then
  pass "every native scanner suppression has a governance record"
else
  fail "native suppressions are missing governance records"
  sed 's/^/  - /' "${MISSING_RECORDS}" >&2
fi

if [[ ! -s "${STALE_RECORDS}" ]]; then
  pass "every active governance record maps to a native suppression"
else
  fail "active governance records no longer map to native suppressions"
  sed 's/^/  - /' "${STALE_RECORDS}" >&2
fi

# -----------------------------------------------------------------------------
# Final validation summary
# -----------------------------------------------------------------------------

EXCEPTION_COUNT="$(
  jq '.exceptions | length' "${EXCEPTION_POLICY}"
)"

NATIVE_COUNT="$(
  wc -l < "${NATIVE_FINDINGS}" |
  tr -d '[:space:]'
)"

echo
echo "Security policy validation summary"
echo "  Validation date: ${VALIDATION_DATE}"
echo "  Registered exceptions: ${EXCEPTION_COUNT}"
echo "  Native suppressions: ${NATIVE_COUNT}"
echo "  Failures: ${FAILURES}"

# Return a nonzero exit code so CI blocks the job whenever any policy check
# failed. When no failures exist, emit a single final success result.
if (( FAILURES > 0 )); then
  echo "FAIL: security policy validation failed" >&2
  exit 1
fi

echo "PASS: security policy validation completed successfully"
