#!/usr/bin/env bash

set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-baba-admin}"
AWS_REGION_NAME="${AWS_REGION:-us-east-1}"
BUDGET_NAME="${BUDGET_NAME:-baba-app-monthly-budget}"
BASELINE_START="${BASELINE_START:-}"
BASELINE_END="${BASELINE_END:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"
  pwd
)"

TEMP_DIR="$(mktemp -d)"

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

if date -v1d +%F >/dev/null 2>&1; then
  TODAY="$(date +%F)"
  CURRENT_MONTH_START="$(date -v1d +%F)"
else
  TODAY="$(date +%F)"
  CURRENT_MONTH_START="$(date +%Y-%m-01)"
fi

AWS_COMMAND=(
  aws
  --profile "${AWS_PROFILE_NAME}"
  --region "${AWS_REGION_NAME}"
)

BASELINE_FILE="${TEMP_DIR}/baseline.json"
TAG_FILE="${TEMP_DIR}/tags.json"
BUDGET_FILE="${TEMP_DIR}/budget.json"
NOTIFICATIONS_FILE="${TEMP_DIR}/notifications.json"
MONITORS_FILE="${TEMP_DIR}/monitors.json"
SUBSCRIPTIONS_FILE="${TEMP_DIR}/subscriptions.json"
ANOMALIES_FILE="${TEMP_DIR}/anomalies.json"
REPORT_FILE="${TEMP_DIR}/report.json"

START_DATE="${BASELINE_START}" \
END_DATE="${BASELINE_END}" \
AWS_PROFILE="${AWS_PROFILE_NAME}" \
AWS_REGION="${AWS_REGION_NAME}" \
  "${SCRIPT_DIR}/cost-baseline.sh" \
  > "${BASELINE_FILE}"

AWS_PROFILE="${AWS_PROFILE_NAME}" \
AWS_REGION="${AWS_REGION_NAME}" \
  "${SCRIPT_DIR}/tag-audit.sh" \
  > "${TAG_FILE}"

ACCOUNT_ID="$(
  "${AWS_COMMAND[@]}" sts get-caller-identity \
    --query Account \
    --output text
)"

"${AWS_COMMAND[@]}" budgets describe-budget \
  --account-id "${ACCOUNT_ID}" \
  --budget-name "${BUDGET_NAME}" \
  --output json \
  > "${BUDGET_FILE}"

"${AWS_COMMAND[@]}" budgets describe-notifications-for-budget \
  --account-id "${ACCOUNT_ID}" \
  --budget-name "${BUDGET_NAME}" \
  --output json \
  > "${NOTIFICATIONS_FILE}"

"${AWS_COMMAND[@]}" ce get-anomaly-monitors \
  --output json \
  > "${MONITORS_FILE}"

"${AWS_COMMAND[@]}" ce get-anomaly-subscriptions \
  --output json \
  > "${SUBSCRIPTIONS_FILE}"

