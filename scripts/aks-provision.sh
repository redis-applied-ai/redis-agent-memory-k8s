#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd az
ram_require_file "$AKS_BICEP_TEMPLATE" "Bicep template not found"

WHAT_IF="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --what-if) WHAT_IF="true"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# If the resource group already exists in a different location, fail fast with a clear message
# rather than letting Azure return a cryptic InvalidResourceGroupLocation error.
existing_location="$(az group show --name "$AKS_RESOURCE_GROUP" --query location -o tsv 2>/dev/null || true)"
if [[ -n "$existing_location" && "$existing_location" != "$AKS_LOCATION" ]]; then
  echo "Error: resource group '${AKS_RESOURCE_GROUP}' already exists in '${existing_location}'" \
       "but AKS_LOCATION is set to '${AKS_LOCATION}'." >&2
  echo "Either:" >&2
  echo "  - Delete it: az group delete --name ${AKS_RESOURCE_GROUP} --yes" >&2
  echo "  - Or match the location in .env: AKS_LOCATION=${existing_location}" >&2
  exit 1
fi

echo "Creating resource group: ${AKS_RESOURCE_GROUP} (${AKS_LOCATION})"
az group create \
  --name "$AKS_RESOURCE_GROUP" \
  --location "$AKS_LOCATION" \
  --output table

DEPLOY_ARGS=(
  --resource-group "$AKS_RESOURCE_GROUP"
  --template-file "$AKS_BICEP_TEMPLATE"
  --parameters
    clusterName="$AKS_CLUSTER_NAME"
    systemNodeVmSize="$AKS_SYSTEM_NODE_VM_SIZE"
    systemNodeCount="$AKS_SYSTEM_NODE_COUNT"
    userNodeVmSize="$AKS_USER_NODE_VM_SIZE"
    userNodeCount="$AKS_USER_NODE_COUNT"
)

if [[ "$WHAT_IF" == "true" ]]; then
  echo "Dry-run: what-if deployment for AKS cluster: ${AKS_CLUSTER_NAME}"
  az deployment group create "${DEPLOY_ARGS[@]}" --what-if
else
  echo "Deploying AKS cluster: ${AKS_CLUSTER_NAME}"
  az deployment group create "${DEPLOY_ARGS[@]}" --output table
  echo "AKS cluster provisioned: ${AKS_CLUSTER_NAME}"
fi
