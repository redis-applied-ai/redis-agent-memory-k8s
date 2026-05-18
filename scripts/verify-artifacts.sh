#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ram_require_cmd helm docker

if [[ "$RAM_CHART" == redis-ai/* ]]; then
  helm repo add redis-ai https://helm.redis.io/ai >/dev/null 2>&1 || true
fi
helm repo add redis https://helm.redis.io >/dev/null 2>&1 || true
helm repo update

echo "Checking Helm chart ${RAM_CHART} ${RAM_CHART_VERSION}"
helm show chart "$RAM_CHART" --version "$RAM_CHART_VERSION" >/dev/null

echo "Checking Helm chart ${REDIS_ENTERPRISE_OPERATOR_CHART} ${REDIS_ENTERPRISE_OPERATOR_VERSION}"
helm show chart "$REDIS_ENTERPRISE_OPERATOR_CHART" --version "$REDIS_ENTERPRISE_OPERATOR_VERSION" --devel >/dev/null

echo "Checking RAM image ${RAM_IMAGE}"
docker manifest inspect "$RAM_IMAGE" >/dev/null

echo "Checking Redis Enterprise operator image metadata through Helm chart"
helm template "$REDIS_ENTERPRISE_OPERATOR_RELEASE" "$REDIS_ENTERPRISE_OPERATOR_CHART" \
  --version "$REDIS_ENTERPRISE_OPERATOR_VERSION" \
  --devel \
  -n "$REDIS_ENTERPRISE_NAMESPACE" \
  -f "$REDIS_ENTERPRISE_VALUES" >/dev/null

echo "Artifacts verified"
