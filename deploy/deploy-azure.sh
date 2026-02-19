#!/usr/bin/env bash
# Deploy ghcr.io/jurajama/image-analysis:latest to Azure Container Instances.
# See deploy/AZURE_DEPLOYMENT.md for full instructions.
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
RESOURCE_GROUP="image-analysis-rg"
CONTAINER_NAME="image-analysis"
LOCATION="eastus"                          # az account list-locations -o table
IMAGE="ghcr.io/jurajama/image-analysis:latest"
PORT=8080
CPU=1                                      # vCPUs
MEMORY=2                                   # GB — YOLOv8m loads ~1.5 GB RAM
DNS_LABEL="${CONTAINER_NAME}"              # must be globally unique across Azure
                                           # becomes <dns>.<region>.azurecontainer.io

# ── GHCR credentials (only needed if the image is private) ────────────────────
# Leave blank for public images.
# For private images, export these before running:
#   export GHCR_USER="your-github-username"
#   export GHCR_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"  # PAT with read:packages scope
GHCR_USER="${GHCR_USER:-}"
GHCR_TOKEN="${GHCR_TOKEN:-}"

# ── Cleanup function ──────────────────────────────────────────────────────────
# Deletes the container and resource group.
# To tear down: uncomment the two lines below, then run the script.
cleanup() {
    echo "Deleting container '${CONTAINER_NAME}'..."
    az container delete \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${CONTAINER_NAME}" \
        --yes
    echo "Deleting resource group '${RESOURCE_GROUP}' (runs in background)..."
    az group delete \
        --name "${RESOURCE_GROUP}" \
        --yes \
        --no-wait
    echo "Cleanup initiated."
}
# cleanup
# exit 0

# ── Preflight check ───────────────────────────────────────────────────────────
if ! az --version > /dev/null 2>&1; then
    echo "ERROR: Azure CLI not found. Install it with:"
    echo "  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    exit 1
fi

echo "Using image: ${IMAGE}"
echo "Resource group: ${RESOURCE_GROUP} (${LOCATION})"
echo "Container: ${CONTAINER_NAME}"
echo ""

# ── Resource group ────────────────────────────────────────────────────────────
if ! az group show --name "${RESOURCE_GROUP}" &>/dev/null; then
    echo "Creating resource group '${RESOURCE_GROUP}' in '${LOCATION}'..."
    az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none
else
    echo "Resource group '${RESOURCE_GROUP}' already exists, skipping creation."
fi

# ── Remove stale container (ACI cannot update in place) ───────────────────────
if az container show --resource-group "${RESOURCE_GROUP}" --name "${CONTAINER_NAME}" &>/dev/null; then
    echo "Existing container found; deleting before redeploy..."
    az container delete \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${CONTAINER_NAME}" \
        --yes
fi

# ── Optional GHCR registry credentials ───────────────────────────────────────
REGISTRY_ARGS=()
if [[ -n "${GHCR_USER}" && -n "${GHCR_TOKEN}" ]]; then
    echo "GHCR credentials provided — using authenticated pull."
    REGISTRY_ARGS+=(--registry-login-server ghcr.io)
    REGISTRY_ARGS+=(--registry-username "${GHCR_USER}")
    REGISTRY_ARGS+=(--registry-password "${GHCR_TOKEN}")
fi

# ── Deploy ────────────────────────────────────────────────────────────────────
echo "Deploying container '${CONTAINER_NAME}'..."
az container create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CONTAINER_NAME}" \
    --image "${IMAGE}" \
    --cpu "${CPU}" \
    --memory "${MEMORY}" \
    --ports "${PORT}" \
    --ip-address Public \
    --dns-name-label "${DNS_LABEL}" \
    --os-type Linux \
    --restart-policy OnFailure \
    --output none \
    "${REGISTRY_ARGS[@]}"

# ── Wait for running state ────────────────────────────────────────────────────
echo "Waiting for container to reach 'Running' state (up to 120 s)..."
for i in {1..24}; do
    state=$(az container show \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${CONTAINER_NAME}" \
        --query "instanceView.state" \
        --output tsv 2>/dev/null || echo "Unknown")
    echo "  [${i}] State: ${state}"
    if [[ "${state}" == "Running" ]]; then break; fi
    sleep 5
done

# ── Print access URL ──────────────────────────────────────────────────────────
FQDN=$(az container show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CONTAINER_NAME}" \
    --query "ipAddress.fqdn" \
    --output tsv)

echo ""
echo "=================================================="
echo " Deployment complete."
echo " Public URL: http://${FQDN}:${PORT}"
echo "=================================================="
echo ""
echo "Test with:"
echo "  curl http://${FQDN}:${PORT}/"
echo "  curl -X POST -F 'image=@photo.jpg' http://${FQDN}:${PORT}/detect"
echo ""
echo "View logs:"
echo "  az container logs --resource-group ${RESOURCE_GROUP} --name ${CONTAINER_NAME} --follow"
echo ""
echo "To tear down when done:"
echo "  Uncomment 'cleanup' near the top of this script and re-run, or:"
echo "  az group delete --name ${RESOURCE_GROUP} --yes"
