#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd terraform

if [[ -z "${AKS_ADMIN_SSH_PUBLIC_KEY:-}" ]]; then
  echo "Error: AKS_ADMIN_SSH_PUBLIC_KEY is not set." >&2
  echo "Set it in .env to the contents of your SSH public key (e.g. ~/.ssh/id_ed25519.pub)." >&2
  exit 1
fi

export TF_VAR_cluster_name="$AKS_CLUSTER_NAME"
export TF_VAR_resource_group_name="$AKS_RESOURCE_GROUP"
export TF_VAR_location="$AKS_LOCATION"
export TF_VAR_system_node_vm_size="$AKS_SYSTEM_NODE_VM_SIZE"
export TF_VAR_system_node_count="$AKS_SYSTEM_NODE_COUNT"
export TF_VAR_user_node_vm_size="$AKS_USER_NODE_VM_SIZE"
export TF_VAR_user_node_count="$AKS_USER_NODE_COUNT"
export TF_VAR_admin_ssh_public_key="$AKS_ADMIN_SSH_PUBLIC_KEY"
export TF_VAR_admin_username="${AKS_ADMIN_USERNAME:-azureuser}"
export TF_VAR_loadtest_vm_size="${AKS_LOADTEST_VM_SIZE:-Standard_D4_v5}"

WHAT_IF="false"
SKIP_INIT="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --what-if)    WHAT_IF="true";    shift ;;
    --skip-init)  SKIP_INIT="true";  shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

TF_DIR="${RAM_ROOT}/infra/terraform"
BACKEND_HCL="${TF_DIR}/backend.hcl"
cd "$TF_DIR"

BACKEND_ARGS=()
if [[ -f "$BACKEND_HCL" ]]; then
  BACKEND_ARGS+=("-backend-config=${BACKEND_HCL}")
fi

if [[ "$WHAT_IF" == "true" ]]; then
  echo "Dry-run: planning Terraform deployment for AKS cluster: ${AKS_CLUSTER_NAME}"
  if [[ "$SKIP_INIT" != "true" ]]; then
    terraform init "${BACKEND_ARGS[@]}"
  fi
  terraform plan
  exit 0
fi

echo "Deploying AKS cluster via Terraform: ${AKS_CLUSTER_NAME}"
if [[ "$SKIP_INIT" != "true" ]]; then
  terraform init "${BACKEND_ARGS[@]}"
fi
terraform apply -auto-approve
echo "AKS cluster provisioned: ${AKS_CLUSTER_NAME}"
