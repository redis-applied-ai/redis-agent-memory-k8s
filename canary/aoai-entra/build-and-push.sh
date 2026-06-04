#!/usr/bin/env bash
set -euo pipefail

# Build the AOAI workload-identity canary image and push it to ACR.
# Reads the ACR name from Terraform output by default. Override via env:
#   ACR_NAME    short name of the ACR (no .azurecr.io suffix)
#   IMAGE_NAME  default: aoai-entra-canary
#   IMAGE_TAG   default: latest
#   PLATFORM    default: linux/amd64  (AKS nodes are amd64; override for arm64 clusters)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform"

ACR_NAME="${ACR_NAME:-}"
if [[ -z "$ACR_NAME" ]]; then
  if ! ACR_NAME="$(terraform -chdir="$TF_DIR" output -raw acr_name 2>/dev/null)"; then
    echo "ACR_NAME not set and terraform output acr_name unavailable. Run 'make up ENV=aks-tf' first or export ACR_NAME." >&2
    exit 1
  fi
fi

IMAGE_NAME="${IMAGE_NAME:-aoai-entra-canary}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PLATFORM="${PLATFORM:-linux/amd64}"

LOGIN_SERVER="${ACR_NAME}.azurecr.io"
FULL_REF="${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Logging into ACR: $ACR_NAME"
az acr login --name "$ACR_NAME"

echo "Building image: $FULL_REF (platform=$PLATFORM)"
docker build --platform "$PLATFORM" -t "$FULL_REF" "$SCRIPT_DIR"

echo "Pushing: $FULL_REF"
docker push "$FULL_REF"

echo "Pushed: $FULL_REF"
