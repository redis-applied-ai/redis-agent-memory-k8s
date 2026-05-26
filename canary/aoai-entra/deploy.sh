#!/usr/bin/env bash
set -euo pipefail

# Render the canary manifest with values from Terraform outputs and apply it.
# Run build-and-push.sh first so the image exists in ACR.
#
# Optional env:
#   IMAGE_NAME  default: aoai-entra-canary
#   IMAGE_TAG   default: latest
#   KUBECTL     default: kubectl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform"
MANIFEST="$SCRIPT_DIR/k8s/canary.yaml"

KUBECTL="${KUBECTL:-kubectl}"
IMAGE_NAME="${IMAGE_NAME:-aoai-entra-canary}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

tf_output() {
  terraform -chdir="$TF_DIR" output -raw "$1"
}

ACR_LOGIN_SERVER="$(tf_output acr_login_server)"
AOAI_ENDPOINT="$(tf_output openai_endpoint)"
EMBED_DEPLOYMENT="$(tf_output openai_embedding_deployment_name)"
CLIENT_ID="$(tf_output ram_identity_client_id)"
TENANT_ID="$(tf_output ram_identity_tenant_id)"
NAMESPACE="$(tf_output canary_namespace)"
SERVICE_ACCOUNT="$(tf_output canary_service_account_name)"

IMAGE_REF="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'
}

sed \
  -e "s|REPLACE_WITH_NAMESPACE|$(escape_sed "$NAMESPACE")|g" \
  -e "s|REPLACE_WITH_SERVICE_ACCOUNT|$(escape_sed "$SERVICE_ACCOUNT")|g" \
  -e "s|REPLACE_WITH_CLIENT_ID|$(escape_sed "$CLIENT_ID")|g" \
  -e "s|REPLACE_WITH_TENANT_ID|$(escape_sed "$TENANT_ID")|g" \
  -e "s|REPLACE_WITH_IMAGE|$(escape_sed "$IMAGE_REF")|g" \
  -e "s|REPLACE_WITH_AOAI_ENDPOINT|$(escape_sed "$AOAI_ENDPOINT")|g" \
  -e "s|REPLACE_WITH_EMBED_DEPLOYMENT|$(escape_sed "$EMBED_DEPLOYMENT")|g" \
  "$MANIFEST" | "$KUBECTL" apply -f -

echo
echo "Applied. Tail logs with:"
echo "  $KUBECTL -n $NAMESPACE logs -l app=aoai-entra-canary -f"
