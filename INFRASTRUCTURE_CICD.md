# Infrastructure & Application CI/CD Pipelines

Complete automation for provisioning, deploying, and tearing down AKS infrastructure and application on-demand using GitHub Actions and Azure Bicep.

## Quick Start

### 1. Deploy Everything On-Demand (Provision + Deploy)

```bash
# Go to GitHub Actions → "On-Demand: Provision & Deploy"
# Click "Run workflow"
# Select:
# - Environment: dev
# - Region: uksouth
# - Node Count: 1
# Wait ~15-20 minutes
# Access API at: http://<LoadBalancer-IP>/api/addresses/search?postcode=SW1A1AA
```

### 2. Tear Down (Save Costs)

```bash
# Go to GitHub Actions → "Teardown Infrastructure"
# Click "Run workflow"
# Type "yes" to confirm
# Wait ~5-10 minutes for deletion
# All resources deleted, no more costs
```

### 3. Add Secrets to Key Vault

```bash
# After infrastructure is provisioned, add the Postcodes.io API secret:

# Option A: Using Azure CLI
az keyvault secret set \
  --vault-name kv-address-lookup-<unique-suffix> \
  --name PostcodesIOApiUrl \
  --value "https://api.postcodes.io"

# Option B: Using Azure Portal
# 1. Go to Azure Portal → Search "kv-address-lookup"
# 2. Click Key Vault resource
# 3. Left menu → "Secrets"
# 4. Click "+ Generate/Import"
# 5. Name: PostcodesIOApiUrl
# 6. Value: https://api.postcodes.io
# 7. Click "Create"

# Find the Key Vault name:
# GitHub Actions workflow output shows: keyVaultName
# Or use: az keyvault list --query "[].name"
```

### 4. For Development (Continuous Deployment)

```bash
# After infrastructure is provisioned and secrets added:
# Just push to master branch
# build.yml runs automatically
# deploy.yml runs automatically
# Application updated in AKS
# No infrastructure wait time
```

---

## Workflows Overview

### 📦 Build & Test Workflow (`build.yml`)

**Trigger**: Push to master branch or pull requests

**What it does**:
1. Checks out code
2. Restores NuGet packages (.NET dependencies)
3. Builds application (Release configuration)
4. Runs xUnit tests with TRX output
5. Publishes test results as GitHub checks
6. Builds multi-stage Docker image
7. Authenticates to Azure Container Registry
8. Pushes image with tags: `latest`, `master-<commit-sha>`, `master`

**Output**: Docker image in ACR with multiple tags

**Duration**: ~5-10 minutes

**Status**: ✅ Fully working

---

### 🚀 Deploy Application Workflow (`deploy.yml`)

**Trigger**: Automatically when build.yml succeeds (workflow_run)

**What it does**:
1. Authenticates to Azure via OIDC federated credentials
2. Gets AKS cluster credentials
3. Extracts image tag (`latest`)
4. Updates AKS deployment with new image via `kubectl set image`
5. Waits for rollout to complete (5 minute timeout)
6. Gets LoadBalancer IP address
7. Runs health check against `/health` endpoint (60 seconds, 5s intervals)
8. Runs smoke test against `/api/addresses/search` (verifies data returned)
9. If any step fails, automatically rolls back to previous image version

**Output**: Application running in AKS, accessible via LoadBalancer IP

**Duration**: ~3-5 minutes

**Status**: ✅ Fully working

**Success Indicators**:
```
✅ Pod running (1/1 Ready)
✅ Service LoadBalancer IP assigned
✅ Health check passing (200 OK)
✅ Smoke test passing (returns address data)
```

---

### 🏗️ Provision Infrastructure Workflow (`infra-provision.yml`)

**Trigger**: Manual on-demand (workflow_dispatch)

**Inputs**:
- **Environment**: `dev`, `staging`, or `prod`
- **Region**: Azure region (default: `uksouth`)
- **Node Count**: Number of AKS nodes (default: `1`)