"${AWS_COMMAND[@]}" ce get-anomalies \
  --date-interval \
    "StartDate=${CURRENT_MONTH_START},EndDate=${TODAY}" \
  --max-results 100 \
  --output json \
  > "${ANOMALIES_FILE}"

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg current_month_start "${CURRENT_MONTH_START}" \
  --arg anomaly_end "${TODAY}" \
  --slurpfile baseline "${BASELINE_FILE}" \
  --slurpfile tags "${TAG_FILE}" \
  --slurpfile budget "${BUDGET_FILE}" \
  --slurpfile notifications "${NOTIFICATIONS_FILE}" \
  --slurpfile monitors "${MONITORS_FILE}" \
  --slurpfile subscriptions "${SUBSCRIPTIONS_FILE}" \
  --slurpfile anomalies "${ANOMALIES_FILE}" '
    def round2:
      . * 100 | round / 100;

    ($budget[0].Budget) as $budget_data |

    (
      $budget_data.CalculatedSpend.ActualSpend.Amount |
      tonumber
    ) as $actual_spend |

    (
      $budget_data.CalculatedSpend.ForecastedSpend.Amount |
      tonumber
    ) as $forecasted_spend |

    (
      $budget_data.BudgetLimit.Amount |
      tonumber
    ) as $budget_limit |

    {
      generated_at_utc: $generated_at,
      report_scope: {
        project: "baba-app",
        environment: "dev",
        currency: "USD",
        contains_account_id: false,
        contains_subscriber_addresses: false
      },
      cost_baseline: $baseline[0],
      budget: {
        name: $budget_data.BudgetName,
        type: $budget_data.BudgetType,
        period: $budget_data.TimeUnit,
        limit_usd: ($budget_limit | round2),
        actual_spend_usd: ($actual_spend | round2),
        forecasted_spend_usd: ($forecasted_spend | round2),
        actual_utilization_percent:
          (
            ($actual_spend * 100 / $budget_limit) |
            round2
          ),
        forecast_utilization_percent:
          (
            ($forecasted_spend * 100 / $budget_limit) |
            round2
          ),
        exceeded: ($actual_spend > $budget_limit),
        notifications:
          [
            $notifications[0].Notifications[] |
            {
              type: .NotificationType,
              comparison: .ComparisonOperator,
              threshold: .Threshold,
              threshold_type: (.ThresholdType // "PERCENTAGE")
            }
          ] |
          sort_by(.type, .threshold)
      },
      anomaly_detection: {
        period: {
          start_inclusive: $current_month_start,
          end_exclusive: $anomaly_end
        },
        active_monitors:
          [
            $monitors[0].AnomalyMonitors[] |
            {
              name: .MonitorName,
              type: .MonitorType,
              dimension: .MonitorDimension
            }
          ],
        subscriptions:
          [
            $subscriptions[0].AnomalySubscriptions[] |
            {
              name: .SubscriptionName,
              frequency: .Frequency,
              monitor_count: (.MonitorArnList | length),
              subscriber_count: (.Subscribers | length),
              subscriber_types:
                (
                  [.Subscribers[].Type] |
                  unique
                ),
              thresholds:
                [
                  (
                    .ThresholdExpression.And //
                    []
                  )[] |
                  {
                    metric: .Dimensions.Key,
                    operator:
                      (.Dimensions.MatchOptions[0] // "UNKNOWN"),
                    value:
                      (
                        .Dimensions.Values[0] |
                        tonumber
                      )
                  }
                ]
            }
          ],
        detected_anomalies:
          ($anomalies[0].Anomalies | length),
        total_impact_usd:
          (
            [
              $anomalies[0].Anomalies[]
              .Impact.TotalImpact |
              tonumber
            ] |
            add // 0 |
            round2
          ),
        findings:
          (
            [
              $anomalies[0].Anomalies[] |
              {
                start_date: .AnomalyStartDate,
                end_date: .AnomalyEndDate,
                service:
                  (.RootCauses[0].Service // "Unknown"),
                total_impact_usd:
                  (
                    .Impact.TotalImpact |
                    tonumber |
                    round2
                  )
              }
            ] |
            sort_by(.total_impact_usd) |
            reverse
          )
      },
      tag_compliance: {
        discovered_resources:
          $tags[0].discovered_resources,
        pending_deletion_exceptions:
          $tags[0].pending_deletion_exceptions,
        in_scope_resources:
          $tags[0].in_scope_resources,
        compliant_resources:
          $tags[0].compliant_resources,
        noncompliant_resources:
          $tags[0].noncompliant_resources,
        compliance_percent:
          $tags[0].compliance_percent,
        exceptions_by_reason:
          (
            $tags[0].exceptions |
            sort_by(.reason) |
            group_by(.reason) |
            map({
              reason: .[0].reason,
              count: length
            })
          )
      },
      optimization_actions: [
        {
          action:
            "Destroy development EKS runtime when not in use",
          status: "implemented",
          approval:
            "Human-approved Phase 7 lifecycle workflow",
          savings_status:
            "Pending verification after Cost Explorer data matures"
        },
        {
          action:
            "Review persistent NAT Gateway hourly cost",
          status: "open",
          approval:
            "Required before infrastructure modification",
          savings_status:
            "Not yet estimated"
        },
        {
          action:
            "Retain CloudTrail, encryption, and audit logging",
          status: "retained",
          approval:
            "Security controls are not removed solely for savings",
          savings_status:
            "Not applicable"
        }
      ],
      savings: {
        verified_monthly_savings_usd: null,
        status:
          "Pending a complete post-EKS-destruction comparison period"
      }
    }
  ' > "${REPORT_FILE}"

if [[ -n "${OUTPUT_FILE}" ]]; then
  cp "${REPORT_FILE}" "${OUTPUT_FILE}"
fi

cat "${REPORT_FILE}"