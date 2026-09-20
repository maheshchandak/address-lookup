# ============================================================================
# Phase 4: Infrastructure as Code - Step 1: Setup & Configuration
# ============================================================================
# Purpose: Set subscription context and verify prerequisites
# Run this FIRST before running other scripts
# ============================================================================

# ============================================================================
# CONFIGURATION - UPDATE THESE VALUES
# ============================================================================
$SUBSCRIPTION_ID = "19f9bf9f-a14a-44be-8ec7-30e9c950ff9c"  # Get from: az account show --query id -o tsv
$RESOURCE_GROUP = "rg-address-lookup"
$LOCATION = "uksouth"  # uk south, uksouth2, eastus, etc.

# ============================================================================
# SCRIPT STARTS HERE
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Phase 4: Infrastructure Setup - Step 1" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if subscription ID is configured
if ($SUBSCRIPTION_ID -eq "YOUR_SUBSCRIPTION_ID") {
    Write-Host "ERROR: Please update SUBSCRIPTION_ID in this script" -ForegroundColor Red
    Write-Host "Get your subscription ID with: az account show --query id -o tsv" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/5] Checking Azure CLI installation..." -ForegroundColor Cyan
$azCheck = az --version
if (-not $azCheck) {
    Write-Host "ERROR: Azure CLI not installed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Azure CLI installed" -ForegroundColor Green
Write-Host ""

# Set subscription
Write-Host "[2/5] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SUBSCRIPTION_ID
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to set subscription" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Subscription set to: $SUBSCRIPTION_ID" -ForegroundColor Green
Write-Host ""

# Get current subscription info
Write-Host "[3/5] Verifying subscription..." -ForegroundColor Cyan
$subInfo = az account show --query "{name: name, id: id, tenantId: tenantId}" -o json | ConvertFrom-Json
Write-Host "Subscription Name: $($subInfo.name)" -ForegroundColor Green
Write-Host "Subscription ID:   $($subInfo.id)" -ForegroundColor Green
Write-Host "Tenant ID:         $($subInfo.tenantId)" -ForegroundColor Green
Write-Host ""

# Check if resource group exists, create if not
Write-Host "[4/5] Checking resource group..." -ForegroundColor Cyan
$rgExists = az group exists --name $RESOURCE_GROUP
if ($rgExists -eq "true") {
    Write-Host "✓ Resource group exists: $RESOURCE_GROUP" -ForegroundColor Green
} else {
    Write-Host "Creating resource group: $RESOURCE_GROUP in $LOCATION..." -ForegroundColor Yellow
    az group create --name $RESOURCE_GROUP --location $LOCATION
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Resource group created" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to create resource group" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Display resource group info
Write-Host "[5/5] Resource group details:" -ForegroundColor Cyan
$rgInfo = az group show --name $RESOURCE_GROUP --query "{name: name, location: location, id: id}" -o json | ConvertFrom-Json
Write-Host "Name:     $($rgInfo.name)" -ForegroundColor Green
Write-Host "Location: $($rgInfo.location)" -ForegroundColor Green
Write-Host "ID:       $($rgInfo.id)" -ForegroundColor Green
Write-Host ""

# Save configuration to environment file for other scripts
$envFile = Join-Path (Split-Path $PSCommandPath) "config.env"
@"
# Auto-generated configuration file
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
RESOURCE_GROUP=$RESOURCE_GROUP
LOCATION=$LOCATION
"@ | Out-File -FilePath $envFile -Encoding UTF8

Write-Host "✓ Configuration saved to: $envFile" -ForegroundColor Green
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✓ Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Run 02-vnet.ps1 to create the Virtual Network" -ForegroundColor Cyan