**What it does**:
1. Authenticates to Azure via OIDC federated credentials
2. Creates resource group: `rg-address-lookup`
3. Validates Bicep templates
4. Deploys infrastructure using `infra/main.bicep`:
   - AKS cluster (1.37.0 Kubernetes)
   - Azure Container Registry (Basic tier)
   - Key Vault (for secrets management)
   - Virtual Network (10.0.0.0/16 CIDR)
   - Log Analytics Workspace
   - Application Insights
   - Managed Identity for authentication
5. Gets AKS cluster credentials
6. Verifies cluster health
7. Creates ACR credentials as Kubernetes secret

**Output**:
- AKS cluster ready for deployment
- ACR ready to push/pull images
- All infrastructure deployed
- Cluster credentials available

**Duration**: ~10-15 minutes

**Status**: ✅ Ready for use

**Cost Implications**:
- AKS cluster: ~$0.73/hour (1 node, D2s_v3)
- ACR: ~$5/month (Basic tier)
- Key Vault: ~$0.34/month (minimal usage)
- Total: ~$25-30/month for dev environment

---

### 🗑️ Teardown Infrastructure Workflow (`infra-teardown.yml`)

**Trigger**: Manual on-demand (workflow_dispatch)

**Safety Feature**: Requires typing "yes" to confirm deletion

**What it does**:
1. Authenticates to Azure via OIDC federated credentials
2. Checks if resource group exists
3. Deletes entire resource group: `rg-address-lookup`
   - AKS cluster
   - Container Registry
   - Key Vault
   - Virtual Network
   - Managed Identity
   - Log Analytics Workspace
   - Application Insights
   - All related disks and storage
4. Deletion runs asynchronously in Azure (5-10 minutes)

**Output**: All resources deleted, no recurring costs

**Duration**: ~5-10 minutes for completion

**Status**: ✅ Ready for use

**Cost Savings**: Eliminates ~$25-30/month infrastructure costs

---

### 🔄 On-Demand Provision & Deploy Workflow (`on-demand-deploy.yml`)

**Trigger**: Manual on-demand (workflow_dispatch)

**Inputs**:
- **Environment**: `dev`, `staging`, or `prod`
- **Region**: Azure region (default: `uksouth`)
- **Node Count**: Number of AKS nodes (default: `1`)
- **Skip Infrastructure**: Use existing infrastructure (optional)

**What it does** (complete automation):
1. **Check Infrastructure**: Verifies if AKS cluster exists
2. **Provision** (if needed):
   - Creates resource group
   - Deploys Bicep infrastructure
   - ~10-15 minutes
3. **Build**: 
   - Compiles .NET application
   - Runs unit tests
   - ~5 minutes
4. **Build Image**:
   - Creates multi-stage Docker image
   - Pushes to ACR
   - ~3 minutes
5. **Deploy**:
   - Updates AKS deployment
   - Waits for rollout
   - Runs health checks
   - Runs smoke tests
   - ~3-5 minutes
6. **Report**:
   - LoadBalancer IP
   - API endpoint
   - Access instructions

**Output**: 
- Infrastructure provisioned
- Application built and tested
- Image in registry
- Pods running in AKS
- LoadBalancer IP with external access

**Total Duration**: ~25-30 minutes (first run, includes infrastructure)
**Duration**: ~10-15 minutes (subsequent runs with existing infrastructure)

**Status**: ✅ Ready for production deployments

**Perfect for**:
- On-demand testing environments
- Load testing sessions
- Demo/presentation environments
- Production deployments with infrastructure recreation

---

## Authentication & Security

### OIDC Federated Credentials (No Secrets!)

All workflows use **Azure OIDC token exchange** for authentication. No secrets stored in GitHub.

**How it works**:
1. GitHub Actions generates a OIDC token for this repository
2. Token is exchanged for Azure credentials
3. Workflows authenticate as managed identity: `uami-github-actions`
4. No credentials stored anywhere

