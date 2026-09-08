
#!/usr/bin/env bash

set -euo pipefail

# Validates that the Baba App EKS cluster is ACTIVE and that all worker nodes
# registered with the cluster report Ready.

CLUSTER_NAME="${1:-baba-app-dev-eks}"
AWS_REGION="${2:-us-east-1}"

STATUS=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.status' \
  --output text)

if [[ "${STATUS}" != "ACTIVE" ]]; then
  echo "EKS cluster is not ACTIVE: ${STATUS}"
  exit 1
fi

aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}"

kubectl wait \
  --for=condition=Ready \
  nodes \
  --all \
  --timeout=10m

kubectl get nodes -o wide