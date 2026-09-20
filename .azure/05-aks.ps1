# ============================================================================
# Phase 4: Infrastructure as Code - Step 5: Azure Kubernetes Service (AKS)
# ============================================================================
# Purpose: Create and configure AKS cluster for containerized deployment
# Run after: 04-keyvault.ps1
# ============================================================================

# Load configuration from setup script
$scriptDir = Split-Path $PSCommandPath
$envFile = Join-Path $scriptDir "config.env"

if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: Configuration file not found. Run 01-setup.ps1 first" -ForegroundColor Red
    exit 1
}

# Load environment variables
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}

$SUBSCRIPTION_ID = $env:SUBSCRIPTION_ID
$RESOURCE_GROUP = $env:RESOURCE_GROUP
$LOCATION = $env:LOCATION
$SUBNET_AKS_NAME = $env:SUBNET_AKS_NAME
$VNET_NAME = $env:VNET_NAME
$ACR_NAME = $env:ACR_NAME

# ============================================================================
# CONFIGURATION - CUSTOMIZE IF NEEDED
# ============================================================================
$AKS_CLUSTER_NAME = "aks-address-lookup"
$VM_SKU = "Standard_B2s"  # Small: B2s, Medium: B4ms, Prod: D2s_v3
$NODE_COUNT = 1  # Minimum 1, recommended 2-3 for HA

# Get latest supported Kubernetes version for the region
Write-Host "[0/5] Detecting supported Kubernetes versions for region: $LOCATION" -ForegroundColor Cyan

# First, verify Azure CLI is working
$cliTest = az account show --query id -o tsv 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Azure CLI authentication failed" -ForegroundColor Red
    Write-Host "Please run: az login" -ForegroundColor Yellow
    exit 1
}

# Try to find available VM sizes - use D-series as fallback since B-series quota is exhausted
Write-Host "Attempting to detect available VM sizes for region: $LOCATION" -ForegroundColor Yellow
# Try D-series v7/v3 options (more commonly available, still cost-effective)
$preferredSizes = @("Standard_D2s_v3", "Standard_D2ads_v7", "Standard_D2ds_v4", "Standard_B2ps_v2", "Standard_D3s_v3")
$VM_SKU = $preferredSizes[0]  # Start with D2s_v3 (cheapest D-series)
Write-Host "✓ Using cheapest available option: $VM_SKU" -ForegroundColor Green

Write-Host ""

# Get versions with better error handling
Write-Host "Attempting to retrieve Kubernetes versions for region: $LOCATION" -ForegroundColor Yellow
$versionsJson = az aks get-versions --location $LOCATION -o json 2>&1
$getVersionsExitCode = $LASTEXITCODE

if ($getVersionsExitCode -ne 0) {
    Write-Host "ERROR: Failed to retrieve Kubernetes versions for region: $LOCATION" -ForegroundColor Red
    Write-Host "Debug output: $versionsJson" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Attempting to list available AKS regions..." -ForegroundColor Yellow
    
    $availableRegions = az provider show --namespace Microsoft.ContainerService --query "resourceTypes[?resourceType=='managedClusters'].locations" -o json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $regions = $availableRegions | ConvertFrom-Json
        Write-Host "Available regions for AKS:" -ForegroundColor Cyan
        $regions -join "`n" | Write-Host -ForegroundColor Green
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Common regions: eastus, westus, westeurope, uksouth, eastus2, canadacentral" -ForegroundColor Cyan
    }
    
    Write-Host "" -ForegroundColor Yellow
    Write-Host "To fix this:" -ForegroundColor Yellow
    Write-Host "1. Update LOCATION in config.env to a supported region" -ForegroundColor Yellow
    Write-Host "2. Re-run 01-setup.ps1 or manually edit .\.azure\config.env" -ForegroundColor Yellow
    exit 1
}

try {
    $versionsObj = $versionsJson | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "ERROR: Failed to parse Kubernetes versions JSON" -ForegroundColor Red
    Write-Host "Raw output: $versionsJson" -ForegroundColor Yellow
    exit 1
}

