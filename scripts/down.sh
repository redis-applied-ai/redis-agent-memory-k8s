#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: down.sh [--delete-cluster]

Uninstalls monitoring and RAM, then removes Redis resources. The kind cluster
is kept unless --delete-cluster is passed.
USAGE
}

DELETE_CLUSTER="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete-cluster) DELETE_CLUSTER="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl helm
ram_use_context

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  kubectl -n "$RAM_NAMESPACE" delete servicemonitor redis-agent-memory redis-enterprise --ignore-not-found=true >/dev/null 2>&1 || true
fi
kubectl -n "$RAM_MONITORING_NAMESPACE" delete configmap \
  -l app.kubernetes.io/part-of=ram-harness,grafana_dashboard=1 \
  --ignore-not-found=true >/dev/null 2>&1 || true

if helm -n "$RAM_MONITORING_NAMESPACE" status "$RAM_MONITORING_RELEASE" >/dev/null 2>&1; then
  helm -n "$RAM_MONITORING_NAMESPACE" uninstall "$RAM_MONITORING_RELEASE" || true
else
  echo "Monitoring release not found: ${RAM_MONITORING_RELEASE}"
fi

if helm -n "$RAM_NAMESPACE" status "$RAM_RELEASE" >/dev/null 2>&1; then
  helm -n "$RAM_NAMESPACE" uninstall "$RAM_RELEASE"
else
  echo "Helm release not found: ${RAM_RELEASE}"
fi

kubectl -n "$RAM_NAMESPACE" delete pdb redis-agent-memory-server redis-agent-memory-worker --ignore-not-found=true >/dev/null 2>&1 || true

if kubectl get crd redisenterprisedatabases.app.redislabs.com >/dev/null 2>&1; then
  kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" delete -f "$REDIS_ENTERPRISE_DATABASES" --ignore-not-found=true || true
fi
if helm -n "$REDIS_ENTERPRISE_NAMESPACE" status "$REDIS_ENTERPRISE_OPERATOR_RELEASE" >/dev/null 2>&1; then
  helm -n "$REDIS_ENTERPRISE_NAMESPACE" uninstall "$REDIS_ENTERPRISE_OPERATOR_RELEASE" || true
fi
kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" delete pvc -l app=redis-enterprise --ignore-not-found=true || true

if [[ "$DELETE_CLUSTER" == "true" ]]; then
  ram_require_cmd kind
  kind delete cluster --name "$RAM_KIND_CLUSTER"
fi