**Security Benefits**:
- ✅ No secrets to steal from GitHub
- ✅ No secret rotation needed
- ✅ Token includes immutable repo ID (prevents reuse if repo transferred)
- ✅ RBAC controls what identity can do
- ✅ Audit trail in Azure Activity Log

**Credentials Setup** (already configured):

GitHub Variables:
- `AZURE_CLIENT_ID`: Managed identity client ID
- `AZURE_TENANT_ID`: Azure tenant ID
- `AZURE_SUBSCRIPTION_ID`: Subscription ID

GitHub Secrets:
- `ACR_USERNAME`: For Docker push (alternative auth)
- `ACR_PASSWORD`: For Docker push (alternative auth)

---

## Secrets Management

### How Application Uses Secrets

Your application uses `DefaultAzureCredential` which automatically reads secrets from:

1. **Local Development**: User Secrets (Secret Manager)
2. **AKS Production**: Key Vault (via managed identity)

The application expects this secret:
```
Key Vault Secret Name: PostcodesIOApiUrl
Value: https://api.postcodes.io (or your API endpoint)
```

### Add Secret After Infrastructure Provisioning

**Step 1: Get the Key Vault Name**

From workflow output or run:
```bash
# List all key vaults
az keyvault list --query "[].name" -o table

# Or get from resource group
az keyvault list --resource-group rg-address-lookup --query "[].name" -o table
```

**Step 2: Add the Secret**

**Method A: Azure CLI (Recommended)**
```bash
az keyvault secret set \
  --vault-name kv-address-lookup-<unique-suffix> \
  --name PostcodesIOApiUrl \
  --value "https://api.postcodes.io"

# Verify it was added
az keyvault secret show \
  --vault-name kv-address-lookup-<unique-suffix> \
  --name PostcodesIOApiUrl
```

