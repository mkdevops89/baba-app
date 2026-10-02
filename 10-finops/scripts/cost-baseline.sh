#!/usr/bin/env bash

set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-baba-admin}"
AWS_REGION_NAME="${AWS_REGION:-us-east-1}"

command -v aws >/dev/null 2>&1 || {
  echo "ERROR: aws CLI is required." >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required." >&2
  exit 1
}

macos_date() {
  date -u -v-30d +%F >/dev/null 2>&1
}

if macos_date; then
  DEFAULT_START="$(date -u -v-30d +%F)"
  TODAY="$(date -u +%F)"
  CURRENT_MONTH_START="$(date -u -v1d +%F)"
  NEXT_MONTH_START="$(date -u -v1d -v+1m +%F)"
else
  DEFAULT_START="$(date -u -d '30 days ago' +%F)"
  TODAY="$(date -u +%F)"
  CURRENT_MONTH_START="$(date -u +%Y-%m-01)"
  NEXT_MONTH_START="$(
    date -u -d "${CURRENT_MONTH_START} +1 month" +%F
  )"
fi

START_DATE="${START_DATE:-${DEFAULT_START}}"
END_DATE="${END_DATE:-${TODAY}}"

if [[ ! "${START_DATE}" < "${END_DATE}" ]]; then
  echo "ERROR: START_DATE must be earlier than END_DATE." >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TEMP_DIR}"
}

trap cleanup EXIT

DAILY_FILE="${TEMP_DIR}/daily.json"
SERVICES_FILE="${TEMP_DIR}/services.json"
EC2_OTHER_FILE="${TEMP_DIR}/ec2-other.json"
VPC_FILE="${TEMP_DIR}/vpc.json"
CURRENT_ACTUAL_FILE="${TEMP_DIR}/current-actual.json"
FORECAST_FILE="${TEMP_DIR}/forecast.json"

AWS_COMMAND=(
  aws
  --profile "${AWS_PROFILE_NAME}"
  --region "${AWS_REGION_NAME}"
)

"${AWS_COMMAND[@]}" ce get-cost-and-usage \
  --time-period "Start=${START_DATE},End=${END_DATE}" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --output json \
  > "${DAILY_FILE}"

"${AWS_COMMAND[@]}" ce get-cost-and-usage \
  --time-period "Start=${START_DATE},End=${END_DATE}" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json \
  > "${SERVICES_FILE}"

"${AWS_COMMAND[@]}" ce get-cost-and-usage \
  --time-period "Start=${START_DATE},End=${END_DATE}" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["EC2 - Other"]}}' \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --output json \
  > "${EC2_OTHER_FILE}"

"${AWS_COMMAND[@]}" ce get-cost-and-usage \
  --time-period "Start=${START_DATE},End=${END_DATE}" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Virtual Private Cloud"]}}' \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --output json \
  > "${VPC_FILE}"

if [[ "${CURRENT_MONTH_START}" == "${TODAY}" ]]; then
  jq -n '
    {
      ResultsByTime: [
        {
          Total: {
            UnblendedCost: {
              Amount: "0",
              Unit: "USD"
            }
          }
        }
      ]
    }
  ' > "${CURRENT_ACTUAL_FILE}"
else
  "${AWS_COMMAND[@]}" ce get-cost-and-usage \
    --time-period "Start=${CURRENT_MONTH_START},End=${TODAY}" \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --output json \
    > "${CURRENT_ACTUAL_FILE}"
fi

if ! "${AWS_COMMAND[@]}" ce get-cost-forecast \
  --time-period "Start=${TODAY},End=${NEXT_MONTH_START}" \
  --metric UNBLENDED_COST \
  --granularity DAILY \
  --output json \
  > "${FORECAST_FILE}"
then
  jq -n '
    {
      Total: {
        Amount: "0",
        Unit: "USD"
      },
      ForecastResultsByTime: []
    }
  ' > "${FORECAST_FILE}"
