@description('Azure region for resources')
param location string = 'uksouth'

@description('Environment name (dev, staging, prod)')
param environment string = 'dev'

@description('Project name')
param projectName string = 'address-lookup'

@description('AKS cluster kubernetes version')
param kubernetesVersion string = '1.37.0'

@description('AKS node count')
param nodeCount int = 1

@description('AKS VM size')
param vmSize string = 'Standard_D2s_v3'

// Variables
var resourceGroupName = 'rg-${projectName}'
var acrName = replace('acr${projectName}', '-', '')
var aksClusterName = 'aks-${projectName}'
var keyVaultName = 'kv-${projectName}-${uniqueString(resourceGroup().id)}'
var vnetName = 'vnet-${projectName}'
var managedIdentityName = 'uami-${projectName}'
var appInsightsName = 'appi-${projectName}'
var workspaceName = 'law-${projectName}'

// VNet configuration
var vnetAddressPrefix = '10.0.0.0/16'
var aksSubnetPrefix = '10.0.1.0/24'
var vmSubnetPrefix = '10.0.2.0/24'

// Tags
var tags = {
  environment: environment
  project: projectName
  createdBy: 'GitHub Actions'
  createdDate: utcNow('u')
}

// Log Analytics Workspace
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    RetentionInDays: 30
    WorkspaceResourceId: workspace.id
  }
}

// Managed Identity for GitHub Actions and AKS pods
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: aksSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.ContainerRegistry'
            }
            {
              service: 'Microsoft.KeyVault'
            }
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
      {
        name: 'vm-subnet'
        properties: {
          addressPrefix: vmSubnetPrefix
        }
      }
    ]
  }
}

// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
  }
}

// Grant Key Vault access to Managed Identity
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: 'add'
  parent: keyVault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: managedIdentity.properties.principalId
        permissions: {
          keys: [
            'get'
            'list'
          ]
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Grant AKS access to ACR
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2023-04-01-preview' = {
  scope: acr
  name: guid(acr.id, managedIdentity.id, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-338473d6067b') // AcrPull role
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-02-preview' = {
  name: aksClusterName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    enableRBAC: true
    dnsPrefix: projectName
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: vmSize
        mode: 'System'
        osType: 'Linux'
        vnetSubnetID: '${vnet.id}/subnets/aks-subnet'
        maxPods: 110
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspace.id
        }
      }
      azurepolicy: {
        enabled: false
      }
    }
  }
}

// Grant AKS managed identity access to ACR
resource aksAcrRoleAssignment 'Microsoft.Authorization/roleAssignments@2023-04-01-preview' = {
  scope: acr
  name: guid(acr.id, aksCluster.identity.principalId, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-338473d6067b') // AcrPull role
    principalId: aksCluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output aksClusterName string = aksCluster.name
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output keyVaultName string = keyVault.name
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output workspaceId string = workspace.id
output vnetId string = vnet.id
