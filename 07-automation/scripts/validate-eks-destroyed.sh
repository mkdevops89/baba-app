#!/usr/bin/env bash

set -euo pipefail

# Confirms that the Baba App development EKS cluster no longer exists.

CLUSTER_NAME="${1:-baba-app-dev-eks}"
AWS_REGION="${2:-us-east-1}"

if aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  >/dev/null 2>&1; then
  echo "EKS cluster still exists."
  exit 1
fi

echo "EKS cluster is absent."