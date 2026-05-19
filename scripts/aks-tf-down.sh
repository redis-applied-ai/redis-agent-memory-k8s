#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

export REDIS_ENTERPRISE_DATABASES="${REDIS_ENTERPRISE_DATABASES:-${RAM_ROOT}/k8s/redis-enterprise-databases.aks.yaml}"
export RAM_USE_CURRENT_CONTEXT=true

# Remove the ILB service first so Azure cleans up the load balancer rule.
kubectl delete -f "${RAM_ROOT}/k8s/ram-internal-lb.aks.yaml" --ignore-not-found || true

exec "${RAM_ROOT}/scripts/down.sh"
