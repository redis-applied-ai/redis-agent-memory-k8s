#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd terraform aws

# EKS cluster knobs.
export TF_VAR_aws_region="$EKS_AWS_REGION"
export TF_VAR_cluster_name="$EKS_CLUSTER_NAME"
export TF_VAR_kubernetes_version="$EKS_KUBERNETES_VERSION"
export TF_VAR_node_instance_type="$EKS_NODE_INSTANCE_TYPE"
export TF_VAR_node_count="$EKS_NODE_COUNT"

# Azure cross-cloud federation — point at the EXISTING UAMI created by the AKS
# deployment (ENV=aks-tf). This module only reads it and adds an EKS federated
# credential; it never recreates the UAMI or AOAI.
export TF_VAR_azure_resource_group="$AZURE_RESOURCE_GROUP"
[[ -n "${RAM_IDENTITY_NAME:-}" ]]        && export TF_VAR_ram_identity_name="$RAM_IDENTITY_NAME"
[[ -n "${RAM_NAMESPACE:-}" ]]            && export TF_VAR_ram_namespace="$RAM_NAMESPACE"
[[ -n "${RAM_SERVICE_ACCOUNT_NAME:-}" ]] && export TF_VAR_ram_service_account_name="$RAM_SERVICE_ACCOUNT_NAME"

WHAT_IF="false"
SKIP_INIT="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --what-if)   WHAT_IF="true";   shift ;;
    --skip-init) SKIP_INIT="true"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

TF_DIR="${RAM_ROOT}/infra/terraform-eks"
cd "$TF_DIR"

if [[ "$WHAT_IF" == "true" ]]; then
  echo "Dry-run: planning Terraform deployment for EKS cluster: ${EKS_CLUSTER_NAME}"
  [[ "$SKIP_INIT" != "true" ]] && terraform init
  terraform plan
  exit 0
fi

echo "Deploying EKS cluster via Terraform: ${EKS_CLUSTER_NAME} (${EKS_AWS_REGION})"
[[ "$SKIP_INIT" != "true" ]] && terraform init
terraform apply -auto-approve
echo "EKS cluster provisioned: ${EKS_CLUSTER_NAME}"