fi

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg start_date "${START_DATE}" \
  --arg end_date "${END_DATE}" \
  --arg current_month_start "${CURRENT_MONTH_START}" \
  --arg forecast_start "${TODAY}" \
  --arg next_month_start "${NEXT_MONTH_START}" \
  --slurpfile daily "${DAILY_FILE}" \
  --slurpfile services "${SERVICES_FILE}" \
  --slurpfile ec2_other "${EC2_OTHER_FILE}" \
  --slurpfile vpc "${VPC_FILE}" \
  --slurpfile actual "${CURRENT_ACTUAL_FILE}" \
  --slurpfile forecast "${FORECAST_FILE}" '
    def round2:
      . * 100 | round / 100;

    def aggregate_services:
      [
        $services[0].ResultsByTime[].Groups[] |
        {
          service: .Keys[0],
          amount: (.Metrics.UnblendedCost.Amount | tonumber)
        }
      ] |
      sort_by(.service) |
      group_by(.service) |
      map({
        service: .[0].service,
        amount_usd: (map(.amount) | add | round2)
      });

    def aggregate_usage($document):
      [
        $document[0].ResultsByTime[].Groups[] |
        {
          usage_type: .Keys[0],
          amount: (.Metrics.UnblendedCost.Amount | tonumber)
        }
      ] |
      sort_by(.usage_type) |
      group_by(.usage_type) |
      map({
        usage_type: .[0].usage_type,
        amount_usd: (map(.amount) | add | round2)
      });

    aggregate_services as $service_costs |
    aggregate_usage($ec2_other) as $ec2_usage |
    aggregate_usage($vpc) as $vpc_usage |

    (
      $actual[0].ResultsByTime[0]
      .Total.UnblendedCost.Amount |
      tonumber
    ) as $current_actual |

    (
      $forecast[0].Total.Amount |
      tonumber
    ) as $remaining_forecast |

    {
      generated_at_utc: $generated_at,
      metric: "UnblendedCost",
      currency: "USD",
      baseline_period: {
        start_inclusive: $start_date,
        end_exclusive: $end_date,
        total_cost_usd:
          (
            [
              $daily[0].ResultsByTime[]
              .Total.UnblendedCost.Amount |
              tonumber
            ] |
            add |
            round2
          )
      },
      top_five_services:
        (
          $service_costs |
          map(select(.service != "Tax" and .amount_usd > 0)) |
          sort_by(.amount_usd) |
          reverse |
          .[:5]
        ),
      cost_by_service:
        (
          $service_costs |
          sort_by(.amount_usd) |
          reverse
        ),
      daily_costs:
        [
          $daily[0].ResultsByTime[] |
          {
            date: .TimePeriod.Start,
            amount_usd:
              (
                .Total.UnblendedCost.Amount |
                tonumber |
                round2
              )
          }
        ],
      key_cost_centers: {
        eks_usd:
          (
            [
              $service_costs[] |
              select(
                .service ==
                "Amazon Elastic Container Service for Kubernetes"
              ) |
              .amount_usd
            ] |
            add // 0
          ),
        ec2_compute_usd:
          (
            [
              $service_costs[] |
              select(
                .service ==
                "Amazon Elastic Compute Cloud - Compute"
              ) |
              .amount_usd
            ] |
            add // 0
          ),
        ec2_other_usd:
          (
            [
              $service_costs[] |
              select(.service == "EC2 - Other") |
              .amount_usd
            ] |
            add // 0
          ),
        ebs_usd:
          (
            [
              $ec2_usage[] |
              select(.usage_type | contains("EBS")) |
              .amount_usd
            ] |
            add // 0 |
            round2
          ),
        nat_gateway_usd:
          (
            [
              $ec2_usage[] |
              select(.usage_type | contains("NatGateway")) |
              .amount_usd
            ] |
            add // 0 |
            round2
          ),
        cloudwatch_usd:
          (
            [
              $service_costs[] |
              select(.service == "AmazonCloudWatch") |
              .amount_usd
            ] |
            add // 0
          ),
        kms_usd:
          (
            [
              $service_costs[] |
              select(.service == "AWS Key Management Service") |
              .amount_usd
            ] |
            add // 0
          ),
        s3_usd:
          (
            [
              $service_costs[] |
              select(.service == "Amazon Simple Storage Service") |
              .amount_usd
            ] |
            add // 0
          ),
        public_ipv4_usd:
          (
            [
              $vpc_usage[] |
              select(.usage_type | contains("PublicIPv4")) |
              .amount_usd
            ] |
            add // 0 |
            round2
          )
      },
      current_month_projection: {
        month_start: $current_month_start,
        actual_end_exclusive: $forecast_start,
        actual_cost_usd: ($current_actual | round2),
        forecast_start_inclusive: $forecast_start,
        forecast_end_exclusive: $next_month_start,
        remaining_forecast_usd: ($remaining_forecast | round2),
        projected_month_total_usd:
          (
            ($current_actual + $remaining_forecast) |
            round2
          ),
        forecast_granularity: "DAILY"
      }
    }
  '