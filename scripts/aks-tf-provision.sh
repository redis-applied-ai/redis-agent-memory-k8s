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

# Azure OpenAI deployment knobs — all optional; Terraform has sensible defaults.
[[ -n "${AOAI_ACCOUNT_NAME:-}" ]]              && export TF_VAR_openai_account_name="$AOAI_ACCOUNT_NAME"
[[ -n "${AOAI_LOCATION:-}" ]]                  && export TF_VAR_openai_location="$AOAI_LOCATION"
[[ -n "${AOAI_SKU_NAME:-}" ]]                  && export TF_VAR_openai_sku_name="$AOAI_SKU_NAME"
[[ -n "${AOAI_CHAT_DEPLOYMENT_NAME:-}" ]]      && export TF_VAR_openai_chat_deployment_name="$AOAI_CHAT_DEPLOYMENT_NAME"
[[ -n "${AOAI_CHAT_MODEL:-}" ]]                && export TF_VAR_openai_chat_model="$AOAI_CHAT_MODEL"
[[ -n "${AOAI_CHAT_MODEL_VERSION:-}" ]]        && export TF_VAR_openai_chat_model_version="$AOAI_CHAT_MODEL_VERSION"
[[ -n "${AOAI_CHAT_SKU_NAME:-}" ]]             && export TF_VAR_openai_chat_sku_name="$AOAI_CHAT_SKU_NAME"
[[ -n "${AOAI_CHAT_SKU_CAPACITY:-}" ]]         && export TF_VAR_openai_chat_sku_capacity="$AOAI_CHAT_SKU_CAPACITY"
[[ -n "${AOAI_EMBEDDING_DEPLOYMENT_NAME:-}" ]] && export TF_VAR_openai_embedding_deployment_name="$AOAI_EMBEDDING_DEPLOYMENT_NAME"
[[ -n "${AOAI_EMBEDDING_MODEL:-}" ]]           && export TF_VAR_openai_embedding_model="$AOAI_EMBEDDING_MODEL"
[[ -n "${AOAI_EMBEDDING_MODEL_VERSION:-}" ]]   && export TF_VAR_openai_embedding_model_version="$AOAI_EMBEDDING_MODEL_VERSION"
[[ -n "${AOAI_EMBEDDING_SKU_NAME:-}" ]]        && export TF_VAR_openai_embedding_sku_name="$AOAI_EMBEDDING_SKU_NAME"
[[ -n "${AOAI_EMBEDDING_SKU_CAPACITY:-}" ]]    && export TF_VAR_openai_embedding_sku_capacity="$AOAI_EMBEDDING_SKU_CAPACITY"

# Workload identity wiring for the RAM ServiceAccount.
[[ -n "${RAM_IDENTITY_NAME:-}" ]]              && export TF_VAR_ram_identity_name="$RAM_IDENTITY_NAME"
[[ -n "${RAM_NAMESPACE:-}" ]]                  && export TF_VAR_ram_namespace="$RAM_NAMESPACE"
[[ -n "${RAM_SERVICE_ACCOUNT_NAME:-}" ]]       && export TF_VAR_ram_service_account_name="$RAM_SERVICE_ACCOUNT_NAME"

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
