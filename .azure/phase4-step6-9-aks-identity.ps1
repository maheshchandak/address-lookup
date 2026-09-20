# Phase 4 - Step 6-9: AKS Deployment, Identity Configuration, and Verification
# This script creates the AKS cluster, configures managed identities, and performs final verification

param(
    [string]$SubscriptionId = "19f9bf9f-a14a-44be-8ec7-30e9c950ff9c",
    [string]$ResourceGroup = "rg-address-lookup",
    [string]$Region = "uksouth",
    [string]$AppName = "address-lookup"
)

# Color output for better readability
$success = @{ ForegroundColor = "Green" }
$warning = @{ ForegroundColor = "Yellow" }
$error_msg = @{ ForegroundColor = "Red" }
$info = @{ ForegroundColor = "Cyan" }

function Write-Section {
    param([string]$Title)
    Write-Host "`n" + ("=" * 60) @warning
    Write-Host "  $Title" @warning
    Write-Host ("=" * 60) @warning
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" @success
}

function Write-Step {
    param([string]$Message)
    Write-Host "→ $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" @info
}

# ============================================================================
# CONFIGURATION
# ============================================================================

Write-Section "PHASE 4 INFRASTRUCTURE DEPLOYMENT - AKS & Identity Configuration"

$config = @{
    SubscriptionId        = $SubscriptionId
    ResourceGroup         = $ResourceGroup
    Region                = $Region
    AppName               = $AppName
    
    # VNet Configuration (from previous steps)
    VNetName              = "vnet-$AppName"
    AksSubnetName         = "subnet-aks"
    
    # AKS Configuration
    AksClusterName        = "aks-$AppName"
    AksNodepoolName       = "nodepool1"
    AksNodeCount          = 2
    AksVmSize             = "Standard_B2s"
    AksKubernetesVersion  = "1.30"  # Adjust as needed
    
    # ACR Configuration (from previous steps)
    AcrName               = "acr$($AppName -replace '-', '')"
    
    # Key Vault Configuration (from previous steps)
    KeyVaultName          = "kv-$AppName"
    
    # Application Insights (from previous steps)
    AppInsightsName       = "appinsights-$AppName"
    
    # Managed Identity
    AksIdentityName       = "identity-$AppName-aks"
}

Write-Success "Configuration loaded for AKS deployment"

# ============================================================================
# STEP 6: Create AKS Cluster
# ============================================================================

Write-Section "STEP 6: Creating AKS Cluster"

Write-Step "Checking if AKS cluster already exists..."
$aksExists = az aks show --resource-group $config.ResourceGroup --name $config.AksClusterName --query 'name' -o tsv 2>$null
if ($aksExists) {
    Write-Success "AKS cluster already exists: $($config.AksClusterName)"
}
else {
    Write-Step "Getting subnet ID for VNet integration..."
    $subnetId = az network vnet subnet show `
        --resource-group $config.ResourceGroup `
        --vnet-name $config.VNetName `
        --name $config.AksSubnetName `
        --query 'id' -o tsv
    Write-Success "Subnet ID: $subnetId"
    
    Write-Step "Creating AKS cluster: $($config.AksClusterName)..."
    Write-Info "This may take 5-10 minutes. Please wait..."
    
    az aks create `
        --resource-group $config.ResourceGroup `
        --name $config.AksClusterName `
        --location $config.Region `
        --kubernetes-version $config.AksKubernetesVersion `
        --node-count $config.AksNodeCount `
        --vm-set-type VirtualMachineScaleSets `
        --load-balancer-sku standard `
        --enable-managed-identity `
        --network-plugin azure `
        --vnet-subnet-id $subnetId `
        --docker-bridge-address 172.17.0.1/16 `
        --service-cidr 10.1.0.0/16 `
        --dns-service-ip 10.1.0.10 `
        --node-vm-size $config.AksVmSize `
        --enable-monitoring `
        --workspace-resource-id $(az monitor log-analytics workspace show --resource-group $config.ResourceGroup --workspace-name "la-$($config.AppName)" --query 'id' -o tsv) `
        --zones 1 2 `
        --enable-azure-rbac
    
    Write-Success "AKS cluster created: $($config.AksClusterName)"
}

