#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

TEMPLATE="$RAM_CONFIG_TEMPLATE"
OUTPUT="$RAM_CONFIG_OUTPUT"
OPENAI_PLACEHOLDER="REPLACE_WITH_OPENAI_API_KEY"
STORE_ID_PLACEHOLDER="REPLACE_WITH_RAM_STORE_ID"
CONTENT_REDIS_PLACEHOLDER="REPLACE_WITH_CONTENT_REDIS_URL"
JOBS_REDIS_PLACEHOLDER="REPLACE_WITH_JOBS_REDIS_URL"

usage() {
  cat <<'USAGE'
Usage: render-config.sh [--template file] [--output file]

Renders the RAM config template by replacing:
  REPLACE_WITH_OPENAI_API_KEY with OPENAI_API_KEY
  REPLACE_WITH_RAM_STORE_ID with RAM_STORE_ID
  REPLACE_WITH_CONTENT_REDIS_URL with the content REDB URL
  REPLACE_WITH_JOBS_REDIS_URL with the jobs REDB URL
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template) TEMPLATE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_file "$TEMPLATE" "Template not found"

# OpenAI API key substitution is optional — only required when the template
# still uses static credentials (credentials.type: static + REPLACE_WITH_OPENAI_API_KEY).
# Templates that use Entra credentials (credentials.type: entra) don't need a key.
NEEDS_OPENAI_KEY="false"
if grep -q "$OPENAI_PLACEHOLDER" "$TEMPLATE"; then
  NEEDS_OPENAI_KEY="true"
fi

if [[ "$NEEDS_OPENAI_KEY" == "true" ]]; then
  if [[ -z "${OPENAI_API_KEY:-}" && -f "$OUTPUT" ]]; then
    OPENAI_API_KEY="$(awk -F': ' '/api_key:/ {gsub(/"/, "", $2); print $2; exit}' "$OUTPUT")"
  fi
  [[ -n "${OPENAI_API_KEY:-}" ]] || { echo "OPENAI_API_KEY is not set (template uses static credentials)" >&2; exit 1; }
  [[ "$OPENAI_API_KEY" != "$OPENAI_PLACEHOLDER" ]] || { echo "OPENAI_API_KEY still contains the example placeholder" >&2; exit 1; }
fi

if ! grep -q "$STORE_ID_PLACEHOLDER" "$TEMPLATE"; then
  echo "Template does not contain $STORE_ID_PLACEHOLDER: $TEMPLATE" >&2
  exit 1
fi

if ! grep -q "$CONTENT_REDIS_PLACEHOLDER" "$TEMPLATE"; then
  echo "Template does not contain $CONTENT_REDIS_PLACEHOLDER: $TEMPLATE" >&2
  exit 1
fi

if ! grep -q "$JOBS_REDIS_PLACEHOLDER" "$TEMPLATE"; then
  echo "Template does not contain $JOBS_REDIS_PLACEHOLDER: $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
tmp_output="$(mktemp "${OUTPUT}.tmp.XXXXXX")"
trap 'rm -f "$tmp_output"' EXIT

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

redb_secret_name() {
  declare redb="$1"
  kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" get redb "$redb" -o jsonpath='{.spec.databaseSecretName}'
}

secret_value() {
  declare secret="$1"
  declare key="$2"
  kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" get secret "$secret" -o jsonpath="{.data.${key}}" |
    python3 -c 'import base64,sys; print(base64.b64decode(sys.stdin.read()).decode(), end="")'
}

redb_url() {
  declare redb="$1"
  declare secret
  declare password
  declare port
  declare service_names
  declare service
  declare host
  declare encoded_password

  secret="$(redb_secret_name "$redb")"
  if [[ -z "$secret" ]]; then
    secret="redb-${redb}"
  fi

  password="$(secret_value "$secret" password)"
  port="$(secret_value "$secret" port)"
  service_names="$(secret_value "$secret" service_names)"
  service="$(printf '%s' "$service_names" | tr ',; ' '\n' | sed '/^$/d' | head -1)"

  if [[ -z "$service" || -z "$port" ]]; then
    echo "Could not derive service/port from secret ${secret}" >&2
    return 1
  fi

  if [[ "$service" == *.* ]]; then
    host="$service"
  else
    host="${service}.${REDIS_ENTERPRISE_NAMESPACE}.svc"
  fi

  encoded_password="$(python3 - "$password" <<'PY'
import sys
from urllib.parse import quote
print(quote(sys.argv[1], safe=""))
PY
)"
  printf 'redis://:%s@%s:%s' "$encoded_password" "$host" "$port"
}

if [[ -z "${RAM_CONTENT_REDIS_URL:-}" ]]; then
  ram_require_cmd kubectl python3
  RAM_CONTENT_REDIS_URL="$(redb_url "$REDIS_ENTERPRISE_CONTENT_REDB")"
fi

if [[ -z "${RAM_JOBS_REDIS_URL:-}" ]]; then
  ram_require_cmd kubectl python3
  RAM_JOBS_REDIS_URL="$(redb_url "$REDIS_ENTERPRISE_JOBS_REDB")"
fi

SED_ARGS=(
  -e "s/$STORE_ID_PLACEHOLDER/$(escape_sed "$RAM_STORE_ID")/g"
  -e "s/$CONTENT_REDIS_PLACEHOLDER/$(escape_sed "$RAM_CONTENT_REDIS_URL")/g"
  -e "s/$JOBS_REDIS_PLACEHOLDER/$(escape_sed "$RAM_JOBS_REDIS_URL")/g"
)
if [[ "$NEEDS_OPENAI_KEY" == "true" ]]; then
  SED_ARGS+=(-e "s/$OPENAI_PLACEHOLDER/$(escape_sed "$OPENAI_API_KEY")/g")
fi

sed "${SED_ARGS[@]}" "$TEMPLATE" > "$tmp_output"

REMAINING_PLACEHOLDERS="${STORE_ID_PLACEHOLDER}|${CONTENT_REDIS_PLACEHOLDER}|${JOBS_REDIS_PLACEHOLDER}"
if [[ "$NEEDS_OPENAI_KEY" == "true" ]]; then
  REMAINING_PLACEHOLDERS="${REMAINING_PLACEHOLDERS}|${OPENAI_PLACEHOLDER}"
fi
if grep -qE "$REMAINING_PLACEHOLDERS" "$tmp_output"; then
  echo "Rendered config still contains a template placeholder" >&2
  exit 1
fi

mv "$tmp_output" "$OUTPUT"
chmod 600 "$OUTPUT"
trap - EXIT

echo "Rendered RAM config: $OUTPUT"
