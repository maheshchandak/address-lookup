using './main.bicep'

param location = 'uksouth'
param environment = 'dev'
param projectName = 'address-lookup'
param kubernetesVersion = '1.37.0'
param nodeCount = 1
param vmSize = 'Standard_D2s_v3'

// GitHub Actions OIDC Federation (set enableGitHubFederated=true and provide subject claim to auto-create federated credential)
param enableGitHubFederated = false
param githubFederatedSubject = ''
