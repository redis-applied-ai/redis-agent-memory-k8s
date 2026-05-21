#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd az

echo "Deleting resource group: ${AKS_RESOURCE_GROUP}"
echo "This will destroy the AKS cluster and all associated Azure resources."
az group delete \
  --name "$AKS_RESOURCE_GROUP" \
  --yes \
  --no-wait

echo "Deletion of ${AKS_RESOURCE_GROUP} initiated (async)."
echo "Check progress: az group show --name ${AKS_RESOURCE_GROUP} --query properties.provisioningState -o tsv"
