# ============================================================================
# Phase 4: Infrastructure as Code - Step 4: Azure Key Vault
# ============================================================================
# Purpose: Create and configure Azure Key Vault for secrets management
# Run after: 03-acr.ps1
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
# CONFIGURATION - CUSTOMIZE AND SET YOUR SECRETS
# ============================================================================
# Key Vault name must be globally unique, 3-24 characters, alphanumeric and hyphens
$KEYVAULT_NAME = "kv-addresslookup-$(Get-Date -Format 'MMddHHmm')"  # Auto-generate unique name
# $KEYVAULT_NAME = "kv-addresslookup"  # Uncomment to use fixed name (may conflict)

# Secrets - UPDATE WITH YOUR VALUES
$POSTCODES_IO_URL = "https://api.postcodes.io"  # Postcodes.io API endpoint
$POSTCODES_IO_KEY = "your-api-key-here"  # Update with actual API key if needed

# ============================================================================
# SCRIPT STARTS HERE
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Phase 4: Infrastructure Setup - Step 4" -ForegroundColor Cyan
Write-Host "Azure Key Vault" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "[1/5] Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SUBSCRIPTION_ID
Write-Host "✓ Subscription: $SUBSCRIPTION_ID" -ForegroundColor Green
Write-Host ""

# Create Key Vault
Write-Host "[2/5] Creating Azure Key Vault..." -ForegroundColor Cyan
Write-Host "Key Vault Name: $KEYVAULT_NAME" -ForegroundColor Yellow

$kvExists = az keyvault show --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --query id 2>$null
if ($kvExists) {
    Write-Host "✓ Key Vault already exists: $KEYVAULT_NAME" -ForegroundColor Green
} else {
    az keyvault create `
        --name $KEYVAULT_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --enable-rbac-authorization true
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Key Vault created: $KEYVAULT_NAME" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to create Key Vault" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Get current user/service principal ID for RBAC
Write-Host "[3/5] Setting up RBAC permissions..." -ForegroundColor Cyan
$currentUser = az account show --query user.name -o tsv
Write-Host "Current user/principal: $currentUser" -ForegroundColor Yellow

# Assign Key Vault Secrets Officer role to current user
az role assignment create `
    --assignee $currentUser `
    --role "Key Vault Secrets Officer" `
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME" 2>$null

Write-Host "✓ RBAC permissions configured" -ForegroundColor Green
Write-Host ""

# Add secrets to Key Vault
Write-Host "[4/5] Adding secrets to Key Vault..." -ForegroundColor Cyan

# Add Postcodes.io URL
Write-Host "  - Adding PostcodesIOUrl..." -ForegroundColor Yellow
az keyvault secret set `
    --vault-name $KEYVAULT_NAME `
    --name "PostcodesIOUrl" `
    --value $POSTCODES_IO_URL 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ PostcodesIOUrl secret created" -ForegroundColor Green
}

# Add Postcodes.io API Key (if needed)
if ($POSTCODES_IO_KEY -ne "your-api-key-here") {
    Write-Host "  - Adding PostcodesIOKey..." -ForegroundColor Yellow
    az keyvault secret set `
        --vault-name $KEYVAULT_NAME `
        --name "PostcodesIOKey" `
        --value $POSTCODES_IO_KEY 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ PostcodesIOKey secret created" -ForegroundColor Green
    }
}

Write-Host ""

# List secrets in vault
Write-Host "[5/5] Verifying secrets..." -ForegroundColor Cyan
$secrets = az keyvault secret list --vault-name $KEYVAULT_NAME --query "[].name" -o tsv
Write-Host "Secrets in vault:" -ForegroundColor Yellow
$secrets | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
Write-Host ""

# Display Key Vault details
Write-Host "Azure Key Vault Details:" -ForegroundColor Cyan
$kvInfo = az keyvault show --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --query "{name: name, vaultUri: properties.vaultUri, location: location}" -o json | ConvertFrom-Json
Write-Host "Name:     $($kvInfo.name)" -ForegroundColor Green
Write-Host "URI:      $($kvInfo.vaultUri)" -ForegroundColor Green
Write-Host "Location: $($kvInfo.location)" -ForegroundColor Green
Write-Host ""

# Save Key Vault info to config
$envFile = Join-Path $scriptDir "config.env"
Add-Content -Path $envFile -Value "`n# Key Vault Configuration"
Add-Content -Path $envFile -Value "KEYVAULT_NAME=$KEYVAULT_NAME"
Add-Content -Path $envFile -Value "KEYVAULT_URI=$($kvInfo.vaultUri)"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "✓ Key Vault Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: Run 05-aks.ps1 to create Azure Kubernetes Service (AKS)" -ForegroundColor Cyan
Write-Host ""
Write-Host "INFO: To retrieve secrets in your app:" -ForegroundColor Cyan
Write-Host "  az keyvault secret show --vault-name $KEYVAULT_NAME --name PostcodesIOUrl --query value -o tsv" -ForegroundColor Yellow
