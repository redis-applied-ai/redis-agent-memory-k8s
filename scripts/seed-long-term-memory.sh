#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

BASE_URL="$RAM_BASE_URL"
STORE_ID="$RAM_STORE_ID"
COUNT="100"
RUN_ID="$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c1-8)"

usage() {
  cat <<'USAGE'
Usage: seed-long-term-memory.sh [--count n] [--base-url url] [--store-id id]

Creates deterministic long-term memories for search/load tests.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --count) COUNT="$2"; shift 2 ;;
    --base-url) BASE_URL="$2"; shift 2 ;;
    --store-id) STORE_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        COUNT="$1"; shift
      else
        echo "Unknown argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

ram_require_cmd curl python3

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 1 ]]; then
  echo "--count must be a positive integer" >&2
  exit 1
fi

request_json() {
  declare output="$1"
  declare payload="$2"
  declare status
  status="$(curl -sS -o "$output" -w '%{http_code}' -X POST "${BASE_URL}/v1/stores/${STORE_ID}/long-term-memory" \
    -H "content-type: application/json" \
    -d "$payload")"
  if [[ ! "$status" =~ ^2[0-9][0-9]$ ]]; then
    echo "Seed request failed with HTTP ${status}" >&2
    sed -n '1,120p' "$output" >&2 || true
    exit 1
  fi
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ram-seed.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

for i in $(seq 1 "$COUNT"); do
  MEMORY_ID="seed-${RUN_ID}-${i}"
  response="${TMP_DIR}/seed-${i}.json"
  request_json "$response" "{
      \"memories\": [{
        \"id\": \"${MEMORY_ID}\",
        \"text\": \"Seed memory ${i} for RAM search testing on Kubernetes.\",
        \"memoryType\": \"semantic\",
        \"ownerId\": \"load-user\",
        \"namespace\": \"ram-load\",
        \"topics\": [\"load-test\", \"ram\"]
      }]
    }"
  python3 - "$response" "$MEMORY_ID" <<'PY'
import json
import sys

path, memory_id = sys.argv[1:]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
if memory_id not in data.get("created", []):
    raise SystemExit(f"created memory id not found: {memory_id}")
PY
done

echo "Seeded ${COUNT} long-term memories with prefix seed-${RUN_ID}"
