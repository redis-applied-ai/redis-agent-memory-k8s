#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

HOST="$RAM_BASE_URL"
USERS="${LOCUST_USERS:-1000}"
SPAWN_RATE="${LOCUST_SPAWN_RATE:-50}"
DURATION="${LOCUST_DURATION:-30m}"
PROFILE="${RAM_LOCUST_PROFILE:-session}"
export RAM_STORE_ID

usage() {
  cat <<'USAGE'
Usage: run-local.sh [--profile session|search|promotion|mixed] [--host url] [--users n] [--spawn-rate n] [--duration time]

Profiles:
  session    Writes/reads session memory and disables long-term search.
  search     Writes/reads session memory and searches seeded long-term memory.
  promotion  Writes/reads session memory while the worker processes promotion jobs.
  mixed      Writes/reads session memory and searches long-term memory.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --users) USERS="$2"; shift 2 ;;
    --spawn-rate) SPAWN_RATE="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd locust

case "$PROFILE" in
  session|promotion)
    export RAM_INCLUDE_LTM_SEARCH="${RAM_INCLUDE_LTM_SEARCH:-false}"
    export RAM_SEARCH_WEIGHT="${RAM_SEARCH_WEIGHT:-1}"
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
