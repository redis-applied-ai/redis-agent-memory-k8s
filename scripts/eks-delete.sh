#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd terraform aws

# Destroys the EKS cluster and removes the EKS federated credential from the
# UAMI. The UAMI, AOAI account, and the AKS deployment are owned by
# ../terraform and are left untouched.
export TF_VAR_aws_region="$EKS_AWS_REGION"
export TF_VAR_cluster_name="$EKS_CLUSTER_NAME"
export TF_VAR_kubernetes_version="$EKS_KUBERNETES_VERSION"
export TF_VAR_node_instance_type="$EKS_NODE_INSTANCE_TYPE"
export TF_VAR_node_count="$EKS_NODE_COUNT"
export TF_VAR_azure_resource_group="$AZURE_RESOURCE_GROUP"
[[ -n "${RAM_IDENTITY_NAME:-}" ]]        && export TF_VAR_ram_identity_name="$RAM_IDENTITY_NAME"
[[ -n "${RAM_NAMESPACE:-}" ]]            && export TF_VAR_ram_namespace="$RAM_NAMESPACE"
[[ -n "${RAM_SERVICE_ACCOUNT_NAME:-}" ]] && export TF_VAR_ram_service_account_name="$RAM_SERVICE_ACCOUNT_NAME"

TF_DIR="${RAM_ROOT}/infra/terraform-eks"
cd "$TF_DIR"

echo "Destroying EKS cluster via Terraform: ${EKS_CLUSTER_NAME}"
echo "This removes the EKS cluster and the EKS federated credential on the UAMI."
echo "The Azure UAMI, AOAI account, and AKS deployment are NOT affected."
terraform destroy -auto-approve
echo "Terraform destroy complete for cluster: ${EKS_CLUSTER_NAME}"
