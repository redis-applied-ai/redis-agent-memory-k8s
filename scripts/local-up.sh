#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

SKIP_PROVISION="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-provision) SKIP_PROVISION="true"; shift ;;
    -h|--help) echo "Usage: local-up.sh [--skip-provision]"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ "$SKIP_PROVISION" != "true" ]]; then
  "${RAM_ROOT}/scripts/kind-up.sh"
fi

"${RAM_ROOT}/scripts/deploy-stack.sh"
