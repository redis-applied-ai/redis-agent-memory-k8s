#!/usr/bin/env bash
set -euo pipefail

# Terraform and Bicep AKS deployments share the same env vars and cluster shape,
# so the loadtest logic is identical. Delegate to the shared implementation.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aks-loadtest.sh" "$@"
