#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd kubectl helm
ram_use_context

echo "Context: $(kubectl config current-context 2>/dev/null || echo '<none>')"
echo "Namespace: ${RAM_NAMESPACE}"
echo

echo "Helm releases:"
helm -n "$REDIS_ENTERPRISE_NAMESPACE" list --filter "^${REDIS_ENTERPRISE_OPERATOR_RELEASE}$" || true
helm -n "$RAM_NAMESPACE" list --filter "^${RAM_RELEASE}$" || true
helm -n "$RAM_MONITORING_NAMESPACE" list --filter "^${RAM_MONITORING_RELEASE}$" || true
echo

echo "Redis Enterprise:"
kubectl -n "$REDIS_ENTERPRISE_NAMESPACE" get rec,redb,sts 2>/dev/null || true
echo

echo "RAM:"
kubectl -n "$RAM_NAMESPACE" get deploy,pods,svc -l "app.kubernetes.io/instance=${RAM_RELEASE}" 2>/dev/null || true
echo

echo "Monitoring:"
kubectl -n "$RAM_MONITORING_NAMESPACE" get prometheus,deploy,sts -l "app.kubernetes.io/instance=${RAM_MONITORING_RELEASE}" 2>/dev/null || true
echo

port_status() {
  declare label="$1"
  declare port="$2"
  declare url="$3"

  if ! command -v lsof >/dev/null 2>&1; then
    echo "${label}: local port check unavailable; lsof not found"
    return
  fi

  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "${label}: ${url}"
  else
    echo "${label}: not forwarded"
  fi
}

port_status "RAM API" "$RAM_API_PORT" "http://127.0.0.1:${RAM_API_PORT}"
port_status "Prometheus" "$RAM_PROMETHEUS_PORT" "http://127.0.0.1:${RAM_PROMETHEUS_PORT}"
port_status "Grafana" "$RAM_GRAFANA_PORT" "http://127.0.0.1:${RAM_GRAFANA_PORT}"

if command -v lsof >/dev/null 2>&1; then
  echo "Forwarding command: make port-forward"
fi
