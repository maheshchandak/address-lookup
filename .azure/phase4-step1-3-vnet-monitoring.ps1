# Phase 4 - Step 1-3: Prerequisites, VNet, and Monitoring
# This script creates the foundational networking and monitoring infrastructure

param(
    [string]$SubscriptionId = "",
    [string]$ResourceGroup = "rg-address-lookup",
    [string]$Region = "uksouth",
    [string]$AppName = "address-lookup"
)

# Color output for better readability
$success = @{ ForegroundColor = "Green" }
$warning = @{ ForegroundColor = "Yellow" }
$error_msg = @{ ForegroundColor = "Red" }

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

# ============================================================================
# CONFIGURATION - Modify these as needed
# ============================================================================

Write-Section "PHASE 4 INFRASTRUCTURE DEPLOYMENT - Configuration"

$config = @{
    SubscriptionId        = $SubscriptionId
    ResourceGroup         = $ResourceGroup
    Region                = $Region
    AppName               = $AppName
    
    # VNet Configuration
    VNetName              = "vnet-$AppName"
    VNetCIDR              = "10.0.0.0/16"
    AksSubnetName         = "subnet-aks"
    AksSubnetCIDR         = "10.0.1.0/24"
    
    # ACR Configuration
    AcrName               = "acr$($AppName -replace '-', '')"
    AcrSku                = "Premium"
    
    # Key Vault Configuration
    KeyVaultName          = "kv-$AppName"
    
    # AKS Configuration
    AksClusterName        = "aks-$AppName"
    AksNodepoolName       = "nodepool1"
    AksNodeCount          = 2
    AksVmSize             = "Standard_B2s"
    
    # Application Insights
    AppInsightsName       = "appinsights-$AppName"
    LogAnalyticsName      = "la-$AppName"
    
    # Managed Identity
    AksIdentityName       = "identity-$AppName-aks"
}

Write-Host "Configuration loaded:" @success
Write-Host "  Resource Group: $($config.ResourceGroup)"
Write-Host "  Region: $($config.Region)"
Write-Host "  App Name: $($config.AppName)"
Write-Host "  VNet: $($config.VNetName) [$($config.VNetCIDR)]"
Write-Host "  AKS Subnet: $($config.AksSubnetName) [$($config.AksSubnetCIDR)]"
Write-Host "  AKS Cluster: $($config.AksClusterName)"
Write-Host "  ACR: $($config.AcrName)"

# ============================================================================
# STEP 1: Verify Prerequisites
# ============================================================================

Write-Section "STEP 1: Verifying Prerequisites"

Write-Step "Checking Azure CLI installation..."
try {
    $cliVersion = az version --query '"azure-cli"' -o tsv
    Write-Success "Azure CLI installed: $cliVersion"
}
catch {
    Write-Host "❌ Azure CLI not found. Please install it first." @error_msg
    exit 1
}

Write-Step "Checking authentication..."
try {
    $account = az account show --query 'name' -o tsv
    Write-Success "Authenticated as: $account"
}
catch {
    Write-Host "❌ Not authenticated. Run 'az login' first." @error_msg
    exit 1
}

Write-Step "Setting subscription..."
if ($config.SubscriptionId) {
    az account set --subscription $config.SubscriptionId
    Write-Success "Subscription set to: $($config.SubscriptionId)"
}
else {
    $current = az account show --query 'id' -o tsv
    Write-Success "Using current subscription: $current"
}

Write-Step "Verifying resource group exists..."
$rg = az group show --name $config.ResourceGroup --query 'name' -o tsv 2>$null
if ($rg) {
    Write-Success "Resource group found: $($config.ResourceGroup)"
}
else {
    Write-Host "❌ Resource group not found. Creating..." @warning
    az group create --name $config.ResourceGroup --location $config.Region
    Write-Success "Resource group created: $($config.ResourceGroup)"
}

Write-Success "All prerequisites verified!"

# ============================================================================
# STEP 2: Create Virtual Network
# ============================================================================

