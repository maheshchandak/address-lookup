# ============================================================================
# Phase 4: Infrastructure as Code - Step 3: Azure Container Registry
# ============================================================================
# Purpose: Create and configure Azure Container Registry (ACR)
# Run after: 02-vnet.ps1
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
# ACR name must be globally unique, lowercase, alphanumeric only
# Using pattern: acr<timestamp><random>
$TIMESTAMP = Get-Date -Format "MMddHHmm"
# $ACR_NAME = "acr${TIMESTAMP}$(Get-Random -Minimum 1000 -Maximum 9999)".ToLower()
# Or use a fixed name (change 'addresslookup' to your preferred name)
$ACR_NAME = "addresslookupacr"  # Uncomment to use fixed name

$ACR_SKU = "Basic"  # Basic, Standard, Premium
$ENABLE_ADMIN = "false"  # Set to true to enable admin user (not recommended for prod)

# ============================================================================
# SCRIPT STARTS HERE
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Phase 4: Infrastructure Setup - Step 3" -ForegroundColor Cyan
Write-Host "Azure Container Registry (ACR)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "[1/4] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SUBSCRIPTION_ID
Write-Host "✓ Subscription: $SUBSCRIPTION_ID" -ForegroundColor Green
Write-Host ""

# Check if ACR name is available and create ACR
Write-Host "[2/4] Creating Azure Container Registry..." -ForegroundColor Cyan
Write-Host "ACR Name: $ACR_NAME" -ForegroundColor Yellow
Write-Host "SKU:      $ACR_SKU" -ForegroundColor Yellow

$acrExists = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query id 2>$null
if ($acrExists) {
    Write-Host "✓ ACR already exists: $ACR_NAME" -ForegroundColor Green
} else {
    az acr create `
        --name $ACR_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --sku $ACR_SKU `
        --admin-enabled $ENABLE_ADMIN
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ ACR created: $ACR_NAME" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to create ACR" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Get ACR login server
Write-Host "[3/4] Retrieving ACR login server..." -ForegroundColor Cyan
$ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query loginServer -o tsv
Write-Host "✓ ACR Login Server: $ACR_LOGIN_SERVER" -ForegroundColor Green
Write-Host ""

# Enable anonymous pull (for public images, optional)
Write-Host "[4/4] Configuring ACR settings..." -ForegroundColor Cyan
az acr update `
    --name $ACR_NAME `
    --public-network-enabled true `
    --default-action Allow
Write-Host "✓ ACR configured for network access" -ForegroundColor Green
Write-Host ""

# Display ACR details
Write-Host "Azure Container Registry Details:" -ForegroundColor Cyan
$acrInfo = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "{name: name, loginServer: loginServer, sku: sku.name, adminEnabled: adminUserEnabled}" -o json | ConvertFrom-Json
Write-Host "Name:        $($acrInfo.name)" -ForegroundColor Green
Write-Host "Login Server: $($acrInfo.loginServer)" -ForegroundColor Green
Write-Host "SKU:         $($acrInfo.sku)" -ForegroundColor Green
Write-Host "Admin User:  $($acrInfo.adminEnabled)" -ForegroundColor Green
Write-Host ""

# Save ACR info to config
$envFile = Join-Path $scriptDir "config.env"
Add-Content -Path $envFile -Value "`n# ACR Configuration"
Add-Content -Path $envFile -Value "ACR_NAME=$ACR_NAME"
Add-Content -Path $envFile -Value "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
Add-Content -Path $envFile -Value "ACR_SKU=$ACR_SKU"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✓ ACR Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Run 04-keyvault.ps1 to create Azure Key Vault" -ForegroundColor Cyan
Write-Host ""
Write-Host "INFO: You can login to ACR with:" -ForegroundColor Cyan
Write-Host "  az acr login --name $ACR_NAME" -ForegroundColor Yellow
Write-Host ""
Write-Host "INFO: Push images to ACR with:" -ForegroundColor Cyan
Write-Host "  docker tag <image> $ACR_LOGIN_SERVER/<image>:<tag>" -ForegroundColor Yellow
Write-Host "  docker push $ACR_LOGIN_SERVER/<image>:<tag>" -ForegroundColor Yellow