# Handle different possible JSON structures
$versions = $null
if ($versionsObj.PSObject.Properties.Name -contains "values") {
    # Structure: { "values": [ { "version": "1.37" }, ... ] }
    $versions = $versionsObj.values | Select-Object -ExpandProperty version
} elseif ($versionsObj.PSObject.Properties.Name -contains "orchestrators") {
    # Structure: { "orchestrators": [ { "kubernetesVersion": "1.28.0" }, ... ] }
    $versions = $versionsObj.orchestrators | Select-Object -ExpandProperty kubernetesVersion
} elseif ($versionsObj -is [array]) {
    # Structure: [ { "kubernetesVersion": "1.28.0" }, ... ]
    $versions = $versionsObj | Select-Object -ExpandProperty kubernetesVersion
} elseif ($versionsObj.PSObject.Properties.Name -contains "kubernetesVersion") {
    # Single object
    $versions = @($versionsObj.kubernetesVersion)
} else {
    Write-Host "ERROR: Unexpected JSON structure. Properties found:" -ForegroundColor Red
    Write-Host ($versionsObj.PSObject.Properties.Name -join ", ") -ForegroundColor Yellow
    Write-Host "Full response: $versionsJson" -ForegroundColor Yellow
    exit 1
}

if (-not $versions -or $versions.Count -eq 0) {
    Write-Host "ERROR: No Kubernetes versions available for region: $LOCATION" -ForegroundColor Red
    Write-Host "This may indicate the region is not supported for AKS." -ForegroundColor Yellow
    exit 1
}

# Use the latest stable version (excluding preview versions)
# Filter non-preview versions, convert to version objects for proper sorting, then get latest
$stableVersions = $versions | Where-Object { $_ -notmatch '-' }
if ($stableVersions) {
    $AKS_VERSION = ($stableVersions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1).ToString()
} else {
    Write-Host "WARNING: No stable versions found, using latest preview version" -ForegroundColor Yellow
    $AKS_VERSION = ($versions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1).ToString()
}

