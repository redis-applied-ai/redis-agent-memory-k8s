#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

# Uninstalls RAM + Redis Enterprise from the current EKS context. The cluster
# itself is kept (use `make delete ENV=eks` to destroy it). The azure-wi webhook
# is left in place; it is harmless and reused on the next deploy.
export REDIS_ENTERPRISE_DATABASES="${RAM_ROOT}/k8s/redis-enterprise-databases.eks.yaml"
export RAM_USE_CURRENT_CONTEXT=true

exec "${RAM_ROOT}/scripts/down.sh"
