#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: worker.sh on|off|status [--replicas n]

Use off for API/Redis load baselines that must not call the model provider.
Use on before promotion tests.
USAGE
}

ACTION="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

REPLICAS="$RAM_WORKER_REPLICAS"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --replicas) REPLICAS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl

case "$ACTION" in
  on)
    kubectl -n "$RAM_NAMESPACE" scale "deploy/${RAM_RELEASE}-worker" --replicas="$REPLICAS"
    kubectl -n "$RAM_NAMESPACE" rollout status "deploy/${RAM_RELEASE}-worker" --timeout="$RAM_WAIT_TIMEOUT"
    ;;
  off)
    kubectl -n "$RAM_NAMESPACE" scale "deploy/${RAM_RELEASE}-worker" --replicas=0
    ;;
  status)
    kubectl -n "$RAM_NAMESPACE" get "deploy/${RAM_RELEASE}-worker"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
