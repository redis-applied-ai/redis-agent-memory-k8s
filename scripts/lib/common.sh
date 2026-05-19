#!/usr/bin/env bash

RAM_ROOT="${RAM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if [[ "$(uname -s)" == "Darwin" && "${LC_ALL:-}" == "C.UTF-8" ]]; then
  export LC_ALL="en_US.UTF-8"
fi

if [[ -f "${RAM_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${RAM_ROOT}/.env"
  set +a
fi

RAM_NAMESPACE="${RAM_NAMESPACE:-${NAMESPACE:-ram}}"
RAM_KIND_CLUSTER="${RAM_KIND_CLUSTER:-ram}"
RAM_KUBE_CONTEXT="${RAM_KUBE_CONTEXT:-kind-${RAM_KIND_CLUSTER}}"
RAM_KIND_CONFIG="${RAM_KIND_CONFIG:-${RAM_ROOT}/k8s/kind.redis-enterprise.yaml}"
RAM_RELEASE="${RAM_RELEASE:-redis-agent-memory}"
RAM_CHART="${RAM_CHART:-redis-ai/redis-agent-memory}"
RAM_CHART_VERSION="${RAM_CHART_VERSION:-0.1.0}"
RAM_IMAGE="${RAM_IMAGE:-redislabs/agent-memory:0.1.0}"
RAM_STORE_ID="${RAM_STORE_ID:-00000000000000000000000000000001}"

RAM_MONITORING_NAMESPACE="${RAM_MONITORING_NAMESPACE:-monitoring}"
RAM_MONITORING_RELEASE="${RAM_MONITORING_RELEASE:-ram-observability}"
RAM_MONITORING_CHART="${RAM_MONITORING_CHART:-prometheus-community/kube-prometheus-stack}"
RAM_MONITORING_CHART_VERSION="${RAM_MONITORING_CHART_VERSION:-85.1.3}"
RAM_MONITORING_VALUES="${RAM_MONITORING_VALUES:-${RAM_ROOT}/configs/monitoring/kube-prometheus-stack.values.yaml}"
RAM_MONITORING_SERVICEMONITORS="${RAM_MONITORING_SERVICEMONITORS:-${RAM_ROOT}/k8s/monitoring/servicemonitors.yaml}"
RAM_MONITORING_DASHBOARDS="${RAM_MONITORING_DASHBOARDS:-${RAM_ROOT}/k8s/monitoring/dashboards}"
RAM_MONITORING_HELM_TIMEOUT="${RAM_MONITORING_HELM_TIMEOUT:-10m}"
RAM_PROMETHEUS_PORT="${RAM_PROMETHEUS_PORT:-9090}"
RAM_GRAFANA_PORT="${RAM_GRAFANA_PORT:-3000}"
RAM_REDIS_METRICS_PATH="${RAM_REDIS_METRICS_PATH:-/v2}"

REDIS_ENTERPRISE_NAMESPACE="${REDIS_ENTERPRISE_NAMESPACE:-$RAM_NAMESPACE}"
REDIS_ENTERPRISE_OPERATOR_RELEASE="${REDIS_ENTERPRISE_OPERATOR_RELEASE:-redis-enterprise-operator}"
REDIS_ENTERPRISE_OPERATOR_CHART="${REDIS_ENTERPRISE_OPERATOR_CHART:-redis/redis-enterprise-operator}"
REDIS_ENTERPRISE_OPERATOR_VERSION="${REDIS_ENTERPRISE_OPERATOR_VERSION:-8.0.20-21}"
REDIS_ENTERPRISE_VALUES="${REDIS_ENTERPRISE_VALUES:-${RAM_ROOT}/configs/redis-enterprise/operator.values.yaml}"
REDIS_ENTERPRISE_REC="${REDIS_ENTERPRISE_REC:-rec}"
REDIS_ENTERPRISE_DATABASES="${REDIS_ENTERPRISE_DATABASES:-${RAM_ROOT}/k8s/redis-enterprise-databases.yaml}"
REDIS_ENTERPRISE_CONTENT_REDB="${REDIS_ENTERPRISE_CONTENT_REDB:-ram-content}"
REDIS_ENTERPRISE_JOBS_REDB="${REDIS_ENTERPRISE_JOBS_REDB:-ram-jobs}"

RAM_CONFIG_TEMPLATE="${RAM_CONFIG_TEMPLATE:-${RAM_ROOT}/memory-dataplane.config.yaml}"
RAM_CONFIG_OUTPUT="${RAM_CONFIG_OUTPUT:-${RAM_ROOT}/.generated/memory-dataplane.config.yaml}"
RAM_VALUES="${RAM_VALUES:-${RAM_ROOT}/configs/values.ram.kind.yaml}"
RAM_LICENSE="${RAM_LICENSE:-${RAM_ROOT}/license}"
RAM_WAIT_TIMEOUT="${RAM_WAIT_TIMEOUT:-180s}"
RAM_HELM_TIMEOUT="${RAM_HELM_TIMEOUT:-5m}"
REDIS_ENTERPRISE_WAIT_TIMEOUT="${REDIS_ENTERPRISE_WAIT_TIMEOUT:-1200s}"

RAM_API_PORT="${RAM_API_PORT:-9000}"
RAM_BASE_URL="${RAM_BASE_URL:-http://127.0.0.1:${RAM_API_PORT}}"
RAM_WORKER_REPLICAS="${RAM_WORKER_REPLICAS:-1}"

ram_require_cmd() {
  declare missing=0
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Required command not found: ${cmd}" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]]
}

ram_require_file() {
  declare file="$1"
  declare hint="${2:-}"
  if [[ ! -f "$file" ]]; then
    if [[ -n "$hint" ]]; then
      echo "${hint}: ${file}" >&2
    else
      echo "Required file not found: ${file}" >&2
    fi
    return 1
  fi
}

ram_create_namespace() {
  ram_require_cmd kubectl
  kubectl create namespace "$RAM_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "$RAM_NAMESPACE" \
    app.kubernetes.io/part-of=ram-harness \
    ram.redis.com/client=true \
    --overwrite >/dev/null
}

ram_create_monitoring_namespace() {
  ram_require_cmd kubectl
  kubectl create namespace "$RAM_MONITORING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl label namespace "$RAM_MONITORING_NAMESPACE" \
    app.kubernetes.io/part-of=ram-harness \
    --overwrite >/dev/null
}

ram_use_context() {
  declare current_context

  if [[ "${RAM_USE_CURRENT_CONTEXT:-false}" == "true" ]]; then
    return 0
  fi

  current_context="$(kubectl config current-context 2>/dev/null || true)"
  if [[ "$current_context" == "$RAM_KUBE_CONTEXT" ]]; then
    return 0
  fi

  if kubectl config get-contexts "$RAM_KUBE_CONTEXT" >/dev/null 2>&1; then
    kubectl config use-context "$RAM_KUBE_CONTEXT" >/dev/null
  fi
}

ram_find_service() {
  declare namespace="$1"
  declare selector="$2"
  kubectl -n "$namespace" get svc -l "$selector" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

ram_prometheus_service() {
  ram_find_service "$RAM_MONITORING_NAMESPACE" "app=kube-prometheus-stack-prometheus,release=${RAM_MONITORING_RELEASE}"
}

ram_grafana_service() {
  ram_find_service "$RAM_MONITORING_NAMESPACE" "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=${RAM_MONITORING_RELEASE}"
}

ram_sha_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
