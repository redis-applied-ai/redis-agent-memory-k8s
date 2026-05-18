#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: up.sh [--skip-kind] [--skip-render]

Creates or reuses the local kind cluster, installs Redis Enterprise for
Kubernetes, creates RAM Secrets, and installs RAM with Helm.
USAGE
}

SKIP_KIND="false"
SKIP_RENDER="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-kind) SKIP_KIND="true"; shift ;;
    --skip-render) SKIP_RENDER="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl helm

if [[ "$SKIP_KIND" != "true" ]]; then
  ram_require_cmd kind
  if kind get clusters | grep -qx "$RAM_KIND_CLUSTER"; then
    echo "kind cluster exists: ${RAM_KIND_CLUSTER}"
  else
    echo "Creating kind cluster: ${RAM_KIND_CLUSTER}"
    kind create cluster --name "$RAM_KIND_CLUSTER" --config "$RAM_KIND_CONFIG"
  fi
fi

ram_use_context
"${RAM_ROOT}/scripts/redis-enterprise-up.sh"

if [[ "$SKIP_RENDER" != "true" ]]; then
  "${RAM_ROOT}/scripts/render-config.sh"
fi

"${RAM_ROOT}/scripts/create-ram-secrets.sh"
"${RAM_ROOT}/scripts/install-ram.sh"

echo "Restarting RAM deployments so Redis indexes are ensured"
kubectl -n "$RAM_NAMESPACE" rollout restart "deploy/${RAM_RELEASE}" "deploy/${RAM_RELEASE}-worker"
kubectl -n "$RAM_NAMESPACE" rollout status "deploy/${RAM_RELEASE}" --timeout="$RAM_WAIT_TIMEOUT"
kubectl -n "$RAM_NAMESPACE" rollout status "deploy/${RAM_RELEASE}-worker" --timeout="$RAM_WAIT_TIMEOUT"

"${RAM_ROOT}/scripts/status.sh"

echo "RAM is installed. Run: make port-forward"