**Method B: Azure Portal**
1. Go to [Azure Portal](https://portal.azure.com)
2. Search for "kv-address-lookup"
3. Click the Key Vault resource
4. Left menu → **Secrets**
5. Click **+ Generate/Import**
6. Fill in:
   - Name: `PostcodesIOApiUrl`
   - Value: `https://api.postcodes.io`
7. Click **Create**

**Method C: PowerShell**
```powershell
Set-AzKeyVaultSecret -VaultName "kv-address-lookup-<unique-suffix>" `
  -Name "PostcodesIOApiUrl" `
  -SecretValue (ConvertTo-SecureString "https://api.postcodes.io" -AsPlainText -Force)
```

**Step 3: Verify Application Can Access Secret**

Check pod logs to confirm application is reading the secret:
```bash
kubectl logs deployment/address-lookup-api --tail=50

# Should show successful startup without auth errors
```

If secret is missing, you'll see in logs:
```
Secret 'PostcodesIOApiUrl' not found in Key Vault
```

### Secret Update Process

**To update a secret in production:**

```bash
# Update the secret
az keyvault secret set \
  --vault-name kv-address-lookup-<unique-suffix> \
  --name PostcodesIOApiUrl \
  --value "https://new-api-endpoint.com"

# Restart pods to pick up new value
kubectl rollout restart deployment/address-lookup-api

# Verify new pods running
kubectl get pods
```

### Security Best Practices

✅ **Do:**
- Store all API keys and URLs in Key Vault (never in code)
- Rotate secrets periodically
- Use RBAC to limit who can read secrets
- Enable Key Vault audit logging
- Use managed identities for authentication

❌ **Don't:**
- Store secrets in environment variables (visible in pod spec)
- Commit secrets to Git
- Share Key Vault keys via email/chat
- Use hardcoded credentials in container images

---

## Workflow Triggers

### Automatic Triggers

**build.yml**:
```
- Push to master branch
- Pull requests to master branch
```

**deploy.yml**:
```
- Successful build.yml completion
- Only on master branch
- Only if all build steps passed
```

### Manual Triggers (Workflow Dispatch)

**infra-provision.yml**:
```
GitHub Actions → "Provision Infrastructure" → "Run workflow"
```

**infra-teardown.yml**:
```
GitHub Actions → "Teardown Infrastructure" → "Run workflow"
Type "yes" to confirm
```

**on-demand-deploy.yml**:
```
GitHub Actions → "On-Demand: Provision & Deploy" → "Run workflow"
```

---

## Cost Optimization Patterns

### Pattern 1: Development with On-Demand Infrastructure

```
Monday:
  → Run "On-Demand: Provision & Deploy"
  → Development/testing for 8 hours
  → Run "Teardown Infrastructure"
  Cost: ~$0.30 (1 day)

Tuesday:
  → Run "On-Demand: Provision & Deploy"
  → Different testing scenario
  → Run "Teardown Infrastructure"
  Cost: ~$0.30 (1 day)

Per Month: ~$6-8 (much cheaper than persistent $25-30/month)
```

### Pattern 2: Persistent Development Environment

```
Keep infrastructure provisioned:
  → Run "On-Demand: Provision & Deploy" once
  → Push code changes to master
  → Auto build and deploy
  → After development, run "Teardown Infrastructure"
Cost: Only pay while developing
```

### Pattern 3: CI/CD with Automatic Deployments

```
Infrastructure provisioned:
  → Developers push to master
  → build.yml runs automatically
  → deploy.yml runs automatically
  → Application updated in AKS
  → No manual intervention
Cost: Persistent (like traditional CI/CD)
```

---

## Monitoring & Troubleshooting

### View Workflow Status

1. Go to GitHub repository
2. Click "Actions" tab
3. Select workflow name
4. Click on specific run
5. View logs and step details

### View Deployment Status in AKS

```bash
# Check pod status
kubectl get pods

# Check deployment status
kubectl get deployment address-lookup-api

# View pod logs
kubectl logs deployment/address-lookup-api

# Check rollout history
kubectl rollout history deployment/address-lookup-api

# Describe pod for events
kubectl describe pod <pod-name>
```

### View Infrastructure in Azure Portal

**Your Resource Group:**
```
Search for: "rg-address-lookup"
Shows all resources:
- AKS cluster (aks-address-lookup)
- ACR (addresslookupacr)
- Key Vault
- Virtual Network
- Log Analytics Workspace
- Application Insights
```

**AKS Managed Resource Group (Auto-Created by Azure):**
```
You'll also see: MC_rg-address-lookup_aks-address-lookup_uksouth
- Contains: Worker VMs, network interfaces, disks, load balancers
- Managed by: Azure (don't edit manually)
- Deleted automatically: When you tear down rg-address-lookup
```

Both resource groups will appear in your subscription's resource group list.

### Common Issues

**Issue**: Deployment times out
- Check: `kubectl get pods` - is new pod pending?
- Check: Pod events - `kubectl describe pod <pod-name>`
- Check: Image pull errors - is image in ACR?
- Solution: Delete stuck pod - `kubectl delete pod <pod-name>`

**Issue**: Health check failing
- Check: Pod logs - `kubectl logs deployment/address-lookup-api`
- Check: API endpoint - `curl http://<IP>/health`
- Check: Network connectivity - security groups, NSG rules

**Issue**: Application can't access Key Vault secrets
- Check: Pod logs for "Secret not found" or auth errors
- Verify: Secret exists - `az keyvault secret show --vault-name <kv-name> --name PostcodesIOApiUrl`
- Verify: Managed identity has permissions - check Key Vault access policies
- Solution: Add the secret using steps in "Secrets Management" section above

**Issue**: Managed identity can't read Key Vault
- Check: Key Vault access policies - managed identity must be listed
- Check: Identity has "get" and "list" permissions on secrets
- Solution: 
  ```bash
  az keyvault set-policy \
    --name kv-address-lookup-<suffix> \
    --object-id <managed-identity-principal-id> \
    --secret-permissions get list
  ```

**Issue**: Teardown not completing
- Check: Azure Portal for stuck deletions
- Check: Activity Log for detailed errors
- Solution: Manual deletion via portal if needed

---

## Infrastructure Details

### Resource Group
- **Name**: `rg-address-lookup`
- **Location**: `uksouth` (customizable)
- **Lifecycle**: On-demand creation/deletion
- **Contents**: AKS cluster, ACR, Key Vault, VNet, Managed Identity, Monitoring

### AKS Managed Resource Group (Auto-Generated)
- **Name**: `MC_rg-address-lookup_aks-address-lookup_uksouth`
- **Created by**: Azure automatically when AKS cluster is created
- **Managed by**: Azure (you don't manage this directly)
- **Contents**: Worker VMs, network interfaces, storage disks, load balancer resources
- **Deletion**: Automatically deleted when you tear down `rg-address-lookup`
- **Important**: Don't manually edit resources in this group; Azure manages them

**What you'll see in Azure Portal:**
```
Your Resource Groups:
  ├─ rg-address-lookup (you control this)
  └─ MC_rg-address-lookup_aks-address-lookup_uksouth (Azure manages this)
```

Both are deleted when you run the teardown workflow.

### AKS Cluster
- **Name**: `aks-address-lookup`
- **Kubernetes Version**: `1.37.0`
- **VM Size**: `Standard_D2s_v3` (2 vCPU, 8GB RAM)
- **Node Count**: Configurable (default: 1)
- **Networking**: Azure CNI with Overlay mode
- **Service CIDR**: `10.1.0.0/16`
- **Pod Subnet**: `10.0.1.0/24`

### Azure Container Registry
- **Name**: `addresslookupacr`
- **Tier**: Basic
- **Networking**: Public access (configurable)
- **Repositories**: `address-lookup-api`

### Key Vault
- **Naming**: `kv-address-lookup-<unique-suffix>`
- **SKU**: Standard
- **Access**: RBAC via managed identity

### Virtual Network
- **CIDR**: `10.0.0.0/16`
- **Subnets**:
  - `aks-subnet`: `10.0.1.0/24`
  - `vm-subnet`: `10.0.2.0/24`
- **Service Endpoints**: ACR, Key Vault, Storage

### Managed Identity
- **Name**: `uami-github-actions`
- **Role**: Contributor on subscription
- **Used by**: GitHub Actions workflows, AKS pods

### Monitoring
- **Log Analytics Workspace**: Retention: 30 days
- **Application Insights**: Instrumentation Key exported
- **Retention**: 30 days (customizable)

---

## Next Steps

1. **Provision Infrastructure**:
   ```
   GitHub Actions → "On-Demand: Provision & Deploy" → Run
   Wait ~20 minutes for completion
   ```

2. **Add Secrets to Key Vault**:
   ```bash
   # Get Key Vault name from workflow output
   az keyvault secret set \
     --vault-name kv-address-lookup-<unique-suffix> \
     --name PostcodesIOApiUrl \
     --value "https://api.postcodes.io"
   ```

3. **Restart Application Pods** (to pick up secrets):
   ```bash
   kubectl rollout restart deployment/address-lookup-api
   kubectl get pods  # Wait for new pods to be Ready
   ```

4. **Test API**:
   ```bash
   curl http://<LoadBalancer-IP>/api/addresses/search?postcode=SW1A1AA
   ```

5. **Make Changes & Deploy**:
   ```bash
   git push origin master
   build.yml + deploy.yml run automatically
   ```

6. **Save Costs**:
   ```bash
   GitHub Actions → "Teardown Infrastructure" → Run (type "yes")
   ```

---

## Documentation

- **Kubernetes Deployment**: `.github/kubernetes/deployment.yaml`
- **Infrastructure as Code**: `infra/main.bicep`, `infra/main.bicepparam`
- **Workflow Details**: `.github/workflows/*.yml`
- **Project Phases**: `PHASES_SIMPLIFIED.md`

---

## Support

For issues:
1. Check workflow logs in GitHub Actions
2. Check pod logs: `kubectl logs deployment/address-lookup-api`
3. Check Activity Log in Azure Portal
4. Review troubleshooting section above
5. Verify secrets in Key Vault: `az keyvault secret list --vault-name <kv-name>`
