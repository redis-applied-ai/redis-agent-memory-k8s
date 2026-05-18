#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: down.sh [--delete-cluster] [--keep-redis]

Uninstalls RAM and removes local Redis resources. The kind cluster is kept
unless --delete-cluster is passed.
USAGE
}

DELETE_CLUSTER="false"
KEEP_REDIS="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete-cluster) DELETE_CLUSTER="true"; shift ;;
    --keep-redis) KEEP_REDIS="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl helm

if helm -n "$RAM_NAMESPACE" status "$RAM_RELEASE" >/dev/null 2>&1; then
  helm -n "$RAM_NAMESPACE" uninstall "$RAM_RELEASE"
else
  echo "Helm release not found: ${RAM_RELEASE}"
fi

kubectl -n "$RAM_NAMESPACE" delete -f "${RAM_ROOT}/k8s/pdb-ram.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  kubectl -n "$RAM_NAMESPACE" delete -f "${RAM_ROOT}/k8s/servicemonitor-ram.yaml" --ignore-not-found=true >/dev/null 2>&1 || true
fi

if [[ "$KEEP_REDIS" != "true" ]]; then
  if kubectl get crd redisenterprisedatabases.app.redislabs.com >/dev/null 2>&1; then
    kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" delete -f "$REDIS_ENTERPRISE_DATABASES" --ignore-not-found=true || true
  fi
  if helm -n "$REDIS_ENTERPRISE_NAMESPACE" status "$REDIS_ENTERPRISE_OPERATOR_RELEASE" >/dev/null 2>&1; then
    helm -n "$REDIS_ENTERPRISE_NAMESPACE" uninstall "$REDIS_ENTERPRISE_OPERATOR_RELEASE" || true
  fi
  kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" delete pvc -l app=redis-enterprise --ignore-not-found=true || true
fi

if [[ "$DELETE_CLUSTER" == "true" ]]; then
  ram_require_cmd kind
  kind delete cluster --name "$RAM_KIND_CLUSTER"
fi
