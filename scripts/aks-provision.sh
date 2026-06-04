#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd az
ram_require_file "$AKS_BICEP_TEMPLATE" "Bicep template not found"

if [[ -z "${AKS_ADMIN_SSH_PUBLIC_KEY:-}" ]]; then
  echo "Error: AKS_ADMIN_SSH_PUBLIC_KEY is not set." >&2
  echo "Set it in .env to the contents of your SSH public key (e.g. ~/.ssh/id_ed25519.pub)." >&2
  exit 1
fi

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
    adminSshPublicKey="$AKS_ADMIN_SSH_PUBLIC_KEY"
    adminUsername="${AKS_ADMIN_USERNAME:-azureuser}"
    loadtestVmSize="${AKS_LOADTEST_VM_SIZE:-Standard_D4_v5}"
)

if [[ "$WHAT_IF" == "true" ]]; then
  echo "Dry-run: what-if deployment for AKS cluster: ${AKS_CLUSTER_NAME}"
  az deployment group create "${DEPLOY_ARGS[@]}" --what-if
  exit 0
fi

echo "Deploying AKS cluster: ${AKS_CLUSTER_NAME}"
az deployment group create "${DEPLOY_ARGS[@]}" --output table
echo "AKS cluster provisioned: ${AKS_CLUSTER_NAME}"

# Peer the load test VNet with the AKS node VNet so the VM can reach the internal load balancer.
# AKS creates its own VNet in the MC_ resource group; we peer both directions.
LOADTEST_VNET="${AKS_CLUSTER_NAME}-vnet"
LOADTEST_VNET_ID="$(az network vnet show \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --name "$LOADTEST_VNET" \
  --query id -o tsv)"

MC_RG="$(az aks show \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --query nodeResourceGroup -o tsv)"

AKS_VNET_NAME="$(az network vnet list \
  --resource-group "$MC_RG" \
  --query '[0].name' -o tsv)"

AKS_VNET_ID="$(az network vnet show \
  --resource-group "$MC_RG" \
  --name "$AKS_VNET_NAME" \
  --query id -o tsv)"

echo "Peering ${LOADTEST_VNET} ↔ ${AKS_VNET_NAME}..."

if ! az network vnet peering show \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --vnet-name "$LOADTEST_VNET" \
  --name "loadtest-to-aks" >/dev/null 2>&1; then
  az network vnet peering create \
    --name "loadtest-to-aks" \
    --resource-group "$AKS_RESOURCE_GROUP" \
    --vnet-name "$LOADTEST_VNET" \
    --remote-vnet "$AKS_VNET_ID" \
    --allow-vnet-access \
    --output none
  echo "  loadtest → aks: created"
else
  echo "  loadtest → aks: already exists"
fi

if ! az network vnet peering show \
  --resource-group "$MC_RG" \
  --vnet-name "$AKS_VNET_NAME" \
  --name "aks-to-loadtest" >/dev/null 2>&1; then
  az network vnet peering create \
    --name "aks-to-loadtest" \
    --resource-group "$MC_RG" \
    --vnet-name "$AKS_VNET_NAME" \
    --remote-vnet "$LOADTEST_VNET_ID" \
    --allow-vnet-access \
    --output none
  echo "  aks → loadtest: created"
else
  echo "  aks → loadtest: already exists"
fi

echo "VNet peering complete."
