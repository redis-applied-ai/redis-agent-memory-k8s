#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

NAMESPACE="$RAM_NAMESPACE"
RELEASE="$RAM_RELEASE"
VALUES="$RAM_VALUES"
LICENSE_FILE="$RAM_LICENSE"
CONFIG_FILE="$RAM_CONFIG_OUTPUT"
CHART="$RAM_CHART"
CHART_VERSION="$RAM_CHART_VERSION"
TIMEOUT="$RAM_HELM_TIMEOUT"

usage() {
  cat <<'USAGE'
Usage: install-ram.sh [options]

Options:
  --namespace ns       Kubernetes namespace. Default: ram-local
  --release name       Helm release. Default: redis-agent-memory
  --values file        Helm values file.
  --license file       License file used only to calculate rollout checksum.
  --config file        Config file used only to calculate rollout checksum.
  --chart chart        Helm chart ref or local path. Default: redis-ai/redis-agent-memory
  --version version    Public chart version. Default: 0.1.0
  --timeout duration   Helm wait timeout. Default: 5m
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --release) RELEASE="$2"; shift 2 ;;
    --values) VALUES="$2"; shift 2 ;;
    --license) LICENSE_FILE="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --chart) CHART="$2"; shift 2 ;;
    --version) CHART_VERSION="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl helm
ram_require_file "$VALUES" "Values file not found"
ram_require_file "$LICENSE_FILE" "License file not found"
ram_require_file "$CONFIG_FILE" "Config file not found. Run ./scripts/render-config.sh first"

LICENSE_CHECKSUM="$(ram_sha_file "$LICENSE_FILE")"
CONFIG_CHECKSUM="$(ram_sha_file "$CONFIG_FILE")"
IMAGE_REPOSITORY="${RAM_IMAGE%:*}"
IMAGE_TAG="${RAM_IMAGE##*:}"
if [[ "$IMAGE_REPOSITORY" == "$IMAGE_TAG" ]]; then
  echo "RAM_IMAGE must include an explicit tag: ${RAM_IMAGE}" >&2
  exit 1
fi

RAM_NAMESPACE="$NAMESPACE"
ram_create_namespace

if [[ "$CHART" == redis-ai/* ]]; then
  helm repo add redis-ai https://helm.redis.io/ai >/dev/null 2>&1 || true
  helm repo update
  VERSION_ARGS=(--version "$CHART_VERSION")
else
  VERSION_ARGS=()
fi

helm upgrade --install "$RELEASE" "$CHART" \
  "${VERSION_ARGS[@]}" \
  -n "$NAMESPACE" \
  -f "$VALUES" \
  --set image.repository="$IMAGE_REPOSITORY" \
  --set image.tag="$IMAGE_TAG" \
  --set license.existingSecretChecksum="$LICENSE_CHECKSUM" \
  --set config.existingSecretChecksum="$CONFIG_CHECKSUM" \
  --rollback-on-failure \
  --wait \
  --timeout "$TIMEOUT"

echo "RAM installed: release=${RELEASE} namespace=${NAMESPACE}"
