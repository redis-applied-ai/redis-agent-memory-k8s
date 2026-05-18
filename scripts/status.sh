#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd kubectl helm

echo "Context: $(kubectl config current-context 2>/dev/null || echo '<none>')"
echo "Namespace: ${RAM_NAMESPACE}"
echo

"${RAM_ROOT}/scripts/redis-enterprise-status.sh"
echo

helm -n "$RAM_NAMESPACE" list --filter "^${RAM_RELEASE}$" || true
echo

kubectl -n "$RAM_NAMESPACE" get pods,svc,deploy 2>/dev/null || true
echo

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$RAM_LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Local API: http://127.0.0.1:${RAM_LOCAL_PORT}"
else
  echo "Local API: not forwarded. Run: make port-forward"
fi