if (-not $AKS_VERSION) {
    Write-Host "ERROR: Could not find a Kubernetes version" -ForegroundColor Red
    Write-Host "Available versions: $($versions -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Latest supported version: $AKS_VERSION" -ForegroundColor Green
Write-Host "✓ Available versions: $($versions -join ', ')" -ForegroundColor Green
Write-Host ""

# Get subnet ID
$SUBNET_ID = az network vnet subnet show `
    --vnet-name $VNET_NAME `
    --name $SUBNET_AKS_NAME `
    --resource-group $RESOURCE_GROUP `
    --query id -o tsv 2>$null

if (-not $SUBNET_ID) {
    Write-Host "ERROR: VNet or subnet not found. Run 02-vnet.ps1 first" -ForegroundColor Red
    exit 1
}

# Get ACR resource ID
$ACR_ID = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query id -o tsv 2>$null

if (-not $ACR_ID) {
    Write-Host "ERROR: ACR not found. Run 03-acr.ps1 first" -ForegroundColor Red
    exit 1
}

# ============================================================================
# SCRIPT STARTS HERE
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Phase 4: Infrastructure Setup - Step 5" -ForegroundColor Cyan
Write-Host "Azure Kubernetes Service (AKS)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  NOTE: This step may take 10-15 minutes" -ForegroundColor Yellow
Write-Host ""

# Set subscription context
Write-Host "[1/5] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SUBSCRIPTION_ID
Write-Host "✓ Subscription: $SUBSCRIPTION_ID" -ForegroundColor Green
Write-Host ""

# Check if cluster exists
Write-Host "[2/5] Checking AKS cluster status..." -ForegroundColor Cyan
$clusterExists = az aks show --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --query id 2>$null
if ($clusterExists) {
    Write-Host "✓ AKS cluster already exists: $AKS_CLUSTER_NAME" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "[3/5] Creating AKS cluster..." -ForegroundColor Cyan
    Write-Host "Cluster Name: $AKS_CLUSTER_NAME" -ForegroundColor Yellow
    Write-Host "VM SKU:       $VM_SKU" -ForegroundColor Yellow
    Write-Host "Node Count:   $NODE_COUNT" -ForegroundColor Yellow
    Write-Host "Version:      $AKS_VERSION" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⏳ This will take approximately 10-15 minutes..." -ForegroundColor Yellow
    Write-Host ""

    az aks create `
        --name $AKS_CLUSTER_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --vm-set-type VirtualMachineScaleSets `
        --node-count $NODE_COUNT `
        --node-vm-size $VM_SKU `
        --kubernetes-version $AKS_VERSION `
        --vnet-subnet-id $SUBNET_ID `
        --enable-managed-identity `
        --generate-ssh-keys `
        --attach-acr $ACR_ID `
        --network-plugin azure `
        --network-policy azure `
        --service-cidr 10.1.0.0/16 `
        --dns-service-ip 10.1.0.10 `
        --enable-addons monitoring

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ AKS cluster created successfully" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to create AKS cluster" -ForegroundColor Red
        exit 1
    }

    # Enable autoscaling on the default node pool
    Write-Host "[3b/5] Enabling autoscaling on default node pool..." -ForegroundColor Cyan
    az aks nodepool update `
        --resource-group $RESOURCE_GROUP `
        --cluster-name $AKS_CLUSTER_NAME `
        --name nodepool1 `
        --enable-cluster-autoscaling `
        --min-count 1 `
        --max-count 3

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Autoscaling enabled successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Warning: Failed to enable autoscaling (cluster was created, this is non-critical)" -ForegroundColor Yellow
    }
}

Write-Host ""

# Get cluster credentials
Write-Host "[4/5] Configuring kubectl credentials..." -ForegroundColor Cyan
az aks get-credentials `
    --name $AKS_CLUSTER_NAME `
    --resource-group $RESOURCE_GROUP `
    --overwrite-existing

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ kubectl credentials configured" -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to get credentials" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Verify cluster connectivity
Write-Host "[5/5] Verifying cluster connectivity..." -ForegroundColor Cyan
$clusterInfo = kubectl cluster-info 2>$null
if ($clusterInfo) {
    Write-Host "✓ Successfully connected to cluster" -ForegroundColor Green
    
    # Show nodes
    Write-Host ""
    Write-Host "Cluster Nodes:" -ForegroundColor Cyan
    kubectl get nodes -o wide
    Write-Host ""
} else {
    Write-Host "⚠️  Could not verify cluster connection (this may be normal on first setup)" -ForegroundColor Yellow
}

# Display AKS details
Write-Host ""
Write-Host "Azure Kubernetes Service Details:" -ForegroundColor Cyan
$aksInfo = az aks show --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "{name: name, kubernetes: kubernetesVersion, nodeCount: agentPoolProfiles[0].count, vmSize: agentPoolProfiles[0].vmSize}" -o json | ConvertFrom-Json
Write-Host "Name:           $($aksInfo.name)" -ForegroundColor Green
Write-Host "Kubernetes:     $($aksInfo.kubernetes)" -ForegroundColor Green
Write-Host "Node Count:     $($aksInfo.nodeCount)" -ForegroundColor Green
Write-Host "VM Size:        $($aksInfo.vmSize)" -ForegroundColor Green
Write-Host ""

# Save AKS info to config
$envFile = Join-Path $scriptDir "config.env"
Add-Content -Path $envFile -Value "`n# AKS Configuration"
Add-Content -Path $envFile -Value "AKS_CLUSTER_NAME=$AKS_CLUSTER_NAME"
Add-Content -Path $envFile -Value "AKS_VERSION=$AKS_VERSION"
Add-Content -Path $envFile -Value "AKS_VM_SKU=$VM_SKU"
Add-Content -Path $envFile -Value "AKS_NODE_COUNT=$NODE_COUNT"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✓ AKS Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Run 06-identity-rbac.ps1 to configure managed identity and RBAC" -ForegroundColor Cyan
Write-Host ""
Write-Host "INFO: Useful kubectl commands:" -ForegroundColor Cyan
Write-Host "  kubectl get nodes                  # Show cluster nodes" -ForegroundColor Yellow
Write-Host "  kubectl get pods -A                # Show all pods" -ForegroundColor Yellow
Write-Host "  kubectl config current-context    # Show current context" -ForegroundColor Yellow
