#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

usage() {
  cat <<'USAGE'
Usage: kind-up.sh

Creates or reuses the kind cluster used by this harness.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

ram_require_cmd kind kubectl

if kind get clusters | grep -qx "$RAM_KIND_CLUSTER"; then
  echo "kind cluster exists: ${RAM_KIND_CLUSTER}"
else
  echo "Creating kind cluster: ${RAM_KIND_CLUSTER}"
  kind create cluster --name "$RAM_KIND_CLUSTER" --config "$RAM_KIND_CONFIG"
fi

ram_use_context
