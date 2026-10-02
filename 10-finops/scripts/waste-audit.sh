#!/usr/bin/env bash

set -euo pipefail

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
SNAPSHOT_AGE_DAYS="${SNAPSHOT_AGE_DAYS:-90}"

for command in aws jq mktemp; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${command}" >&2
    exit 1
  fi
done

if ! [[ "${SNAPSHOT_AGE_DAYS}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: SNAPSHOT_AGE_DAYS must be a nonnegative integer." >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

aws ec2 describe-instances \
  --region "${REGION}" \
  --output json \
  > "${TEMP_DIR}/instances.json"

aws ec2 describe-volumes \
  --region "${REGION}" \
  --filters Name=status,Values=available \
  --output json \
  > "${TEMP_DIR}/volumes.json"

aws ec2 describe-snapshots \
  --region "${REGION}" \
  --owner-ids self \
  --output json \
  > "${TEMP_DIR}/snapshots.json"

aws ec2 describe-addresses \
  --region "${REGION}" \
  --output json \
  > "${TEMP_DIR}/addresses.json"

aws ec2 describe-nat-gateways \
  --region "${REGION}" \
  --filter Name=state,Values=pending,available \
  --output json \
  > "${TEMP_DIR}/nat-gateways.json"

aws elbv2 describe-load-balancers \
  --region "${REGION}" \
  --output json \
  > "${TEMP_DIR}/elbv2.json"

aws elb describe-load-balancers \
  --region "${REGION}" \
  --output json \
  > "${TEMP_DIR}/elb-classic.json"

aws rds describe-db-instances \
  --region "${REGION}" \
  --output json \
  > "${TEMP_DIR}/rds.json"

aws eks list-clusters \
  --region "${REGION}" \
  --output json \
  > "${TEMP_DIR}/eks.json"

aws ecr describe-repositories \
  --region "${REGION}" \
  --output json \
  > "${TEMP_DIR}/ecr-repositories.json"

: > "${TEMP_DIR}/ecr-summary.ndjson"

while IFS= read -r repository; do
  aws ecr describe-images \
    --region "${REGION}" \
    --repository-name "${repository}" \
    --output json |
  jq -c --arg repository "${repository}" '
    {
      repository: $repository,
      total_records: (.imageDetails | length),
      tagged_records:
        (
          [
            .imageDetails[]
            | select((.imageTags // []) | length > 0)
          ]
          | length
        ),
      untagged_records:
        (
          [
            .imageDetails[]
            | select((.imageTags // []) | length == 0)
          ]
          | length
        ),
      deployable_images:
        (
          [
            .imageDetails[]
            | select(
                .artifactMediaType ==
                  "application/vnd.docker.container.image.v1+json"
                or
                .artifactMediaType ==
                  "application/vnd.oci.image.config.v1+json"
                or
                .imageManifestMediaType ==
                  "application/vnd.oci.image.index.v1+json"
              )
          ]
          | length
        ),
      supply_chain_artifacts:
        (
          [
            .imageDetails[]
            | select(
                (.artifactMediaType // "")
                | test("attestation|sigstore")
              )
          ]
          | length
        ),
      stored_mib:
        (
          [.imageDetails[].imageSizeInBytes // 0]
          | add // 0
          | . / 1048576
          | . * 100
          | round / 100
        )
    }
  ' >> "${TEMP_DIR}/ecr-summary.ndjson"
done < <(
  jq -r '.repositories[].repositoryName' \
    "${TEMP_DIR}/ecr-repositories.json"
)

jq -s '.' \
  "${TEMP_DIR}/ecr-summary.ndjson" \
  > "${TEMP_DIR}/ecr-summary.json"

GENERATED_AT_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

jq -n \
  --arg generated_at "${GENERATED_AT_UTC}" \
  --arg region "${REGION}" \
  --argjson snapshot_age_days "${SNAPSHOT_AGE_DAYS}" \
  --slurpfile instances "${TEMP_DIR}/instances.json" \
  --slurpfile volumes "${TEMP_DIR}/volumes.json" \
  --slurpfile snapshots "${TEMP_DIR}/snapshots.json" \
  --slurpfile addresses "${TEMP_DIR}/addresses.json" \
  --slurpfile nat "${TEMP_DIR}/nat-gateways.json" \
  --slurpfile elbv2 "${TEMP_DIR}/elbv2.json" \
  --slurpfile classic "${TEMP_DIR}/elb-classic.json" \
  --slurpfile rds "${TEMP_DIR}/rds.json" \
  --slurpfile eks "${TEMP_DIR}/eks.json" \
  --slurpfile ecr "${TEMP_DIR}/ecr-summary.json" '
  def tag_value($tags; $key):
    (
      $tags // []
      | map(select(.Key == $key))
      | .[0].Value
    ) // null;

  def aws_epoch:
    sub("\\.[0-9]+\\+00:00$"; "Z")
    | sub("\\.[0-9]+Z$"; "Z")
    | sub("\\+00:00$"; "Z")
    | try fromdateiso8601 catch 0;

  (
    [
      $instances[0].Reservations[].Instances[]
      | select(.State.Name == "stopped")
      | {
          instance_id: .InstanceId,
          instance_type: .InstanceType,
          state: .State.Name,
          name: tag_value(.Tags; "Name"),
          project: tag_value(.Tags; "Project")
        }
    ]
  ) as $stopped_instances |

  (
    [
      $volumes[0].Volumes[]
      | {
          volume_id: .VolumeId,
          size_gib: .Size,
          volume_type: .VolumeType,
          created_at: .CreateTime,
          name: tag_value(.Tags; "Name"),
          project: tag_value(.Tags; "Project")
        }
    ]
  ) as $unattached_volumes |

  (
    [
      $snapshots[0].Snapshots[]
      | select(
          (now - (.StartTime | aws_epoch))
          >= ($snapshot_age_days * 86400)
        )
      | {
          snapshot_id: .SnapshotId,
          size_gib: .VolumeSize,
          started_at: .StartTime,
          description: .Description
        }
    ]
  ) as $old_snapshots |

  (
    [
      $addresses[0].Addresses[]
      | select(
          .AssociationId == null
          and .NetworkInterfaceId == null
          and .InstanceId == null
        )
      | {
          allocation_id: .AllocationId,
          public_ip: .PublicIp,
          name: tag_value(.Tags; "Name"),
          project: tag_value(.Tags; "Project")
        }
    ]
  ) as $idle_elastic_ips |

  (
    [
      $nat[0].NatGateways[]
      | {
          nat_gateway_id: .NatGatewayId,
          state: .State,
          vpc_id: .VpcId,
          subnet_id: .SubnetId,
          public_ip: (.NatGatewayAddresses[0].PublicIp // null),
          name: tag_value(.Tags; "Name"),
          project: tag_value(.Tags; "Project")
        }
    ]
  ) as $active_nat_gateways |

  (
    [
      $elbv2[0].LoadBalancers[]
      | {
          name: .LoadBalancerName,
          type: .Type,
          scheme: .Scheme,
          state: .State.Code,
          vpc_id: .VpcId
        }
    ]
  ) as $modern_load_balancers |

  (
    [
      $classic[0].LoadBalancerDescriptions[]
      | {
          name: .LoadBalancerName,
          scheme: .Scheme,
          vpc_id: .VPCId,
          registered_instances: (.Instances | length)
        }
    ]
  ) as $classic_load_balancers |

  (
    [
      $rds[0].DBInstances[]
      | {
          identifier: .DBInstanceIdentifier,
          status: .DBInstanceStatus,
          engine: .Engine,
          instance_class: .DBInstanceClass,
          storage_gib: .AllocatedStorage
        }
    ]
  ) as $database_instances |

  ($eks[0].clusters // []) as $eks_clusters |

  (
    ($stopped_instances | length)
    + ($unattached_volumes | length)
    + ($old_snapshots | length)
    + ($idle_elastic_ips | length)
    + ($active_nat_gateways | length)
    + ($modern_load_balancers | length)
    + ($classic_load_balancers | length)
    + ($database_instances | length)
    + ($eks_clusters | length)
  ) as $review_count |

  {
    generated_at_utc: $generated_at,
    region: $region,
    snapshot_age_threshold_days: $snapshot_age_days,
    status:
      (
        if $review_count == 0
        then "PASS"
        else "REVIEW_REQUIRED"
        end
      ),
    summary: {
      review_findings: $review_count,
      stopped_instances: ($stopped_instances | length),
      unattached_volumes: ($unattached_volumes | length),
      old_snapshots: ($old_snapshots | length),
      idle_elastic_ips: ($idle_elastic_ips | length),
      active_nat_gateways: ($active_nat_gateways | length),
      modern_load_balancers: ($modern_load_balancers | length),
      classic_load_balancers: ($classic_load_balancers | length),
      database_instances: ($database_instances | length),
      eks_clusters: ($eks_clusters | length),
      ecr_repositories: ($ecr[0] | length)
    },
    findings: {
      stopped_instances: $stopped_instances,
      unattached_volumes: $unattached_volumes,
      old_snapshots: $old_snapshots,
      idle_elastic_ips: $idle_elastic_ips,
      active_nat_gateways: $active_nat_gateways,
      modern_load_balancers: $modern_load_balancers,
      classic_load_balancers: $classic_load_balancers,
      database_instances: $database_instances,
      eks_clusters: $eks_clusters
    },
    ecr_inventory: $ecr[0],
    notes: [
      "This report is read-only and does not delete resources.",
      "Every finding requires ownership and dependency validation before remediation.",
      "Untagged ECR records can be referenced platform manifests, attestations, or signatures and are not automatically classified as waste."
    ]
  }
'