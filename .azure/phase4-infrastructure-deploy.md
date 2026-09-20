# Phase 4: Infrastructure as Code - Deployment Plan

**Status**: 🔄 IN PROGRESS  
**Date Started**: 2026-09-20  
**Resource Group**: rg-address-lookup  
**Region**: UK West (uksouth)  

## Deployment Strategy

This document outlines the step-by-step deployment of Azure infrastructure using Azure CLI commands in PowerShell. Each step includes validation to ensure resources are created correctly before proceeding to the next step.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Azure Subscription                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │        Resource Group: rg-address-lookup          │  │
│  │                                                     │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Virtual Network (VNet)                     │  │  │
│  │  │  - Subnet for AKS                           │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Azure Kubernetes Service (AKS)             │  │  │
│  │  │  - Node pool in AKS subnet                   │  │  │
│  │  │  - System nodes & user nodes                 │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Azure Container Registry (ACR)             │  │  │
│  │  │  - Private registry for images              │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Key Vault                                  │  │  │
│  │  │  - Secrets for API keys                     │  │  │
│  │  │  - Access policies for AKS identity         │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Application Insights                       │  │  │
│  │  │  - Monitoring & telemetry                   │  │  │
│  │  │  - Log Analytics workspace                  │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  │                                                     │  │
│  │  ┌─────────────────────────────────────────────┐  │  │
│  │  │  Managed Identity                           │  │  │
│  │  │  - For AKS pod authentication               │  │  │
│  │  └─────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Deployment Steps

### Step 1: Verify Prerequisites
- [ ] Azure CLI installed and authenticated
- [ ] Resource group `rg-address-lookup` exists in UK West
- [ ] Proper permissions (Contributor or Owner role)

### Step 2: Create Virtual Network
- [ ] Create VNet with CIDR block (e.g., 10.0.0.0/16)
- [ ] Create AKS subnet (e.g., 10.0.1.0/24)
- [ ] Verify VNet creation

### Step 3: Create Application Insights & Log Analytics
- [ ] Create Log Analytics workspace
- [ ] Create Application Insights instance
- [ ] Configure connections

### Step 4: Create Key Vault
- [ ] Create Azure Key Vault
- [ ] Store secrets (Postcodes.io endpoint)
- [ ] Configure network rules if needed
- [ ] Test secret retrieval

### Step 5: Create Container Registry (ACR)
- [ ] Create ACR in Premium SKU for webhook/geo-replication support
- [ ] Enable admin access temporarily for push
- [ ] Verify connectivity

### Step 6: Create AKS Cluster
- [ ] Create managed identity for AKS
- [ ] Create AKS cluster with:
  - System nodepool (critical system pods)
  - User nodepool (application pods)
  - Network integration with VNet/Subnet
  - Managed identity
  - Application Insights integration
  - Default monitoring enabled
- [ ] Verify cluster creation and health

### Step 7: Configure AKS Identity & RBAC
- [ ] Create managed identity for pod authentication
- [ ] Assign role-based access:
  - AKS cluster identity → ACR pull access
  - Pod identity → Key Vault access
- [ ] Configure pod identity bindings

### Step 8: Verify All Resources
- [ ] Check all resources exist
- [ ] Verify networking connectivity
- [ ] Test access patterns

### Step 9: Cost Estimation
- [ ] Document resource SKUs
- [ ] Estimate monthly costs
- [ ] Review cost optimization opportunities

## Environment Variables

```powershell
# Set these in your deployment script
$SUBSCRIPTION_ID = "<your-subscription-id>"
$RESOURCE_GROUP = "rg-address-lookup"
$REGION = "uksouth"
$APP_NAME = "address-lookup"

# VNet Configuration
$VNET_NAME = "vnet-$APP_NAME"
$VNET_CIDR = "10.0.0.0/16"
$AKS_SUBNET_NAME = "subnet-aks"
$AKS_SUBNET_CIDR = "10.0.1.0/24"

# AKS Configuration
$AKS_CLUSTER_NAME = "aks-$APP_NAME"
$AKS_NODEPOOL_NAME = "nodepool1"
$AKS_NODE_COUNT = 2
$AKS_VM_SIZE = "Standard_B2s"

# ACR Configuration
$ACR_NAME = "acr${APP_NAME//-/}"  # Remove hyphens for ACR name
$ACR_SKU = "Premium"

# Key Vault Configuration
$KEYVAULT_NAME = "kv-$APP_NAME"

# Application Insights
$APP_INSIGHTS_NAME = "appinsights-$APP_NAME"
$LOG_ANALYTICS_NAME = "la-$APP_NAME"

# Managed Identity
$AKS_IDENTITY_NAME = "identity-$APP_NAME-aks"
$POD_IDENTITY_NAME = "identity-$APP_NAME-pod"
```

## Key Learnings

- **VNet First**: Create networking before AKS for better control over IP ranges and isolation
- **Managed Identities**: Use managed identities instead of shared keys for security
- **Network Policies**: Will be configured in Phase 5 once AKS is running
- **Monitoring**: Application Insights should be wired from the start
- **RBAC**: Use least-privilege access for identities

## Success Criteria

✅ All resources created successfully  
✅ Resources accessible via Azure CLI queries  
✅ Networking allows pod-to-pod communication  
✅ Identities configured with proper RBAC  
✅ Cost estimate documented  

## Next Phase

Phase 5 will deploy Kubernetes manifests to the AKS cluster created in this phase.
