#!/usr/bin/env bash

# Exercise the Phase 11 policy validator with both valid and intentionally
# invalid inputs. A passing test suite proves the validator accepts the current
# policies and rejects common exception-governance failures.

set -euo pipefail

# Resolve repository paths relative to this script so tests work locally and in
# GitHub Actions regardless of the caller's current directory.
SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

REPOSITORY_ROOT="$(
  cd "${SCRIPT_DIR}/../.."
  pwd
)"

VALIDATOR="${REPOSITORY_ROOT}/11-devsecops/scripts/validate-security-policy.sh"
EXCEPTION_POLICY="${REPOSITORY_ROOT}/11-devsecops/policies/security-exceptions.json"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required." >&2
  exit 1
}

if [[ ! -x "${VALIDATOR}" ]]; then
  echo "ERROR: validator is missing or not executable: ${VALIDATOR}" >&2
  exit 1
fi

if [[ ! -s "${EXCEPTION_POLICY}" ]]; then
  echo "ERROR: exception policy is missing or empty: ${EXCEPTION_POLICY}" >&2
  exit 1
fi

# Keep intentionally invalid policies and captured output outside the
# repository. The trap guarantees cleanup whether the test suite passes or
# fails.
TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

TEST_FAILURES=0

pass() {
  echo "PASS: $*"
}

fail() {
  echo "FAIL: $*" >&2
  TEST_FAILURES=$((TEST_FAILURES + 1))
}

# Run a command that must fail and confirm its output contains the expected
# reason. This prevents an unrelated runtime error from being mistaken for a
# successful negative security test.
expect_failure() {
  local test_name="$1"
  local expected_pattern="$2"
  local output_file="$3"

  shift 3

  if "$@" > "${output_file}" 2>&1; then
    fail "${test_name}: command unexpectedly succeeded"
    return
  fi

  if grep -Eq "${expected_pattern}" "${output_file}"; then
    pass "${test_name}"
  else
    fail "${test_name}: expected failure reason was not reported"
    sed 's/^/  /' "${output_file}" >&2
  fi
}

# -----------------------------------------------------------------------------
# Positive control
# -----------------------------------------------------------------------------

# The unmodified repository policies must pass before testing failure cases.
if "${VALIDATOR}" > "${TEMP_DIR}/positive.txt" 2>&1; then
  pass "current repository policies are valid"
else
  fail "current repository policies failed validation"
  sed 's/^/  /' "${TEMP_DIR}/positive.txt" >&2
fi

# -----------------------------------------------------------------------------
# Negative control: expired active exception
# -----------------------------------------------------------------------------

# Use fixed dates so this test remains deterministic regardless of when it runs.
EXPIRED_POLICY="${TEMP_DIR}/expired-exception.json"

jq '
  (.exceptions[] |
   select(.id == "SEC-EXC-001")) |=
  (
    .created_date = "2026-10-01" |
    .expires_date = "2026-10-02"
  )
' "${EXCEPTION_POLICY}" > "${EXPIRED_POLICY}"

expect_failure \
  "expired active exceptions are rejected" \
  "active security exceptions are expired" \
  "${TEMP_DIR}/expired-output.txt" \
  env \
    VALIDATION_DATE=2026-10-03 \
    SECURITY_EXCEPTION_POLICY="${EXPIRED_POLICY}" \
    "${VALIDATOR}"

# -----------------------------------------------------------------------------
# Negative control: missing required owner
# -----------------------------------------------------------------------------

MISSING_OWNER_POLICY="${TEMP_DIR}/missing-owner.json"

jq '
  (.exceptions[] |
   select(.id == "SEC-EXC-001")) |=
  del(.owner)
' "${EXCEPTION_POLICY}" > "${MISSING_OWNER_POLICY}"

expect_failure \
  "exceptions without owners are rejected" \
  "missing required fields" \
  "${TEMP_DIR}/missing-owner-output.txt" \
  env \
    SECURITY_EXCEPTION_POLICY="${MISSING_OWNER_POLICY}" \
    "${VALIDATOR}"

# -----------------------------------------------------------------------------
# Negative control: undocumented native suppression
# -----------------------------------------------------------------------------

# Removing a registry entry while leaving its Trivy ignore in place must expose
# the finding as an undocumented suppression.
MISSING_RECORD_POLICY="${TEMP_DIR}/missing-record.json"

jq '
  .exceptions |=
  map(select(.id != "SEC-EXC-023"))
' "${EXCEPTION_POLICY}" > "${MISSING_RECORD_POLICY}"

expect_failure \
  "native suppressions without governance records are rejected" \
  "native suppressions are missing governance records" \
  "${TEMP_DIR}/missing-record-output.txt" \
  env \
    SECURITY_EXCEPTION_POLICY="${MISSING_RECORD_POLICY}" \
    "${VALIDATOR}"

# -----------------------------------------------------------------------------
# Negative control: stale active governance record
# -----------------------------------------------------------------------------

# Add a structurally valid active record that has no matching scanner-native
# suppression. This verifies that remediated exceptions cannot remain active.
STALE_RECORD_POLICY="${TEMP_DIR}/stale-record.json"

jq '
  .exceptions += [
    (
      .exceptions[] |
      select(.id == "SEC-EXC-003") |
      .id = "SEC-TEST-STALE" |
      .scanner = "TestScanner" |
      .finding_id = "TEST-STALE-001" |
      .scope = ["test-only"] |
      .rationale = "Negative validation test only." |
      .review_reference = "Automated policy test" |
      .created_date = "2026-10-01" |
      .expires_date = "2026-10-30"
    )
  ]
' "${EXCEPTION_POLICY}" > "${STALE_RECORD_POLICY}"

expect_failure \
  "active records without native suppressions are rejected" \
  "active governance records no longer map to native suppressions" \
  "${TEMP_DIR}/stale-record-output.txt" \
  env \
    VALIDATION_DATE=2026-10-03 \
    SECURITY_EXCEPTION_POLICY="${STALE_RECORD_POLICY}" \
    "${VALIDATOR}"

# -----------------------------------------------------------------------------
# Final test summary
# -----------------------------------------------------------------------------

echo
echo "Security policy test summary"
echo "  Positive controls: 1"
echo "  Negative controls: 4"
echo "  Failures: ${TEST_FAILURES}"

if (( TEST_FAILURES > 0 )); then
  echo "FAIL: security policy tests failed" >&2
  exit 1
fi

echo "PASS: security policy tests completed successfully"