Write-Section "STEP 2: Creating Virtual Network"

Write-Step "Checking if VNet already exists..."
$vnetExists = az network vnet show --resource-group $config.ResourceGroup --name $config.VNetName --query 'name' -o tsv 2>$null
if ($vnetExists) {
    Write-Success "VNet already exists: $($config.VNetName)"
}
else {
    Write-Step "Creating VNet: $($config.VNetName)..."
    az network vnet create `
        --resource-group $config.ResourceGroup `
        --name $config.VNetName `
        --address-prefix $config.VNetCIDR `
        --subnet-name $config.AksSubnetName `
        --subnet-prefix $config.AksSubnetCIDR `
        --location $config.Region
    Write-Success "VNet created: $($config.VNetName)"
}

Write-Step "Verifying subnet..."
$subnetId = az network vnet subnet show `
    --resource-group $config.ResourceGroup `
    --vnet-name $config.VNetName `
    --name $config.AksSubnetName `
    --query 'id' -o tsv
Write-Success "Subnet verified. ID: $subnetId"

# ============================================================================
# STEP 3: Create Application Insights & Log Analytics
# ============================================================================

Write-Section "STEP 3: Creating Application Insights & Log Analytics"

Write-Step "Checking if Log Analytics workspace exists..."
$laExists = az monitor log-analytics workspace show `
    --resource-group $config.ResourceGroup `
    --workspace-name $config.LogAnalyticsName `
    --query 'name' -o tsv 2>$null
if ($laExists) {
    Write-Success "Log Analytics workspace already exists: $($config.LogAnalyticsName)"
}
else {
    Write-Step "Creating Log Analytics workspace..."
    az monitor log-analytics workspace create `
        --resource-group $config.ResourceGroup `
        --workspace-name $config.LogAnalyticsName `
        --location $config.Region
    Write-Success "Log Analytics workspace created: $($config.LogAnalyticsName)"
}

Write-Step "Getting Log Analytics workspace ID..."
$laWorkspaceId = az monitor log-analytics workspace show `
    --resource-group $config.ResourceGroup `
    --workspace-name $config.LogAnalyticsName `
    --query 'id' -o tsv
Write-Success "Log Analytics ID: $laWorkspaceId"

Write-Step "Checking if Application Insights exists..."
$appInsightsExists = az monitor app-insights component show `
    --resource-group $config.ResourceGroup `
    --app $config.AppInsightsName `
    --query 'name' -o tsv 2>$null
if ($appInsightsExists) {
    Write-Success "Application Insights already exists: $($config.AppInsightsName)"
}
else {
    Write-Step "Creating Application Insights..."
    az monitor app-insights component create `
        --app $config.AppInsightsName `
        --resource-group $config.ResourceGroup `
        --location $config.Region `
        --workspace $laWorkspaceId
    Write-Success "Application Insights created: $($config.AppInsightsName)"
}

Write-Step "Getting Application Insights instrumentation key..."
$appInsightsKey = az monitor app-insights component show `
    --resource-group $config.ResourceGroup `
    --app $config.AppInsightsName `
    --query 'instrumentationKey' -o tsv
Write-Success "App Insights Key: $($appInsightsKey.Substring(0, 8))..." 

# ============================================================================
# VALIDATION & SUMMARY
# ============================================================================

Write-Section "VALIDATION & SUMMARY"

Write-Step "Listing all created resources..."
$resources = az resource list --resource-group $config.ResourceGroup --query '[].name' -o tsv
foreach ($resource in $resources) {
    Write-Host "  ✓ $resource"
}

Write-Success "STEPS 1-3 COMPLETED SUCCESSFULLY!"
Write-Host ""
Write-Host "Next Steps:" @warning
Write-Host "1. Review the resources created above"
Write-Host "2. Run the next script for Steps 4-5 (Key Vault & ACR)"
Write-Host "3. Then deploy AKS in Steps 6-7"
Write-Host ""
Write-Host "To continue, run: ./phase4-step4-5-keyvault-acr.ps1" @success
