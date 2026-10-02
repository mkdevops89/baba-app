#!/usr/bin/env bash

set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-baba-admin}"
AWS_REGION_NAME="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT:-baba-app}"
ENVIRONMENT_NAME="${ENVIRONMENT:-dev}"

TEMP_DIR="$(mktemp -d)"
INVENTORY_FILE="${TEMP_DIR}/tag-inventory.json"
PENDING_KMS_FILE="${TEMP_DIR}/pending-kms.txt"

cleanup() {
  rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

command -v aws >/dev/null 2>&1 || {
  echo "ERROR: aws CLI is required." >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required." >&2
  exit 1
}

AWS_COMMAND=(
  aws
  --profile "${AWS_PROFILE_NAME}"
  --region "${AWS_REGION_NAME}"
)

"${AWS_COMMAND[@]}" resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Project,Values=${PROJECT_NAME}" \
  --output json \
  > "${INVENTORY_FILE}"

jq -r \
  --arg project "${PROJECT_NAME}" \
  --arg environment "${ENVIRONMENT_NAME}" '
    def tagmap:
      (.Tags // [] | map({key: .Key, value: .Value}) | from_entries);

    .ResourceTagMappingList[] |
    (tagmap) as $tags |
    select(
      (.ResourceARN | split(":")[2]) == "kms" and
      (
        $tags.Project != $project or
        $tags.Environment != $environment or
        $tags.ManagedBy != "Terraform" or
        $tags.Owner != "platform-engineering" or
        $tags.CostCenter != "portfolio" or
        (($tags.Phase // "") | length == 0)
      )
    ) |
    .ResourceARN
  ' "${INVENTORY_FILE}" |
while IFS= read -r resource_arn; do
  key_id="${resource_arn##*/}"

  key_state="$(
    "${AWS_COMMAND[@]}" kms describe-key \
      --key-id "${key_id}" \
      --query 'KeyMetadata.KeyState' \
      --output text 2>/dev/null || true
  )"

  if [[ "${key_state}" == "PendingDeletion" ]]; then
    printf '%s\n' "${resource_arn}" >> "${PENDING_KMS_FILE}"
  fi
done

touch "${PENDING_KMS_FILE}"

REPORT="$(
  jq \
    --arg project "${PROJECT_NAME}" \
    --arg environment "${ENVIRONMENT_NAME}" \
    --rawfile pending_kms "${PENDING_KMS_FILE}" '
      def tagmap:
        (.Tags // [] | map({key: .Key, value: .Value}) | from_entries);

      def pending_kms_arns:
        ($pending_kms | split("\n") | map(select(length > 0)));

      def compliant($tags):
        (
          $tags.Project == $project and
          $tags.Environment == $environment and
          $tags.ManagedBy == "Terraform" and
          $tags.Owner == "platform-engineering" and
          $tags.CostCenter == "portfolio" and
          (($tags.Phase // "") | length > 0)
        );

      [
        .ResourceTagMappingList[] |
        (tagmap) as $tags |
        {
          arn: .ResourceARN,
          service: (.ResourceARN | split(":")[2]),
          resource: (.ResourceARN | split(":") | .[5:] | join(":")),
          compliant: compliant($tags),
          missing_or_invalid:
            [
              if $tags.Project != $project then "Project" else empty end,
              if $tags.Environment != $environment then "Environment" else empty end,
              if $tags.ManagedBy != "Terraform" then "ManagedBy" else empty end,
              if $tags.Owner != "platform-engineering" then "Owner" else empty end,
              if $tags.CostCenter != "portfolio" then "CostCenter" else empty end,
              if (($tags.Phase // "") | length == 0) then "Phase" else empty end
            ]
        }
      ] as $discovered |

      [
        $discovered[] as $resource |
        select(
          (pending_kms_arns | index($resource.arn)) == null
        ) |
        $resource
      ] as $in_scope |

      [
        $discovered[] as $resource |
        select(
          (pending_kms_arns | index($resource.arn)) != null
        ) |
        {
          service: $resource.service,
          resource: $resource.resource,
          reason: "KMS key pending deletion"
        }
      ] as $exceptions |

      {
        project: $project,
        environment: $environment,
        discovered_resources: ($discovered | length),
        pending_deletion_exceptions: ($exceptions | length),
        in_scope_resources: ($in_scope | length),
        compliant_resources:
          ($in_scope | map(select(.compliant)) | length),
        noncompliant_resources:
          ($in_scope | map(select(.compliant | not)) | length),
        compliance_percent:
          (
            if ($in_scope | length) == 0 then 0
            else
              (
                (
                  ($in_scope | map(select(.compliant)) | length)
                  * 10000
                  / ($in_scope | length)
                ) | round / 100
              )
            end
          ),
        by_service:
          (
            $in_scope |
            sort_by(.service) |
            group_by(.service) |
            map({
              service: .[0].service,
              discovered: length,
              compliant: (map(select(.compliant)) | length)
            })
          ),
        exceptions: $exceptions,
        failures:
          (
            $in_scope |
            map(
              select(.compliant | not) |
              {
                service: .service,
                resource: .resource,
                missing_or_invalid: .missing_or_invalid
              }
            )
          )
      }
    ' "${INVENTORY_FILE}"
)"

printf '%s\n' "${REPORT}"

NONCOMPLIANT_COUNT="$(
  jq -r '.noncompliant_resources' <<< "${REPORT}"
)"

if [[ "${NONCOMPLIANT_COUNT}" -ne 0 ]]; then
  echo "FAIL: active resources do not meet the required tag standard." >&2
  exit 1
fi

echo "PASS: all active in-scope resources meet the required tag standard." >&2