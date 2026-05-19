#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: deploy-stack.sh

Installs Redis Enterprise for Kubernetes, creates RAM Secrets, and installs
RAM with Helm into the configured Kubernetes context.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl helm
ram_use_context

"${RAM_ROOT}/scripts/redis-enterprise-up.sh"
"${RAM_ROOT}/scripts/render-config.sh"
"${RAM_ROOT}/scripts/create-ram-secrets.sh"
"${RAM_ROOT}/scripts/install-ram.sh"

echo "Restarting RAM deployments so Redis indexes are ensured"
kubectl -n "$RAM_NAMESPACE" rollout restart "deploy/${RAM_RELEASE}" "deploy/${RAM_RELEASE}-worker"
kubectl -n "$RAM_NAMESPACE" rollout status "deploy/${RAM_RELEASE}" --timeout="$RAM_WAIT_TIMEOUT"
kubectl -n "$RAM_NAMESPACE" rollout status "deploy/${RAM_RELEASE}-worker" --timeout="$RAM_WAIT_TIMEOUT"

"${RAM_ROOT}/scripts/status.sh"

echo "RAM is installed. Run: make port-forward"
