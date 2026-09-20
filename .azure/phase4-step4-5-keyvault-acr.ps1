# Phase 4 - Step 4-5: Key Vault & Azure Container Registry
# This script creates Key Vault and ACR, essential for securing secrets and storing container images

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
# CONFIGURATION
# ============================================================================

Write-Section "PHASE 4 INFRASTRUCTURE DEPLOYMENT - Key Vault & ACR"

$config = @{
    SubscriptionId        = $SubscriptionId
    ResourceGroup         = $ResourceGroup
    Region                = $Region
    AppName               = $AppName
    
    # ACR Configuration
    AcrName               = "acr$($AppName -replace '-', '')"
    AcrSku                = "Premium"
    AcrAdminEnabled       = $true
    
    # Key Vault Configuration
    KeyVaultName          = "kv-$AppName"
    KeyVaultSku           = "standard"
    
    # Secrets to store
    PostcodesApiEndpoint  = "https://api.postcodes.io"
}

Write-Success "Configuration loaded for deployment to: $($config.ResourceGroup) in $($config.Region)"

# ============================================================================
# STEP 4: Create Key Vault
# ============================================================================

Write-Section "STEP 4: Creating Key Vault"

Write-Step "Checking if Key Vault already exists..."
$kvExists = az keyvault show --resource-group $config.ResourceGroup --name $config.KeyVaultName --query 'name' -o tsv 2>$null
if ($kvExists) {
    Write-Success "Key Vault already exists: $($config.KeyVaultName)"
}
else {
    Write-Step "Creating Key Vault: $($config.KeyVaultName)..."
    az keyvault create `
        --resource-group $config.ResourceGroup `
        --name $config.KeyVaultName `
        --location $config.Region `
        --sku $config.KeyVaultSku `
        --enable-rbac-authorization $true
    Write-Success "Key Vault created: $($config.KeyVaultName)"
}

Write-Step "Verifying Key Vault access..."
$kvId = az keyvault show --resource-group $config.ResourceGroup --name $config.KeyVaultName --query 'id' -o tsv
Write-Success "Key Vault ID: $kvId"

Write-Step "Adding sample secrets to Key Vault..."
# Add PostcodeApi endpoint (non-sensitive example)
az keyvault secret set `
    --vault-name $config.KeyVaultName `
    --name "PostcodesApiEndpoint" `
    --value $config.PostcodesApiEndpoint `
    --description "Postcodes.io API endpoint" > $null
Write-Success "Secret added: PostcodesApiEndpoint"

# Add a placeholder API key (user should update this)
az keyvault secret set `
    --vault-name $config.KeyVaultName `
    --name "PostcodesApiKey" `
    --value "YOUR_API_KEY_HERE" `
    --description "Postcodes.io API key (update after deployment)" > $null
Write-Success "Secret added: PostcodesApiKey"

Write-Step "Listing secrets in Key Vault..."
$secrets = az keyvault secret list --vault-name $config.KeyVaultName --query '[].name' -o tsv
foreach ($secret in $secrets) {
    Write-Host "  • $secret"
}

Write-Success "Key Vault configured with secrets!"

# ============================================================================
# STEP 5: Create Azure Container Registry (ACR)
# ============================================================================

Write-Section "STEP 5: Creating Azure Container Registry"

Write-Step "Checking if ACR already exists..."
$acrExists = az acr show --resource-group $config.ResourceGroup --name $config.AcrName --query 'name' -o tsv 2>$null
if ($acrExists) {
    Write-Success "ACR already exists: $($config.AcrName)"
}
else {
    Write-Step "Creating ACR: $($config.AcrName) (SKU: $($config.AcrSku))..."
    az acr create `
        --resource-group $config.ResourceGroup `
        --name $config.AcrName `
        --sku $config.AcrSku `
        --location $config.Region `
        --admin-enabled $config.AcrAdminEnabled
    Write-Success "ACR created: $($config.AcrName)"
}

Write-Step "Getting ACR login server..."
$acrLoginServer = az acr show --resource-group $config.ResourceGroup --name $config.AcrName --query 'loginServer' -o tsv
Write-Success "ACR Login Server: $acrLoginServer"

Write-Step "Getting ACR admin credentials..."
$acrAdminCreds = az acr credential show --resource-group $config.ResourceGroup --name $config.AcrName --query '[username, passwords[0].value]' -o tsv
$acrUsername = $acrAdminCreds.Split("`t")[0]
$acrPassword = $acrAdminCreds.Split("`t")[1]
Write-Success "ACR Admin Username: $acrUsername"
Write-Success "ACR Admin Password: $($acrPassword.Substring(0, 8))..."

Write-Step "Storing ACR credentials in Key Vault..."
az keyvault secret set `
    --vault-name $config.KeyVaultName `
    --name "AcrUsername" `
    --value $acrUsername > $null
az keyvault secret set `
    --vault-name $config.KeyVaultName `
    --name "AcrPassword" `
    --value $acrPassword > $null
az keyvault secret set `
    --vault-name $config.KeyVaultName `
    --name "AcrLoginServer" `
    --value $acrLoginServer > $null
Write-Success "ACR credentials stored in Key Vault"

# ============================================================================
# OPTIONAL: Push existing Docker image to ACR
# ============================================================================

Write-Section "OPTIONAL: Docker Image Setup"

Write-Host "To push your Docker image to ACR:" @warning
Write-Host ""
Write-Host "1. Build your Docker image:"
Write-Host "   docker build -t $acrLoginServer/addressapi:v1 ."
Write-Host ""
Write-Host "2. Login to ACR:"
Write-Host "   az acr login --name $($config.AcrName)"
Write-Host ""
Write-Host "3. Push the image:"
Write-Host "   docker push $acrLoginServer/addressapi:v1"
Write-Host ""
Write-Host "4. Verify image in ACR:"
Write-Host "   az acr repository list --name $($config.AcrName)"
Write-Host ""

# ============================================================================
# VALIDATION & SUMMARY
# ============================================================================

Write-Section "VALIDATION & SUMMARY"

Write-Step "Verifying Key Vault..."
$kvStatus = az keyvault show --resource-group $config.ResourceGroup --name $config.KeyVaultName --query 'name' -o tsv
Write-Success "Key Vault verified: $kvStatus"

Write-Step "Verifying ACR..."
$acrStatus = az acr show --resource-group $config.ResourceGroup --name $config.AcrName --query 'name' -o tsv
Write-Success "ACR verified: $acrStatus"

Write-Success "STEPS 4-5 COMPLETED SUCCESSFULLY!"
Write-Host ""
Write-Host "Created Resources:" @success
Write-Host "  • Key Vault: $($config.KeyVaultName)"
Write-Host "  • ACR: $($config.AcrName)"
Write-Host "  • ACR Login Server: $acrLoginServer"
Write-Host ""
Write-Host "Next Steps:" @warning
Write-Host "1. Update the PostcodesApiKey secret in Key Vault if needed"
Write-Host "2. Push your Docker image to ACR (see instructions above)"
Write-Host "3. Run the next script for Steps 6-7 (AKS Cluster)"
Write-Host ""
Write-Host "To continue, run: ./phase4-step6-7-aks-deployment.ps1" @success
