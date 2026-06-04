#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd az kubectl

echo "Fetching credentials for AKS cluster: ${AKS_CLUSTER_NAME} (${AKS_RESOURCE_GROUP})"
az aks get-credentials \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --overwrite-existing

kubectl config use-context "$AKS_CLUSTER_NAME"
echo "kubectl context: $(kubectl config current-context)"
