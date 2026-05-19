#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd terraform

export TF_VAR_cluster_name="$AKS_CLUSTER_NAME"
export TF_VAR_resource_group_name="$AKS_RESOURCE_GROUP"
export TF_VAR_location="$AKS_LOCATION"
export TF_VAR_system_node_vm_size="$AKS_SYSTEM_NODE_VM_SIZE"
export TF_VAR_system_node_count="$AKS_SYSTEM_NODE_COUNT"
export TF_VAR_user_node_vm_size="$AKS_USER_NODE_VM_SIZE"
export TF_VAR_user_node_count="$AKS_USER_NODE_COUNT"
export TF_VAR_admin_ssh_public_key="${AKS_ADMIN_SSH_PUBLIC_KEY:-}"
export TF_VAR_admin_username="${AKS_ADMIN_USERNAME:-azureuser}"
export TF_VAR_loadtest_vm_size="${AKS_LOADTEST_VM_SIZE:-Standard_D4_v5}"

TF_DIR="${RAM_ROOT}/infra/terraform"
cd "$TF_DIR"

echo "Destroying AKS cluster via Terraform: ${AKS_CLUSTER_NAME}"
echo "This will destroy the AKS cluster and all associated Azure resources."
terraform destroy -auto-approve
echo "Terraform destroy complete for cluster: ${AKS_CLUSTER_NAME}"
