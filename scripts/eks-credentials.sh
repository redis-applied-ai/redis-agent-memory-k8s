#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd aws kubectl

echo "Fetching credentials for EKS cluster: ${EKS_CLUSTER_NAME} (${EKS_AWS_REGION})"
aws eks update-kubeconfig \
  --region "$EKS_AWS_REGION" \
  --name "$EKS_CLUSTER_NAME"

echo "kubectl context: $(kubectl config current-context)"
