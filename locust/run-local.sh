#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

HOST="$RAM_BASE_URL"
USERS="${LOCUST_USERS:-1000}"
SPAWN_RATE="${LOCUST_SPAWN_RATE:-50}"
DURATION="${LOCUST_DURATION:-30m}"
PROFILE="${RAM_LOCUST_PROFILE:-working-memory}"
UI="false"
WEB_HOST="${LOCUST_WEB_HOST:-127.0.0.1}"
WEB_PORT="${LOCUST_WEB_PORT:-8089}"
export RAM_STORE_ID

usage() {
  cat <<'USAGE'
Usage: run-local.sh [--profile working-memory|search|promotion|mixed] [--host url] [--users n] [--spawn-rate n] [--duration time] [--ui] [--web-host host] [--web-port port]

Profiles:
  working-memory  Writes/reads session memory and disables long-term search.
  search          Writes/reads session memory and searches seeded long-term memory.
  promotion       Writes/reads session memory while the worker processes promotion jobs.
  mixed           Writes/reads session memory and searches long-term memory.

Modes:
  default         Headless run that writes CSV and HTML reports under results/.
  --ui            Start the Locust web UI instead of a headless run.
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
    --host) require_value "$@"; HOST="$2"; shift 2 ;;
    --users) require_value "$@"; USERS="$2"; shift 2 ;;
    --spawn-rate) require_value "$@"; SPAWN_RATE="$2"; shift 2 ;;
    --duration) require_value "$@"; DURATION="$2"; shift 2 ;;
    --ui) UI="true"; shift ;;
    --web-host) require_value "$@"; WEB_HOST="$2"; shift 2 ;;
    --web-port) require_value "$@"; WEB_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd curl locust

case "$PROFILE" in
  working-memory)
    PROFILE="working-memory"
    export RAM_INCLUDE_LTM_SEARCH="false"
    export RAM_SEARCH_WEIGHT="0"
    ;;
  promotion)
    export RAM_INCLUDE_LTM_SEARCH="false"
    export RAM_SEARCH_WEIGHT="0"
    ;;
  search|mixed)
    export RAM_INCLUDE_LTM_SEARCH="${RAM_INCLUDE_LTM_SEARCH:-true}"
    export RAM_SEARCH_WEIGHT="${RAM_SEARCH_WEIGHT:-1}"
    ;;
  *)
    echo "Unknown profile: ${PROFILE}" >&2
    usage
    exit 1
    ;;
esac

if ! curl -fsS --max-time 3 "${HOST}/health/readiness" >/dev/null; then
  cat >&2 <<EOF
RAM API is not reachable at ${HOST}.
Start it in another terminal with:
  make port-forward
EOF
  exit 1
fi

if [[ "$UI" == "true" ]]; then
  echo "Starting Locust UI for profile '${PROFILE}'"
  echo "RAM host: ${HOST}"
  echo "Locust UI: http://${WEB_HOST}:${WEB_PORT}"
  echo "Open the UI with http://, not https://; Locust's local web server does not serve TLS."
  exec locust -f "${RAM_ROOT}/locust/ram_locustfile.py" \
    --host "$HOST" \
    --web-host "$WEB_HOST" \
    --web-port "$WEB_PORT"
fi

mkdir -p "$RAM_RESULTS_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_prefix="${RAM_RESULTS_DIR}/ram-${PROFILE}-${USERS}-${timestamp}"

locust -f "${RAM_ROOT}/locust/ram_locustfile.py" \
  --host "$HOST" \
  --headless \
  -u "$USERS" \
  -r "$SPAWN_RATE" \
  -t "$DURATION" \
  --csv "$result_prefix" \
  --html "${result_prefix}.html"
