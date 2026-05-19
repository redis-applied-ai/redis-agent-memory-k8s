#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: aks-tf-up.sh [--skip-provision]

Provisions an AKS cluster via Terraform, fetches credentials, installs Redis
Enterprise for Kubernetes, and installs RAM with Helm.

Options:
  --skip-provision  Skip Terraform deployment and credential fetch (cluster must
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

# AKS-specific config overrides — users can override any of these via .env or
# shell exports before running this script.
export REDIS_ENTERPRISE_VALUES="${REDIS_ENTERPRISE_VALUES:-${RAM_ROOT}/configs/redis-enterprise/operator.values.aks.yaml}"
export REDIS_ENTERPRISE_DATABASES="${REDIS_ENTERPRISE_DATABASES:-${RAM_ROOT}/k8s/redis-enterprise-databases.aks.yaml}"
export RAM_VALUES="${RAM_VALUES:-${RAM_ROOT}/configs/values.ram.aks.yaml}"
export RAM_USE_CURRENT_CONTEXT=true

if [[ "$SKIP_PROVISION" != "true" ]]; then
  ram_require_cmd az terraform
  "${RAM_ROOT}/scripts/aks-tf-provision.sh"
  "${RAM_ROOT}/scripts/aks-tf-credentials.sh"
fi

"${RAM_ROOT}/scripts/deploy-stack.sh"

echo "Applying RAM internal load balancer service..."
kubectl apply -f "${RAM_ROOT}/k8s/ram-internal-lb.aks.yaml"
echo "ILB service applied. Azure will assign a private IP shortly (check: kubectl get svc redis-agent-memory-ilb -n ram)"
