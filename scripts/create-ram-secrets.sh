#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

NAMESPACE="$RAM_NAMESPACE"
LICENSE_FILE="$RAM_LICENSE"
CONFIG_FILE="$RAM_CONFIG_OUTPUT"

usage() {
  cat <<'USAGE'
Usage: create-ram-secrets.sh [--namespace ns] [--license file] [--config file]

Creates/updates:
  Secret ram-license with key license
  Secret ram-config with key memory-dataplane.config.yaml
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --license) LICENSE_FILE="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kubectl
ram_require_file "$LICENSE_FILE" "License file not found"
ram_require_file "$CONFIG_FILE" "Config file not found. Run ./scripts/render-config.sh first"

RAM_NAMESPACE="$NAMESPACE"
ram_create_namespace

kubectl -n "$NAMESPACE" create secret generic ram-license \
  --from-file=license="$LICENSE_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NAMESPACE" create secret generic ram-config \
  --from-file=memory-dataplane.config.yaml="$CONFIG_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "RAM secrets applied in namespace ${NAMESPACE}"