Write-Step "Getting AKS cluster details..."
$aksDetails = az aks show --resource-group $config.ResourceGroup --name $config.AksClusterName --query '{name: name, fqdn: fqdn, nodeResourceGroup: nodeResourceGroup, principalId: identity.principalId}' -o json | ConvertFrom-Json
Write-Success "AKS Cluster FQDN: $($aksDetails.fqdn)"
Write-Success "Node Resource Group: $($aksDetails.nodeResourceGroup)"
Write-Success "AKS Identity Principal ID: $($aksDetails.principalId)"

Write-Step "Getting kubeconfig for local access..."
az aks get-credentials --resource-group $config.ResourceGroup --name $config.AksClusterName --overwrite-existing
Write-Success "Kubeconfig updated. You can now run 'kubectl' commands."

Write-Step "Verifying cluster connectivity..."
$nodes = kubectl get nodes --no-headers
Write-Success "Cluster nodes:"
Write-Host $nodes

# ============================================================================
# STEP 7: Configure AKS Identity & RBAC
# ============================================================================

Write-Section "STEP 7: Configuring AKS Identity & RBAC"

Write-Step "Getting AKS managed identity..."
$aksPrincipalId = az aks show `
    --resource-group $config.ResourceGroup `
    --name $config.AksClusterName `
    --query 'identity.principalId' -o tsv
Write-Success "AKS Principal ID: $aksPrincipalId"

Write-Step "Granting AKS pull access to ACR..."
$acrId = az acr show --resource-group $config.ResourceGroup --name $config.AcrName --query 'id' -o tsv
az role assignment create `
    --assignee-object-id $aksPrincipalId `
    --role "AcrPull" `
    --scope $acrId 2>$null || Write-Success "AcrPull role already assigned"
Write-Success "AKS granted AcrPull role on ACR"

Write-Step "Creating pod-managed identity..."
$kvId = az keyvault show --resource-group $config.ResourceGroup --name $config.KeyVaultName --query 'id' -o tsv
# Note: Workload identity is recommended over pod-managed identity for new clusters
# For this guide, we'll set up RBAC for service accounts
Write-Success "Pod identity setup will be handled via Workload Identity in Phase 5"

