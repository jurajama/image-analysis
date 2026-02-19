# Azure Deployment — Image Analysis Web Server

## Overview

This guide deploys `ghcr.io/jurajama/image-analysis:latest` to
**Azure Container Instances (ACI)**. ACI runs a single container directly on
Azure's infrastructure with no VM, cluster, or service plan to manage. It is
billed per second and costs roughly **$0.06/hour** for this workload, making it
ideal for lightweight testing sessions.

---

## Prerequisites

- An Azure subscription ([free tier](https://azure.microsoft.com/free/) works)
- A `bash` shell (Linux, macOS Terminal, or WSL2 on Windows)
- Azure CLI installed (see section 1)
- For private GHCR images only: a GitHub Personal Access Token with
  `read:packages` scope (see section 7)

---

## 1. Install Azure CLI

**Ubuntu / Debian (including WSL2):**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Other platforms:** https://docs.microsoft.com/cli/azure/install-azure-cli

Verify:
```bash
az --version
```

---

## 2. Azure Login

Interactive login (opens browser):
```bash
az login
```

Headless / SSH server login (shows a code to enter at https://microsoft.com/devicelogin):
```bash
az login --use-device-code
```

If you have multiple subscriptions, set the one to use:
```bash
az account list --output table
az account set --subscription "<subscription-id-or-name>"
```

---

## 3. Configure the Script

Open `deploy/deploy-azure.sh` and review the configuration block at the top:

| Variable | Default | Description |
|---|---|---|
| `RESOURCE_GROUP` | `image-analysis-rg` | Azure resource group — container for all resources. Deleting it removes everything. |
| `CONTAINER_NAME` | `image-analysis` | Name for the ACI container instance. |
| `LOCATION` | `eastus` | Azure region. Pick one close to you: `az account list-locations -o table` |
| `IMAGE` | `ghcr.io/jurajama/image-analysis:latest` | Docker image to deploy. |
| `CPU` | `1` | vCPUs allocated to the container. |
| `MEMORY` | `2` | RAM in GB. Keep at **2 or above** — the YOLOv8m model loads ~1.5 GB into RAM at startup. |
| `DNS_LABEL` | `image-analysis` | Prefix for the public FQDN: `<dns-label>.<region>.azurecontainer.io`. **Must be globally unique across Azure.** If deployment fails with a DNS conflict, change this to something unique (e.g. `image-analysis-myname`). |

---

## 4. Run the Deployment

```bash
chmod +x deploy/deploy-azure.sh
./deploy/deploy-azure.sh
```

The script will:
1. Check Azure CLI is available
2. Create the resource group (skips if it already exists)
3. Delete any stale container with the same name (ACI cannot update in place)
4. Deploy a new container instance with a public IP
5. Wait up to 120 seconds for the container to reach `Running` state
6. Print the public URL

Expected final output:
```
==================================================
 Deployment complete.
 Public URL: http://image-analysis.eastus.azurecontainer.io:8080
==================================================
```

---

## 5. Access the Application

Open the printed URL in a browser. You should see the vehicle detection upload form.

**Test via curl:**
```bash
curl http://image-analysis.eastus.azurecontainer.io:8080/
curl -X POST -F "image=@your_photo.jpg" http://image-analysis.eastus.azurecontainer.io:8080/detect
```

> **Note:** On first request after deployment, the container is already warm
> (the YOLOv8m model is baked into the image and pre-loaded at startup), so
> there is no cold-start download delay.

---

## 6. Logs and Monitoring

**Stream live logs:**
```bash
az container logs \
    --resource-group image-analysis-rg \
    --name image-analysis \
    --follow
```

**Check container state:**
```bash
az container show \
    --resource-group image-analysis-rg \
    --name image-analysis \
    --query "instanceView" \
    --output table
```

The container briefly shows `Waiting` while the image is pulled, then
transitions to `Running`. The pull is fast because the image is already
cached in Azure's infrastructure after the first deployment.

---

## 7. Private GHCR Images

The image is currently **public** on GitHub Container Registry and requires no
credentials to pull. If the repository visibility changes to private, ACI will
fail with an authentication error. To fix this:

**Step 1 — Create a GitHub Personal Access Token:**

1. Go to GitHub → Settings → Developer settings → Personal access tokens →
   Tokens (classic)
2. Click "Generate new token (classic)"
3. Set a name (e.g. `azure-aci-pull`), select the `read:packages` scope
4. Copy the generated token (starts with `ghp_`)

**Step 2 — Export credentials before running the script:**
```bash
export GHCR_USER="your-github-username"
export GHCR_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
./deploy/deploy-azure.sh
```

The script automatically adds `--registry-login-server`, `--registry-username`,
and `--registry-password` arguments to `az container create` when these
environment variables are set.

> **Security:** Do not hardcode the token in the script file or commit it to
> git. Use environment variables or a secrets manager.

---

## 8. Tear Down / Cleanup

When you are done testing, delete all Azure resources to stop billing.

**Option A — Use the script's built-in cleanup function:**

Edit `deploy/deploy-azure.sh`, uncomment these two lines near the top, and
re-run:
```bash
# cleanup
# exit 0
```
becomes:
```bash
cleanup
exit 0
```

**Option B — Manual Azure CLI commands:**

Delete only the container (keeps the resource group for future deployments):
```bash
az container delete \
    --resource-group image-analysis-rg \
    --name image-analysis \
    --yes
```

Delete the entire resource group and everything in it:
```bash
az group delete \
    --name image-analysis-rg \
    --yes
```

Resource group deletion runs in the background and takes a few minutes. Billing
stops as soon as the container is deleted.

---

## Troubleshooting

| Error | Likely Cause | Fix |
|---|---|---|
| `DnsNameLabel is already in use` | DNS label already taken by another Azure user | Change `DNS_LABEL` in the script to something unique |
| Container stuck in `Waiting` state | Image pull failing | Run `az container logs` to see the error; for private images, set `GHCR_USER`/`GHCR_TOKEN` |
| Container restarts repeatedly | Out of memory (OOM kill) | Increase `MEMORY` to `3` or `4` in the script |
| `Connection refused` on port 8080 | Container still starting up | Wait 30–60 seconds and retry |
| `az: command not found` | Azure CLI not installed | Follow section 1 |
| `az login` required | Not authenticated | Run `az login` or `az login --use-device-code` |
| `The subscription is not registered to use namespace 'Microsoft.ContainerInstance'` | Resource provider not enabled | Run: `az provider register --namespace Microsoft.ContainerInstance` |

---

## Cost Estimate

Azure Container Instances pricing (East US, approximate):

| Resource | Rate | Cost for 8 hours |
|---|---|---|
| 1 vCPU | ~$0.000014/s | ~$0.40 |
| 2 GB RAM | ~$0.0000015/GB/s | ~$0.09 |
| **Total** | **~$0.06/hour** | **~$0.49** |

Costs are only incurred while the container is running. Deleting the container
immediately stops billing. A typical testing session of a few hours costs less
than $1.
