#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: eks-up.sh [--skip-provision]

Provisions an EKS cluster via Terraform, adds an Azure federated identity
credential to the existing RAM UAMI (so EKS pods authenticate to Azure OpenAI
via Entra workload identity), installs the azure-workload-identity webhook,
then installs Redis Enterprise for Kubernetes and RAM with Helm.

Options:
  --skip-provision  Skip Terraform apply and credential fetch (cluster must
                    already exist and kubeconfig must point to it)
USAGE
}

SKIP_PROVISION="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-provision) SKIP_PROVISION="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# EKS-specific config overrides — override via .env or shell exports before
# running. common.sh has set these to the kind defaults, so override here.
export REDIS_ENTERPRISE_VALUES="${RAM_ROOT}/configs/redis-enterprise/operator.values.eks.yaml"
export REDIS_ENTERPRISE_DATABASES="${RAM_ROOT}/k8s/redis-enterprise-databases.eks.yaml"
export RAM_VALUES="${RAM_ROOT}/configs/values.ram.eks.yaml"
export RAM_USE_CURRENT_CONTEXT=true

if [[ "$SKIP_PROVISION" != "true" ]]; then
  ram_require_cmd aws az terraform helm
  "${RAM_ROOT}/scripts/eks-provision.sh"
  "${RAM_ROOT}/scripts/eks-credentials.sh"
fi

# Surface the RAM UAMI client/tenant IDs from the EKS terraform outputs so
# install-ram.sh can annotate the ServiceAccount + label the pod template, and
# so we can configure the workload-identity webhook with the correct tenant.
TF_DIR="${RAM_ROOT}/infra/terraform-eks"
RAM_IDENTITY_CLIENT_ID="$(terraform -chdir="$TF_DIR" output -raw ram_identity_client_id 2>/dev/null || true)"
RAM_IDENTITY_TENANT_ID="$(terraform -chdir="$TF_DIR" output -raw ram_identity_tenant_id 2>/dev/null || true)"
if [[ -z "$RAM_IDENTITY_CLIENT_ID" || -z "$RAM_IDENTITY_TENANT_ID" ]]; then
  echo "Error: could not read ram_identity_client_id / ram_identity_tenant_id from terraform outputs." >&2
  echo "Run 'make up ENV=eks' without --skip-provision, or 'terraform -chdir=${TF_DIR} apply' first." >&2
  exit 1
fi
export RAM_IDENTITY_CLIENT_ID RAM_IDENTITY_TENANT_ID
echo "RAM workload identity client_id: ${RAM_IDENTITY_CLIENT_ID}"

# gp3 StorageClass for the EBS CSI driver (Redis Enterprise PVCs reference it).
echo "Applying gp3 StorageClass..."
kubectl apply -f "${RAM_ROOT}/k8s/eks-gp3-storageclass.yaml"

# Install the Azure Workload Identity mutating webhook. AKS provides this
# natively; on EKS we install the vendor-neutral chart so the same SA annotation
# + pod label that install-ram.sh sets triggers AZURE_* env + projected-token
# injection (projected token audience defaults to api://AzureADTokenExchange,
# matching the federated credential).
echo "Installing azure-workload-identity webhook (tenant ${RAM_IDENTITY_TENANT_ID})..."
helm repo add azure-workload-identity https://azure.github.io/azure-workload-identity/charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install workload-identity-webhook \
  azure-workload-identity/workload-identity-webhook \
  --namespace azure-workload-identity-system --create-namespace \
  --set azureTenantID="${RAM_IDENTITY_TENANT_ID}" \
  --wait

# Create the ACR image pull secret referenced by configs/values.ram.eks.yaml
# (imagePullSecrets: acr-pull). RAM's image lives in a private ACR that EKS nodes
# can't pull anonymously; ACR_PULL_* come from a scoped pull token (see README).
if [[ "$RAM_IMAGE" == *.azurecr.io/* ]]; then
  if [[ -z "${ACR_PULL_USERNAME:-}" || -z "${ACR_PULL_PASSWORD:-}" ]]; then
    echo "Error: RAM_IMAGE is in ACR (${RAM_IMAGE}) but ACR_PULL_USERNAME/ACR_PULL_PASSWORD are unset." >&2
    echo "Create a scoped ACR pull token and set ACR_PULL_USERNAME/ACR_PULL_PASSWORD in .env." >&2
    exit 1
  fi
  ram_create_namespace
  echo "Creating ACR image pull secret 'acr-pull' in namespace ${RAM_NAMESPACE}..."
  kubectl -n "$RAM_NAMESPACE" create secret docker-registry acr-pull \
    --docker-server="${ACR_LOGIN_SERVER:-${RAM_IMAGE%%/*}}" \
    --docker-username="$ACR_PULL_USERNAME" \
    --docker-password="$ACR_PULL_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

"${RAM_ROOT}/scripts/deploy-stack.sh"

echo "RAM is installed on EKS. Run: make port-forward"
