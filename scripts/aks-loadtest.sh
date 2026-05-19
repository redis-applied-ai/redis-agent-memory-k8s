#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

ADMIN_USER="${AKS_ADMIN_USERNAME:-azureuser}"
VM_NAME="${AKS_LOADTEST_VM_NAME:-${AKS_CLUSTER_NAME}-loadtest}"

ram_require_cmd az kubectl

echo "Discovering load test VM public IP (${VM_NAME})..."
VM_IP="$(az vm show \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --name "$VM_NAME" \
  -d --query publicIps -o tsv)"

if [[ -z "$VM_IP" ]]; then
  echo "Error: could not find public IP for VM '${VM_NAME}' in resource group '${AKS_RESOURCE_GROUP}'." >&2
  exit 1
fi

echo "Discovering RAM internal load balancer IP..."
ILB_IP="$(kubectl get service redis-agent-memory-ilb -n "$RAM_NAMESPACE" \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

if [[ -z "$ILB_IP" ]]; then
  echo "Error: ILB service 'redis-agent-memory-ilb' has no IP yet." >&2
  echo "Wait a moment for Azure to provision the internal load balancer, then retry." >&2
  exit 1
fi

echo "Load test VM : ${VM_IP}"
echo "RAM ILB      : http://${ILB_IP}:${RAM_API_PORT}"
echo ""
echo "Uploading locust files to ${ADMIN_USER}@${VM_IP}..."
scp -o StrictHostKeyChecking=no -o BatchMode=yes -r \
  "${RAM_ROOT}/locust" \
  "${ADMIN_USER}@${VM_IP}:~/locust"

echo "Starting Locust (users=${LOCUST_USERS:-100} spawn-rate=${LOCUST_SPAWN_RATE:-10} duration=${LOCUST_DURATION:-10m})..."
ssh -o StrictHostKeyChecking=no -o BatchMode=yes "${ADMIN_USER}@${VM_IP}" \
  "RAM_STORE_ID=${RAM_STORE_ID} \
   locust \
     -f ~/locust/ram_locustfile.py \
     --host http://${ILB_IP}:${RAM_API_PORT} \
     --headless \
     -u ${LOCUST_USERS:-100} \
     -r ${LOCUST_SPAWN_RATE:-10} \
     -t ${LOCUST_DURATION:-10m} \
     --csv /tmp/locust-results \
     --html /tmp/locust-results.html && \
   echo 'Done. Fetch results with:' && \
   echo '  scp ${ADMIN_USER}@${VM_IP}:/tmp/locust-results* results/'"
