#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

wait_for_jsonpath() {
  declare description="$1"
  declare cmd="$2"
  declare expected="$3"
  declare timeout_seconds="${4%s}"
  declare start
  declare value

  start="$(date +%s)"
  while true; do
    value="$(eval "$cmd" 2>/dev/null || true)"
    if [[ "$value" == "$expected" ]]; then
      echo "${description}: ${value}"
      return 0
    fi

    if (( $(date +%s) - start > timeout_seconds )); then
      echo "Timed out waiting for ${description}; last value: ${value:-<empty>}" >&2
      return 1
    fi

    sleep 10
  done
}

wait_for_redb() {
  declare redb="$1"
  wait_for_jsonpath "redb/${redb} status" \
    "kubectl -n '$REDIS_ENTERPRISE_NAMESPACE' get redb '$redb' -o jsonpath='{.status.status}'" \
    "active" \
    "$REDIS_ENTERPRISE_WAIT_TIMEOUT"
  wait_for_jsonpath "redb/${redb} spec status" \
    "kubectl -n '$REDIS_ENTERPRISE_NAMESPACE' get redb '$redb' -o jsonpath='{.status.specStatus}'" \
    "Valid" \
    "$REDIS_ENTERPRISE_WAIT_TIMEOUT"
}

ensure_redb_secret() {
  declare secret="$1"
  declare password

  if kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" get secret "$secret" >/dev/null 2>&1; then
    return 0
  fi

  password="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
)"
  kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" create secret generic "$secret" \
    --from-literal=password="$password" >/dev/null
}

ram_require_cmd kubectl helm
ram_require_cmd python3
ram_require_file "$REDIS_ENTERPRISE_VALUES" "Redis Enterprise values file not found"
ram_require_file "$REDIS_ENTERPRISE_DATABASES" "Redis Enterprise database manifest not found"

RAM_NAMESPACE="$REDIS_ENTERPRISE_NAMESPACE"
ram_create_namespace

helm repo add redis https://helm.redis.io >/dev/null 2>&1 || true
helm repo update

helm upgrade --install "$REDIS_ENTERPRISE_OPERATOR_RELEASE" "$REDIS_ENTERPRISE_OPERATOR_CHART" \
  --version "$REDIS_ENTERPRISE_OPERATOR_VERSION" \
  --devel \
  -n "$REDIS_ENTERPRISE_NAMESPACE" \
  -f "$REDIS_ENTERPRISE_VALUES" \
  --wait \
  --timeout "$REDIS_ENTERPRISE_WAIT_TIMEOUT"

wait_for_jsonpath "rec/${REDIS_ENTERPRISE_REC} state" \
  "kubectl -n '$REDIS_ENTERPRISE_NAMESPACE' get rec '$REDIS_ENTERPRISE_REC' -o jsonpath='{.status.state}'" \
  "Running" \
  "$REDIS_ENTERPRISE_WAIT_TIMEOUT"
wait_for_jsonpath "rec/${REDIS_ENTERPRISE_REC} spec status" \
  "kubectl -n '$REDIS_ENTERPRISE_NAMESPACE' get rec '$REDIS_ENTERPRISE_REC' -o jsonpath='{.status.specStatus}'" \
  "Valid" \
  "$REDIS_ENTERPRISE_WAIT_TIMEOUT"

ensure_redb_secret redb-ram-content
ensure_redb_secret redb-ram-jobs

kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" apply -f "$REDIS_ENTERPRISE_DATABASES"
wait_for_redb "$REDIS_ENTERPRISE_CONTENT_REDB"
wait_for_redb "$REDIS_ENTERPRISE_JOBS_REDB"

kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" get rec,redb,svc
