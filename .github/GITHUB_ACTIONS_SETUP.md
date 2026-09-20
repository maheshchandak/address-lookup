# GitHub Actions CI/CD Setup Guide

## Quick Start (5 min)

**Fastest setup using Federated Credentials:**

```powershell
# 1. Create managed identity
az identity create -g rg-address-lookup -n uami-github-actions --location uksouth

# 2. Assign AKS role
$principalId = az identity show -g rg-address-lookup -n uami-github-actions --query principalId --output tsv
az role assignment create --role "Azure Kubernetes Service Cluster Admin" --assignee-object-id $principalId --scope /subscriptions/19f9bf9f-a14a-44be-8ec7-30e9c950ff9c/resourcegroups/rg-address-lookup

# 3. Create federated credential (update YOUR_GITHUB_USERNAME and repo name)
az identity federated-credential create `
  -g rg-address-lookup `
  --identity-name uami-github-actions `
  --name github-actions-fed-cred `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "repo:YOUR_GITHUB_USERNAME/address-lookup:ref:refs/heads/main" `
  --audiences "api://AzureADTokenExchange"

# 4. Get client ID, tenant ID, subscription ID
az identity show -g rg-address-lookup -n uami-github-actions --query clientId --output tsv
az account show --query tenantId --output tsv

# 5. Add to GitHub:
#    - Secrets: ACR_USERNAME, ACR_PASSWORD (from: az acr credential show -n addresslookupacr)
#    - Variables: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID (values from step 4)
```

**Then push code to trigger workflows!**

---

## Overview

Two automated workflows have been created:

1. **build.yml** - Builds and tests on every push
2. **deploy.yml** - Deploys to AKS on push to main branch

---

## Prerequisites

### Option 1: Federated Credentials (Recommended - No Secrets) 🔐

This is the **modern best practice** - GitHub authenticates directly to Azure without storing secrets.

#### Step 1: Create User-Assigned Managed Identity

```powershell
$rg = "rg-address-lookup"
$miName = "uami-github-actions"
$location = "uksouth"

# Create managed identity
az identity create `
  --resource-group $rg `
  --name $miName `
  --location $location

# Get the identity details
$mi = az identity show --resource-group $rg --name $miName --output json | ConvertFrom-Json
$clientId = $mi.clientId
Write-Host "Client ID: $clientId"
Write-Host "Principal ID: $($mi.principalId)"
```

#### Step 2: Assign AKS Admin Role to Managed Identity

```powershell
$principalId = (az identity show -g rg-address-lookup -n uami-github-actions --query principalId --output tsv)
$subscriptionId = "19f9bf9f-a14a-44be-8ec7-30e9c950ff9c"

az role assignment create `
  --role "Azure Kubernetes Service Cluster Admin" `
  --assignee-object-id $principalId `
  --scope /subscriptions/$subscriptionId/resourcegroups/rg-address-lookup
```

#### Step 3: Create Federated Credential

```powershell
$repoOwner = "YOUR_GITHUB_USERNAME"  # Replace with your GitHub username
$repoName = "address-lookup"  # Your repo name
$clientId = "YOUR_CLIENT_ID"  # From step 1

az identity federated-credential create `
  --resource-group rg-address-lookup `
  --identity-name uami-github-actions `
  --name github-actions-fed-cred `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "repo:${repoOwner}/${repoName}:ref:refs/heads/main" `
  --audiences "api://AzureADTokenExchange"

# For all branches (optional):
az identity federated-credential create `
  --resource-group rg-address-lookup `
  --identity-name uami-github-actions `
  --name github-actions-fed-cred-all-branches `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "repo:${repoOwner}/${repoName}:ref:refs/heads/*" `
  --audiences "api://AzureADTokenExchange"
```

#### Step 4: Add GitHub Secrets (ACR Only)

Only ACR credentials needed now:

```
ACR_USERNAME: <your-acr-username>
ACR_PASSWORD: <your-acr-password>
```

**To get ACR credentials:**
```powershell
az acr credential show --resource-group rg-address-lookup --name addresslookupacr
```

**To add to GitHub:**
1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `ACR_USERNAME` / `ACR_PASSWORD`
4. Value: Paste credentials

---

## Comparison: Which Approach?

| Aspect | Federated Credentials | Service Principal | ACR Task |
|--------|----------------------|-------------------|----------|
| **Security** | 🟢 Best (no secrets) | 🟡 Good (secret rotation) | 🟡 Good (webhook token) |
| **Setup Complexity** | 🟡 Medium (5 steps) | 🟢 Simple (2 steps) | 🟡 Medium |
| **Secrets in GitHub** | 🟢 None (only ACR creds) | 🔴 Full credentials | ✅ ACR creds only |
| **Automatic Deployment** | ✅ Yes | ✅ Yes | ✅ Yes (ACR only) |
| **Manual Trigger** | ✅ Yes | ✅ Yes | ❌ No |
| **Token Expiration** | 🟢 Never | 🟡 Manual rotation | 🟡 Manual rotation |
| **Microsoft Recommendation** | ✅ **Recommended** | Supported | Supported |

**Recommendation**: Use **Federated Credentials** for new projects. Migrate from service principal if you have existing workflows.

---

## Switching Between Approaches

### From Service Principal to Federated Credentials

If you've already set up with service principal:

1. **Create managed identity & federated creds** (follow Option 1 above)
2. **Update deploy.yml** (already updated if you used latest version)
3. **Remove `AZURE_CREDENTIALS` secret** from GitHub
4. **Add GitHub Variables** (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID)
5. **Delete old service principal** (optional):
   ```powershell
   az ad sp delete --id <service-principal-object-id>
   ```

### Fallback: Use Service Principal Instead

If you prefer service principal, edit `deploy.yml`:

```yaml
- name: Azure Login (Service Principal)
  uses: azure/login@v2
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

