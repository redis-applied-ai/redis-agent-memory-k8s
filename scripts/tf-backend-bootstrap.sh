#!/usr/bin/env bash
# Creates the Azure Blob Storage backend for Terraform state.
# Run once per team — not idempotent on the storage account name.
# Writes infra/terraform/backend.hcl and prints the ARM_ACCESS_KEY to add to .env.
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd az

TFSTATE_RG="${TFSTATE_RESOURCE_GROUP:-ram-tfstate-rg}"
TFSTATE_LOCATION="${AKS_LOCATION:-eastus}"
TFSTATE_STORAGE_ACCOUNT="${TFSTATE_STORAGE_ACCOUNT:-ramtfstate$RANDOM}"
TFSTATE_CONTAINER="${TFSTATE_CONTAINER:-tfstate}"
TFSTATE_KEY="${TFSTATE_KEY:-redis-agent-memory-k8s.tfstate}"

BACKEND_HCL="${RAM_ROOT}/infra/terraform/backend.hcl"

echo "Creating Terraform state resource group: ${TFSTATE_RG} (${TFSTATE_LOCATION})"
az group create --name "$TFSTATE_RG" --location "$TFSTATE_LOCATION" --output none

# Storage account names must be globally unique, lowercase, 3-24 chars.
TFSTATE_STORAGE_ACCOUNT="$(echo "$TFSTATE_STORAGE_ACCOUNT" | tr '[:upper:]' '[:lower:]')"
echo "Creating storage account: ${TFSTATE_STORAGE_ACCOUNT}"
az storage account create \
  --name "$TFSTATE_STORAGE_ACCOUNT" \
  --resource-group "$TFSTATE_RG" \
  --location "$TFSTATE_LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --output none

echo "Enabling blob versioning (soft delete for state recovery)"
az storage account blob-service-properties update \
  --account-name "$TFSTATE_STORAGE_ACCOUNT" \
  --resource-group "$TFSTATE_RG" \
  --enable-versioning true \
  --output none

echo "Creating blob container: ${TFSTATE_CONTAINER}"
az storage container create \
  --name "$TFSTATE_CONTAINER" \
  --account-name "$TFSTATE_STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none

ARM_ACCESS_KEY="$(az storage account keys list \
  --account-name "$TFSTATE_STORAGE_ACCOUNT" \
  --resource-group "$TFSTATE_RG" \
  --query '[0].value' -o tsv)"

cat > "$BACKEND_HCL" <<EOF
resource_group_name  = "${TFSTATE_RG}"
storage_account_name = "${TFSTATE_STORAGE_ACCOUNT}"
container_name       = "${TFSTATE_CONTAINER}"
key                  = "${TFSTATE_KEY}"
EOF

echo ""
echo "backend.hcl written to: ${BACKEND_HCL}"
echo ""
echo "Add the following to your .env file:"
echo ""
echo "  ARM_ACCESS_KEY=${ARM_ACCESS_KEY}"
echo ""
echo "Then run 'terraform init -migrate-state' to move any existing local state to Azure:"
echo ""
echo "  cd ${RAM_ROOT}/infra/terraform"
echo "  terraform init -backend-config=backend.hcl -migrate-state"
