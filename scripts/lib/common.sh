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
RAM_RESULTS_DIR="${RAM_RESULTS_DIR:-${RAM_ROOT}/results}"
RAM_WORKER_REPLICAS="${RAM_WORKER_REPLICAS:-1}"

# AKS defaults
AKS_RESOURCE_GROUP="${AKS_RESOURCE_GROUP:-ram-aks-rg}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-ram-aks}"
AKS_LOCATION="${AKS_LOCATION:-eastus}"
AKS_BICEP_TEMPLATE="${AKS_BICEP_TEMPLATE:-${RAM_ROOT}/infra/aks/main.bicep}"
AKS_SYSTEM_NODE_VM_SIZE="${AKS_SYSTEM_NODE_VM_SIZE:-Standard_D2s_v3}"
AKS_SYSTEM_NODE_COUNT="${AKS_SYSTEM_NODE_COUNT:-2}"
AKS_USER_NODE_VM_SIZE="${AKS_USER_NODE_VM_SIZE:-Standard_E4s_v3}"
AKS_USER_NODE_COUNT="${AKS_USER_NODE_COUNT:-3}"
AKS_ADMIN_SSH_PUBLIC_KEY="${AKS_ADMIN_SSH_PUBLIC_KEY:-}"
AKS_ADMIN_USERNAME="${AKS_ADMIN_USERNAME:-azureuser}"
AKS_LOADTEST_VM_SIZE="${AKS_LOADTEST_VM_SIZE:-Standard_D4_v5}"
AKS_LOADTEST_VM_NAME="${AKS_LOADTEST_VM_NAME:-${AKS_CLUSTER_NAME}-loadtest}"

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

ram_use_context() {
  if [[ "${RAM_USE_CURRENT_CONTEXT:-false}" == "true" ]]; then
    return 0
  fi

  if kubectl config get-contexts "$RAM_KUBE_CONTEXT" >/dev/null 2>&1; then
    kubectl config use-context "$RAM_KUBE_CONTEXT" >/dev/null
  fi
}

ram_sha_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
