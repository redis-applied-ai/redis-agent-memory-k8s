#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd kubectl
ram_create_namespace

echo "Applying PodDisruptionBudgets"
kubectl -n "$RAM_NAMESPACE" apply -f "${RAM_ROOT}/k8s/pdb-ram.yaml"

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  echo "Applying ServiceMonitor"
  kubectl -n "$RAM_NAMESPACE" apply -f "${RAM_ROOT}/k8s/servicemonitor-ram.yaml"
else
  echo "Skipping ServiceMonitor: servicemonitors.monitoring.coreos.com CRD is not installed"
fi