Then follow Option 2 (Service Principal) steps above.

If you prefer service principal approach:

```powershell
# Create service principal
$spName = "github-actions-aks-deploy"
$sp = az ad sp create-for-rbac `
  --name $spName `
  --role "Azure Kubernetes Service Cluster Admin" `
  --scopes /subscriptions/19f9bf9f-a14a-44be-8ec7-30e9c950ff9c

# Output the JSON for GitHub secret
$sp | ConvertTo-Json
```

Add to GitHub Secrets:
1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `AZURE_CREDENTIALS`
4. Value: Paste the JSON output

---

### Option 3: ACR Task Webhook (CI/CD Only)

If you only need ACR builds triggered:
```powershell
# Create ACR task that triggers on git push
az acr task create `
  --registry addresslookupacr `
  --name build-on-push `
  --image address-lookup-api:{{.Run.ID}} `
  --file Dockerfile `
  --git-token YOUR_GITHUB_PAT `
  --context https://github.com/$owner/$repo.git
```

---

## Workflow Details

### Build Workflow (build.yml)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

**Steps:**
1. ✅ Checkout code
2. ✅ Setup .NET 8
3. ✅ Restore NuGet packages
4. ✅ Build solution (Release config)
5. ✅ Run unit tests
6. ✅ Upload test results
7. 📦 Build Docker image (on push to main/develop only)
8. 📤 Push image to ACR with tags:
   - Branch name (e.g., `main`, `develop`)
   - Commit SHA (e.g., `main-abc1234`)
   - Latest (if on default branch)

**Outputs:**
- Test results published in Actions tab
- Docker image pushed to `addresslookupacr.azurecr.io/address-lookup-api`

---

### Deploy Workflow (deploy.yml)

**Triggers:**
- Push to `main` branch
- Manual trigger via `workflow_dispatch`

**Steps:**
1. ✅ Checkout code
2. 🔐 Login to Azure
3. ✅ Get AKS cluster credentials
4. 🐳 Update deployment with new image
5. ⏳ Wait for rollout to complete (5 min timeout)
6. 🏥 Health check (`/health` endpoint)
7. 🧪 Smoke test (`/api/addresses/search` endpoint)
8. 📊 Display pod status and logs
9. ↩️ Automatic rollback on failure
10. 📝 Deployment summary

**Deployment Process:**
```
GitHub Push 
  ↓
Build & Test Workflow
  ↓ (image pushed to ACR)
Deploy Workflow Triggers
  ↓
Update K8s Deployment Image
  ↓
Rolling Update (1 new pod at a time)
  ↓
Health Check
  ↓
Smoke Test
  ↓
Success ✅ or Rollback ↩️
```

---

## Testing the Setup

### Pre-Testing: Verify All Configuration

Before pushing code, verify everything is configured:

**1. Verify Managed Identity Created**
```powershell
az identity show -g rg-address-lookup -n uami-github-actions
# Should show: clientId, principalId, resourceId
```

**2. Verify Role Assignment**
```powershell
$principalId = az identity show -g rg-address-lookup -n uami-github-actions --query principalId --output tsv
az role assignment list --assignee-object-id $principalId --scope /subscriptions/19f9bf9f-a14a-44be-8ec7-30e9c950ff9c/resourcegroups/rg-address-lookup
# Should show: "Azure Kubernetes Service Cluster Admin"
```

**3. Verify Federated Credential**
```powershell
az identity federated-credential list -g rg-address-lookup --identity-name uami-github-actions
# Should show subject like: repo:your-username/address-lookup:ref:refs/heads/main
```

**4. Verify GitHub Secrets/Variables**
- Go to GitHub → Settings → Secrets and variables → Actions
- Secrets section should have: `ACR_USERNAME`, `ACR_PASSWORD`
- Variables section should have: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

---

### 1. Trigger Build Workflow
```bash
# Make a commit to main or develop
git add .
git commit -m "Test CI/CD pipeline"
git push origin main

