#!/usr/bin/env bash

set -euo pipefail

# Confirms that the EKS module is absent from Terraform state after destruction.

TF_DIR="${1:-03-terraform/environments/dev}"

if terraform \
  -chdir="${TF_DIR}" \
  state list | grep -q '^module\.eks'; then
  echo "EKS resources remain in Terraform state."
  exit 1
fi

echo "No module.eks resources remain in Terraform state."