#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

BASE_URL="$RAM_BASE_URL"
STORE_ID="$RAM_STORE_ID"
SKIP_LTM="false"
KEEP_OUTPUT="${RAM_KEEP_TEST_OUTPUT:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) BASE_URL="$2"; shift 2 ;;
    --store-id) STORE_ID="$2"; shift 2 ;;
    --skip-ltm) SKIP_LTM="true"; shift ;;
    -h|--help)
      echo "Usage: smoke-test.sh [--base-url url] [--store-id id] [--skip-ltm]"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

ram_require_cmd curl python3

SESSION_ID="local-$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24)"
ACTOR_ID="ram-user"
MEMORY_ID="mem-$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-24)"
NOW_MS="$(($(date -u +%s) * 1000))"
SESSION_TEXT="hello from the RAM local harness on Kubernetes"
MEMORY_TEXT="The RAM local harness validates Redis Agent Memory before production deployment."
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ram-smoke.XXXXXX")"

cleanup() {
  local status=$?
  if [[ "$status" -eq 0 && "$KEEP_OUTPUT" != "true" ]]; then
    rm -rf "$TMP_DIR"
  else
    echo "Smoke test artifacts: ${TMP_DIR}" >&2
  fi
}
trap cleanup EXIT

request_json() {
  local method="$1"
  local url="$2"
  local output="$3"
  local payload="${4:-}"
  local status

  if [[ -n "$payload" ]]; then
    status="$(curl -sS -o "$output" -w '%{http_code}' -X "$method" "$url" \
      -H "content-type: application/json" \
      -d "$payload")"
  else
    status="$(curl -sS -o "$output" -w '%{http_code}' -X "$method" "$url")"
  fi

  if [[ ! "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "Request failed: ${method} ${url} -> HTTP ${status}" >&2
    sed -n '1,120p' "$output" >&2 || true
    exit 1
  fi
}

echo "Checking health at ${BASE_URL}"
curl -fsS "${BASE_URL}/health/liveness" >/dev/null
curl -fsS "${BASE_URL}/health/readiness" >/dev/null

echo "Writing session event ${SESSION_ID}"
request_json POST "${BASE_URL}/v1/stores/${STORE_ID}/session-memory/events" \
  "${TMP_DIR}/session-write.json" \
  "{
    \"sessionId\": \"${SESSION_ID}\",
    \"actorId\": \"${ACTOR_ID}\",
    \"role\": \"USER\",
    \"content\": [{\"text\": \"${SESSION_TEXT}\"}],
    \"createdAt\": ${NOW_MS},
    \"metadata\": {\"source\": \"smoke-test\"}
  }"

echo "Reading session memory ${SESSION_ID}"
request_json GET "${BASE_URL}/v1/stores/${STORE_ID}/session-memory/${SESSION_ID}" \
  "${TMP_DIR}/session-read.json"

python3 - "${TMP_DIR}/session-read.json" "$SESSION_ID" "$SESSION_TEXT" <<'PY'
import json
import sys

path, session_id, text = sys.argv[1:]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

events = data.get("events", [])
if data.get("sessionId") != session_id:
    raise SystemExit(f"sessionId mismatch: {data.get('sessionId')} != {session_id}")

if not any(
    event.get("sessionId") == session_id
    and any(item.get("text") == text for item in event.get("content", []))
    for event in events
):
    raise SystemExit("written session event was not returned by session read")
PY

if [[ "$SKIP_LTM" == "true" ]]; then
  echo "Skipping long-term memory checks"
  echo "Smoke test passed"
  exit 0
fi

echo "Creating long-term memory ${MEMORY_ID}"
request_json POST "${BASE_URL}/v1/stores/${STORE_ID}/long-term-memory" \
  "${TMP_DIR}/ltm-create.json" \
  "{
    \"memories\": [{
      \"id\": \"${MEMORY_ID}\",
      \"text\": \"${MEMORY_TEXT}\",
      \"memoryType\": \"semantic\",
      \"sessionId\": \"${SESSION_ID}\",
      \"ownerId\": \"${ACTOR_ID}\",
      \"namespace\": \"ram-local\",
      \"topics\": [\"ram\", \"local-k8s\", \"openai\"]
    }]
  }"

python3 - "${TMP_DIR}/ltm-create.json" "$MEMORY_ID" <<'PY'
import json
import sys

path, memory_id = sys.argv[1:]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
if memory_id not in data.get("created", []):
    raise SystemExit(f"created memory id not found: {memory_id}")
PY

echo "Searching long-term memory"
request_json POST "${BASE_URL}/v1/stores/${STORE_ID}/long-term-memory/search" \
  "${TMP_DIR}/ltm-search.json" \
  "{
    \"text\": \"Redis Agent Memory local Kubernetes\",
    \"filter\": {
      \"ownerId\": {\"eq\": \"${ACTOR_ID}\"},
      \"namespace\": {\"eq\": \"ram-local\"}
    },
    \"filterOp\": \"all\",
    \"limit\": 10
  }"

python3 - "${TMP_DIR}/ltm-search.json" "$MEMORY_ID" "$MEMORY_TEXT" <<'PY'
import json
import sys

path, memory_id, text = sys.argv[1:]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
if not any(memory.get("id") == memory_id and memory.get("text") == text for memory in data.get("memories", [])):
    raise SystemExit(f"created memory was not returned by search: {memory_id}")
PY

echo "Smoke test passed"
echo "Session ID: ${SESSION_ID}"
echo "Memory ID: ${MEMORY_ID}"