# Watch in GitHub → Actions tab
```

### 2. Monitor Build
- Click on the running workflow
- Expand each step to see logs
- Tests should pass and image should be pushed

### 3. Monitor Deployment
- Deploy workflow starts automatically after build
- Watch for:
  - ✅ Image deployed
  - ✅ Rollout status
  - ✅ Health checks pass
  - ✅ Smoke tests pass
  - ✅ Deployment summary

### 4. Manual Trigger (optional)
```bash
# Deploy without pushing code
# Go to GitHub → Actions → Deploy to AKS
# Click "Run workflow"
# Select environment and branch
```

---

## Environment Management

### Staging vs Production
The deploy workflow supports multiple environments:

**Development (default):**
- Automatic deploy on push to main
- Quick feedback loop
- No approval required

**Production (manual approval):**
To add production protection:
1. GitHub Settings → Environments → New environment
2. Name: `production`
3. Add "Protection rules" for required reviewers
4. Deploy workflow will pause for approval

---

## Troubleshooting

### Federated Credentials Issues

**Error: "Invalid issuer or subject"**
- Issue: Federated credential subject doesn't match GitHub repo
- Fix: Verify format is exactly: `repo:OWNER/REPO:ref:refs/heads/BRANCH`
- Example: `repo:john-doe/address-lookup:ref:refs/heads/main`
- Check: `az identity federated-credential list -g rg-address-lookup --identity-name uami-github-actions`

**Error: "Token exchange failed"**
- Issue: Azure AD can't authenticate the GitHub token
- Fix: Ensure managed identity has the required Azure roles
- Check: `az role assignment list --assignee-object-id $principalId`
- Must have: `Azure Kubernetes Service Cluster Admin`

**Error: "Principal does not exist"**
- Issue: Managed identity was deleted or permissions not synced
- Fix: Wait 1-2 minutes and retry; Azure caches role assignments
- Or recreate the managed identity

**Error: "Secret or config not found"**
- Issue: GitHub variables/secrets not added correctly
- Fix: Variables are PUBLIC and case-sensitive:
  - `AZURE_CLIENT_ID` (variable, not secret)
  - `AZURE_TENANT_ID` (variable, not secret)
  - `AZURE_SUBSCRIPTION_ID` (variable, not secret)
  - `ACR_USERNAME` (secret)
  - `ACR_PASSWORD` (secret)
- Verify: Settings → Secrets and variables → Actions

**Workflow says "Azure Login failed"**
- Check the full error in Actions logs
- Ensure federated credential issuer is exactly: `https://token.actions.githubusercontent.com`
- Verify tenant ID is correct: `az account show -q tenantId`

### Service Principal Issues
**Check:**
- .NET version compatibility (8.0)
- NuGet package restore
- Unit tests passing locally
- Docker syntax in Dockerfile

**View logs:**
- GitHub Actions tab → Failed workflow → Logs

### Deploy Fails
**Common issues:**

1. **Credential errors**
   ```
   Error: Azure login failed
   Fix: Verify AZURE_CREDENTIALS secret is valid JSON
   ```

2. **Image not found**
   ```
   Error: image addresslookupacr.azurecr.io/address-lookup-api:sha-xxx not found
   Fix: Ensure ACR credentials are correct and build succeeded
   ```

3. **Rollout timeout**
   ```
   Error: Deployment did not complete in 5 minutes
   Fix: Check pod logs for crashes/issues
   kubectl logs deployment/address-lookup-api
   ```

4. **Health check fails**
   ```
   Error: /health endpoint not responding
   Fix: Application may not be ready, check pod logs
   kubectl logs -l app=address-lookup-api
   ```

---

## Manual Deployment (Backup)

If GitHub Actions workflows fail, deploy manually:

```bash
# Get latest image from ACR
az acr repository list --name addresslookupacr

# Manual kubectl update
kubectl set image deployment/address-lookup-api \
  address-lookup-api=addresslookupacr.azurecr.io/address-lookup-api:latest \
  --record

# Monitor rollout
kubectl rollout status deployment/address-lookup-api
```

---

## Next Steps

### Enhancing the Pipelines
1. **Add integration tests** - Test against deployed API
2. **Add performance tests** - Load testing in deploy workflow
3. **Add approval gates** - Require code review before deploy
4. **Add notifications** - Slack/Teams notifications on failure
5. **Add security scanning** - Container scanning, SAST on code
6. **Add monitoring** - Application Insights verification

### Monitoring & Observability
- [ ] Enable Application Insights collection
- [ ] Create Azure Monitor alerts
- [ ] Set up Grafana dashboards
- [ ] Configure log aggregation

---

## Key Files

- `.github/workflows/build.yml` - Build and test pipeline
- `.github/workflows/deploy.yml` - Deployment to AKS
- `Dockerfile` - Container image definition
- `AddressLookup.sln` - .NET solution

---

## Support

For GitHub Actions documentation:
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Azure Login Action](https://github.com/azure/login)
- [Docker Build/Push Action](https://github.com/docker/build-push-action)
- [Azure AKS Deployment](https://learn.microsoft.com/en-us/azure/aks/)
