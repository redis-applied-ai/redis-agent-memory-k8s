#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

HOST="$RAM_BASE_URL"
PROFILE="${RAM_LOCUST_PROFILE:-working-memory}"
WORKER_MODE=""
WEB_HOST="${LOCUST_WEB_HOST:-127.0.0.1}"
WEB_PORT="${LOCUST_WEB_PORT:-8089}"
export RAM_STORE_ID

usage() {
  cat <<'USAGE'
Usage: run.sh [--profile working-memory|search|promotion] [--worker on|off|unchanged] [--host url] [--web-host host] [--web-port port]

Profiles:
  working-memory  Writes/reads session memory and disables long-term search.
  search          Writes/reads session memory and searches seeded long-term memory.
  promotion       Writes/reads session memory while the worker processes promotion jobs.

This runner always starts the Locust web UI.
USAGE
}

require_value() {
  if [[ $# -lt 2 || "$2" == --* ]]; then
    echo "Missing value for $1" >&2
    usage
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) require_value "$@"; PROFILE="$2"; shift 2 ;;
    --worker) require_value "$@"; WORKER_MODE="$2"; shift 2 ;;
    --host) require_value "$@"; HOST="$2"; shift 2 ;;
    --web-host) require_value "$@"; WEB_HOST="$2"; shift 2 ;;
    --web-port) require_value "$@"; WEB_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd curl kubectl locust

scale_worker() {
  declare mode="$1"
  case "$mode" in
    on)
      kubectl -n "$RAM_NAMESPACE" scale "deploy/${RAM_RELEASE}-worker" --replicas="$RAM_WORKER_REPLICAS"
      kubectl -n "$RAM_NAMESPACE" rollout status "deploy/${RAM_RELEASE}-worker" --timeout="$RAM_WAIT_TIMEOUT"
      ;;
    off)
      kubectl -n "$RAM_NAMESPACE" scale "deploy/${RAM_RELEASE}-worker" --replicas=0
      ;;
    unchanged)
      ;;
    *)
      echo "Unknown worker mode: ${mode}" >&2
      usage
      exit 1
      ;;
  esac
}

case "$PROFILE" in
  working-memory)
    PROFILE="working-memory"
    WORKER_MODE="${WORKER_MODE:-off}"
    export RAM_INCLUDE_LTM_SEARCH="false"
    export RAM_SEARCH_WEIGHT="0"
    ;;
  promotion)
    WORKER_MODE="${WORKER_MODE:-on}"
    export RAM_INCLUDE_LTM_SEARCH="false"
    export RAM_SEARCH_WEIGHT="0"
    ;;
  search)
    WORKER_MODE="${WORKER_MODE:-off}"
    export RAM_INCLUDE_LTM_SEARCH="${RAM_INCLUDE_LTM_SEARCH:-true}"
    export RAM_SEARCH_WEIGHT="${RAM_SEARCH_WEIGHT:-1}"
    ;;
  *)
    echo "Unknown profile: ${PROFILE}" >&2
    usage
    exit 1
    ;;
esac

scale_worker "$WORKER_MODE"

if ! curl -fsS --max-time 3 "${HOST}/health/readiness" >/dev/null; then
  cat >&2 <<EOF
RAM API is not reachable at ${HOST}.
Start it in another terminal with:
  make port-forward
EOF
  exit 1
fi

echo "Starting Locust UI for profile '${PROFILE}'"
echo "Worker mode: ${WORKER_MODE}"
echo "RAM host: ${HOST}"
echo "Locust UI: http://${WEB_HOST}:${WEB_PORT}"
echo "Use Grafana for RAM and Redis internals: http://127.0.0.1:${RAM_GRAFANA_PORT}"
echo "Open the UI with http://, not https://; Locust's web server does not serve TLS."
exec locust -f "${RAM_ROOT}/locust/ram_locustfile.py" \
  --host "$HOST" \
  --web-host "$WEB_HOST" \
  --web-port "$WEB_PORT"
