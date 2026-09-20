# ============================================================================
# Phase 4: Infrastructure as Code - Step 2: Virtual Network & Networking
# ============================================================================
# Purpose: Create Virtual Network, Subnets, and Network Security Groups
# Run after: 01-setup.ps1
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

# ============================================================================
# CONFIGURATION - CUSTOMIZE IF NEEDED
# ============================================================================
$VNET_NAME = "vnet-address-lookup"
$VNET_PREFIX = "10.0.0.0/16"
$SUBNET_AKS_NAME = "subnet-aks"
$SUBNET_AKS_PREFIX = "10.0.1.0/24"
$SUBNET_SERVICES_NAME = "subnet-services"
$SUBNET_SERVICES_PREFIX = "10.0.2.0/24"
$NSG_NAME = "nsg-address-lookup"

# ============================================================================
# SCRIPT STARTS HERE
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Phase 4: Infrastructure Setup - Step 2" -ForegroundColor Cyan
Write-Host "Virtual Network & Networking" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "[1/4] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SUBSCRIPTION_ID
Write-Host "✓ Subscription: $SUBSCRIPTION_ID" -ForegroundColor Green
Write-Host ""

# Create Network Security Group
Write-Host "[2/4] Creating Network Security Group..." -ForegroundColor Cyan
$nsgExists = az network nsg show --name $NSG_NAME --resource-group $RESOURCE_GROUP --query id 2>$null
if ($nsgExists) {
    Write-Host "✓ NSG already exists: $NSG_NAME" -ForegroundColor Green
} else {
    az network nsg create `
        --name $NSG_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ NSG created: $NSG_NAME" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to create NSG" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Create Virtual Network
Write-Host "[3/4] Creating Virtual Network..." -ForegroundColor Cyan
$vnetExists = az network vnet show --name $VNET_NAME --resource-group $RESOURCE_GROUP --query id 2>$null
if ($vnetExists) {
    Write-Host "✓ VNet already exists: $VNET_NAME" -ForegroundColor Green
} else {
    az network vnet create `
        --name $VNET_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --address-prefix $VNET_PREFIX `
        --subnet-name $SUBNET_AKS_NAME `
        --subnet-prefix $SUBNET_AKS_PREFIX `
        --network-security-group $NSG_NAME
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ VNet created: $VNET_NAME" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to create VNet" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Create additional subnet for services
Write-Host "[4/4] Creating Services Subnet..." -ForegroundColor Cyan
$subnetExists = az network vnet subnet show --name $SUBNET_SERVICES_NAME --vnet-name $VNET_NAME --resource-group $RESOURCE_GROUP --query id 2>$null
if ($subnetExists) {
    Write-Host "✓ Subnet already exists: $SUBNET_SERVICES_NAME" -ForegroundColor Green
} else {
    az network vnet subnet create `
        --name $SUBNET_SERVICES_NAME `
        --vnet-name $VNET_NAME `
        --resource-group $RESOURCE_GROUP `
        --address-prefix $SUBNET_SERVICES_PREFIX `
        --network-security-group $NSG_NAME
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Subnet created: $SUBNET_SERVICES_NAME" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to create subnet" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Display VNet details
Write-Host "Virtual Network Details:" -ForegroundColor Cyan
$vnetInfo = az network vnet show --name $VNET_NAME --resource-group $RESOURCE_GROUP --query "{name: name, addressPrefixes: addressSpace.addressPrefixes[0], subnets: subnets[].name}" -o json | ConvertFrom-Json
Write-Host "Name:       $($vnetInfo.name)" -ForegroundColor Green
Write-Host "Address:    $($vnetInfo.addressPrefixes)" -ForegroundColor Green
Write-Host "Subnets:    $($vnetInfo.subnets -join ', ')" -ForegroundColor Green
Write-Host ""

# Save VNet info to config
$vnetInfo = @{
    VNET_NAME = $VNET_NAME
    VNET_PREFIX = $VNET_PREFIX
    SUBNET_AKS_NAME = $SUBNET_AKS_NAME
    SUBNET_AKS_PREFIX = $SUBNET_AKS_PREFIX
    SUBNET_SERVICES_NAME = $SUBNET_SERVICES_NAME
    SUBNET_SERVICES_PREFIX = $SUBNET_SERVICES_PREFIX
    NSG_NAME = $NSG_NAME
}

$envFile = Join-Path $scriptDir "config.env"
Add-Content -Path $envFile -Value "`n# VNet Configuration"
$vnetInfo.GetEnumerator() | ForEach-Object {
    Add-Content -Path $envFile -Value "$($_.Key)=$($_.Value)"
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✓ Networking Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Run 03-acr.ps1 to create Azure Container Registry" -ForegroundColor Cyan
