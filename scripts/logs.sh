#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

COMPONENT="all"
TAIL="100"
FOLLOW="false"

usage() {
  cat <<'USAGE'
Usage: logs.sh [server|worker|all] [--tail n] [--follow]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    server|worker|all) COMPONENT="$1"; shift ;;
    --tail) TAIL="$2"; shift 2 ;;
    --follow) FOLLOW="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl

follow_arg=()
if [[ "$FOLLOW" == "true" ]]; then
  follow_arg=(-f)
fi

case "$COMPONENT" in
  server)
    kubectl -n "$RAM_NAMESPACE" logs "deploy/${RAM_RELEASE}" --tail="$TAIL" "${follow_arg[@]}"
    ;;
  worker)
    kubectl -n "$RAM_NAMESPACE" logs "deploy/${RAM_RELEASE}-worker" --tail="$TAIL" "${follow_arg[@]}"
    ;;
  all)
    echo "== server =="
    kubectl -n "$RAM_NAMESPACE" logs "deploy/${RAM_RELEASE}" --tail="$TAIL"
    echo
    echo "== worker =="
    kubectl -n "$RAM_NAMESPACE" logs "deploy/${RAM_RELEASE}-worker" --tail="$TAIL"
    ;;
esac
