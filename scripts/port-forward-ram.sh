#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

NAMESPACE="$RAM_NAMESPACE"
RELEASE="$RAM_RELEASE"
API_PORT="$RAM_API_PORT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --release) RELEASE="$2"; shift 2 ;;
    --port) API_PORT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: port-forward-ram.sh [--namespace ns] [--release release] [--port api-port]"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

ram_require_cmd kubectl

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$API_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "API port ${API_PORT} is already in use" >&2
  exit 1
fi

echo "Forwarding http://127.0.0.1:${API_PORT} -> svc/${RELEASE}:9000"
kubectl -n "$NAMESPACE" port-forward "svc/${RELEASE}" "${API_PORT}:9000"
