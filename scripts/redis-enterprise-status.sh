#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd kubectl helm

echo "Redis Enterprise namespace: ${REDIS_ENTERPRISE_NAMESPACE}"
echo
helm -n "$REDIS_ENTERPRISE_NAMESPACE" list --filter "^${REDIS_ENTERPRISE_OPERATOR_RELEASE}$" || true
echo
kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" get rec,redb,sts,deploy,pods,svc 2>/dev/null || true
echo
for redb in "$REDIS_ENTERPRISE_CONTENT_REDB" "$REDIS_ENTERPRISE_JOBS_REDB"; do
  secret="$(kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" get redb "$redb" -o jsonpath='{.spec.databaseSecretName}' 2>/dev/null || true)"
  if [[ -n "$secret" ]]; then
    echo "redb/${redb} secret: ${secret}"
  fi
done