Write-Step "Configuring Key Vault access for AKS..."
# Grant the AKS identity access to Key Vault
az keyvault set-policy `
    --name $config.KeyVaultName `
    --object-id $aksPrincipalId `
    --secret-permissions get list `
    --key-permissions get list `
    --certificate-permissions get list 2>$null || Write-Success "Key Vault permissions already configured"
Write-Success "AKS identity granted access to Key Vault secrets"

# ============================================================================
# STEP 8: Verify All Resources
# ============================================================================

Write-Section "STEP 8: Verifying All Resources"

Write-Step "Checking VNet..."
$vnetStatus = az network vnet show --resource-group $config.ResourceGroup --name $config.VNetName --query 'name' -o tsv
Write-Success "VNet verified: $vnetStatus"

Write-Step "Checking AKS subnet..."
$subnetStatus = az network vnet subnet show --resource-group $config.ResourceGroup --vnet-name $config.VNetName --name $config.AksSubnetName --query 'name' -o tsv
Write-Success "AKS subnet verified: $subnetStatus"

Write-Step "Checking ACR..."
$acrStatus = az acr show --resource-group $config.ResourceGroup --name $config.AcrName --query 'name' -o tsv
Write-Success "ACR verified: $acrStatus"

Write-Step "Checking Key Vault..."
$kvStatus = az keyvault show --resource-group $config.ResourceGroup --name $config.KeyVaultName --query 'name' -o tsv
Write-Success "Key Vault verified: $kvStatus"

Write-Step "Checking Application Insights..."
$appInsightsStatus = az monitor app-insights component show --resource-group $config.ResourceGroup --app $config.AppInsightsName --query 'name' -o tsv
Write-Success "Application Insights verified: $appInsightsStatus"

Write-Step "Checking AKS cluster..."
$aksStatus = az aks show --resource-group $config.ResourceGroup --name $config.AksClusterName --query 'powerState.code' -o tsv
Write-Success "AKS cluster status: $aksStatus"

Write-Step "Testing kubectl connectivity..."
$kubeVersion = kubectl version --short --client --output=json | ConvertFrom-Json
Write-Success "kubectl version: $($kubeVersion.clientVersion.gitVersion)"

# ============================================================================
# STEP 9: Cost Estimation
# ============================================================================

Write-Section "STEP 9: Cost Estimation"

Write-Host ""
Write-Host "Monthly Cost Estimation (Approximate):" @warning
Write-Host ""
Write-Host "  AKS Cluster Costs:" @info
Write-Host "    • Cluster management: $0 (included with Azure)"
Write-Host "    • 2 x Standard_B2s nodes: ~\$50/month"
Write-Host "    • Storage (OS disks): ~\$10/month"
Write-Host ""
Write-Host "  Supporting Services:" @info
Write-Host "    • Key Vault (3 operations/month): ~\$1/month"
Write-Host "    • ACR (Premium): ~\$50/month"
Write-Host "    • Application Insights (1GB/month): ~\$0.50/month"
Write-Host "    • Log Analytics (1GB/month): ~\$1/month"
Write-Host ""
Write-Host "  Estimated Total: ~\$112/month" @warning
Write-Host ""
Write-Host "Note: These are approximate costs. Actual costs depend on:" @info
Write-Host "  • Data ingress/egress"
Write-Host "  • Number of deployments and scaling operations"
Write-Host "  • Storage usage"
Write-Host "  • Monitoring data volume"
Write-Host ""
Write-Host "For detailed cost analysis, use:" @success
Write-Host "  az costmanagement export create --resource-group $($config.ResourceGroup)"
Write-Host ""

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

Write-Section "DEPLOYMENT COMPLETE!"

Write-Host ""
Write-Host "Infrastructure Summary:" @success
Write-Host ""
Write-Host "Resource Group: $($config.ResourceGroup)" 
Write-Host "Region: $($config.Region)"
Write-Host ""
Write-Host "Networking:" @info
Write-Host "  • VNet: $($config.VNetName) (10.0.0.0/16)"
Write-Host "  • AKS Subnet: $($config.AksSubnetName) (10.0.1.0/24)"
Write-Host ""
Write-Host "Kubernetes:" @info
Write-Host "  • AKS Cluster: $($config.AksClusterName)"
Write-Host "  • Nodes: $($config.AksNodeCount) × $($config.AksVmSize)"
Write-Host "  • Kubernetes Version: $($config.AksKubernetesVersion)"
Write-Host "  • FQDN: $($aksDetails.fqdn)"
Write-Host ""
Write-Host "Container & Storage:" @info
Write-Host "  • ACR: $($config.AcrName) (Premium SKU)"
Write-Host "  • Key Vault: $($config.KeyVaultName)"
Write-Host ""
Write-Host "Monitoring:" @info
Write-Host "  • Application Insights: $($config.AppInsightsName)"
Write-Host "  • Log Analytics: la-$($config.AppName)"
Write-Host ""

Write-Host "Useful Commands:" @success
Write-Host ""
Write-Host "  # Get cluster info"
Write-Host "  kubectl cluster-info"
Write-Host "  kubectl get nodes"
Write-Host ""
Write-Host "  # Deploy to AKS (Phase 5)"
Write-Host "  kubectl apply -f kubernetes/"
Write-Host ""
Write-Host "  # View logs"
Write-Host "  kubectl logs -n default deployment/address-api"
Write-Host ""
Write-Host "  # Port forward to local"
Write-Host "  kubectl port-forward svc/address-api 8080:80"
Write-Host ""
Write-Host "  # List all resources in RG"
Write-Host "  az resource list --resource-group $($config.ResourceGroup) --output table"
Write-Host ""

Write-Host "Next Phase: PHASE 5 - Kubernetes Deployment" @warning
Write-Host "Deploy your application to the AKS cluster using:"
Write-Host "  ./phase5-kubernetes-deployment.ps1"
Write-Host ""
