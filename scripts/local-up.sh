#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

"${RAM_ROOT}/scripts/kind-up.sh"
"${RAM_ROOT}/scripts/deploy-stack.sh"
