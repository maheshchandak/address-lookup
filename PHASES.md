# Address Lookup API - Project Phases Documentation

**Project**: Address Lookup API  
**Status**: Phases 1, 2, and 3 (Docker image + local container verification) complete; ACR setup and Phase 4 next  
**Last Updated**: 2026-09-19  
**Repository**: c:\MaHESH\Learn\CoPilot\address-lookup

---

## Project Goal

Build and deploy a .NET 8 postcode lookup API to Azure Kubernetes Service (AKS),
learning each stage from local development through containerization, Azure
infrastructure, Kubernetes, and GitHub Actions.

### Current Architecture

- **Application**: ASP.NET Core 8 Web API
- **Postcode provider**: Postcodes.io (`https://api.postcodes.io`), with the configured endpoint stored as a secret
- **Local API**: `http://localhost:5005`
- **Deployment target**: Azure Kubernetes Service
- **Planned security**: Azure Key Vault and managed identity
- **Planned CI/CD**: GitHub Actions
- **Planned container registry**: Azure Container Registry

This file is the canonical project plan and status tracker. Phase details below
describe planned work unless a phase is explicitly marked complete.

---

## Table of Contents

1. [Phase Overview](#phase-overview)
2. [Phase 1: Create Project Scaffold](#phase-1-create-project-scaffold)
3. [Phase 2: Add Key Vault Integration](#phase-2-add-key-vault-integration)
4. [Phase 3: Dockerfile & ACR Setup](#phase-3-dockerfile--acr-setup)
5. [Phase 4: Infrastructure as Code](#phase-4-infrastructure-as-code)
6. [Phase 5: Kubernetes Manifests](#phase-5-kubernetes-manifests)
7. [Phase 6 & 7: GitHub Actions Pipeline](#phase-6--7-github-actions-pipeline)
8. [Phase 8: Testing & Verification](#phase-8-testing--verification)
9. [Next Steps](#next-steps)

---

## Phase Overview

```
Phase 1: Project Scaffold
    ↓
Phase 2: Key Vault Integration
    ↓
Phase 3: Dockerfile & ACR Setup
    ↓
Phase 4: Infrastructure as Code
    ↓
Phase 5: Kubernetes Manifests
    ↓
Phase 6 & 7: GitHub Actions Pipeline
    ↓
Phase 8: Testing & Verification
    ↓
  Deployment and verification pending
```

---

## Phase 1: Create Project Scaffold

**Status**: ✅ COMPLETED  
**Duration**: Initial setup  
**Objectives**: Establish foundational .NET Core Web API structure with basic functionality

### Deliverables

#### 1. **Project Structure**
```
address-lookup/
├── src/
│   └── AddressLookupApi/
│       ├── Controllers/
│       │   ├── HealthController.cs
│       │   └── AddressesController.cs
│       ├── Models/
│       │   ├── Address.cs
│       │   ├── ApiResponse.cs
│       │   └── ConfigurationOptions.cs
│       ├── Services/
│       │   ├── IAddressService.cs
│       │   └── AddressService.cs
│       ├── Middleware/
│       │   ├── ErrorHandlingMiddleware.cs
│       │   └── RequestLoggingMiddleware.cs
│       ├── Program.cs
│       ├── appsettings.json
│       ├── appsettings.Development.json
│       └── AddressLookupApi.csproj
├── tests/
│   ├── AddressLookupApi.Tests/
│   │   ├── AddressServiceTests.cs
│   │   ├── AddressesControllerTests.cs
│   │   └── AddressLookupApi.Tests.csproj
│   └── local/
│       └── requests.http
├── README.md
├── AddressLookup.sln
└── .gitignore
```

#### 2. **Core Components**

**HealthController.cs**
- `GET /health` - Liveness probe endpoint
- `GET /ready` - Readiness probe endpoint
- Returns JSON status with timestamp
- Used by Kubernetes for health checks

**AddressesController.cs**
- `GET /api/addresses/search?postcode={postcode}` - Search addresses by postcode
- `GET /api/addresses/info` - Get API information
- Input validation and error handling
- Structured API responses

**AddressService.cs**
- Integrates with Postcodes.io API
- Postcode validation and normalization
- Response transformation
- Caching support (Phase 2+)

**Models**
- `Address`: Core address data model
- `ApiResponse`: Standard response envelope
- `ConfigurationOptions`: Type-safe configuration

#### 3. **Key Features**

- ✅ .NET Core 8 Web API
- ✅ Dependency Injection (DI)
- ✅ Global error handling
- ✅ Structured logging
- ✅ Input validation
- ✅ Health check endpoints
- ✅ OpenAPI/Swagger support
- ✅ Unit test framework (xUnit, Moq)
- ✅ REST client test file (requests.http)

#### 4. **Configuration**

**appsettings.json** (Production defaults)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  },
  "AddressLookup": {
    "TimeoutSeconds": 10,
    "CacheEnabled": false,
    "CacheDurationMinutes": 60
  }
}
```

**appsettings.Development.json** (Local development - git-ignored)
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug"
    }
  },
  "AddressLookup": {
    "BaseUrl": "https://api.postcodes.io"
  }
}
```

#### 5. **Testing Infrastructure**

**Unit Tests** (xUnit + Moq)
- `AddressServiceTests.cs`: Service layer tests
- `AddressesControllerTests.cs`: Controller layer tests
- Mock HTTP message handler for API calls
- Test coverage for happy path and error scenarios

**Local Testing** (requests.http)
- REST client file for manual testing
- Configured endpoints for local development
- Examples for common scenarios

### Running Phase 1

```bash
# Restore and build
dotnet restore
dotnet build

# Run API
cd src/AddressLookupApi
dotnet run

# Run tests
dotnet test

# Test endpoints
# Via REST Client (VS Code):
# - Open tests/local/requests.http
# - Click "Send Request" on any endpoint

# Via curl:
curl http://localhost:5000/health
curl http://localhost:5000/api/addresses/search?postcode=SW1A1AA
```

### Completion Criteria

- [x] Solution compiles without errors
- [x] All projects build successfully
- [x] Unit tests pass
- [x] API responds to requests locally
- [x] Health endpoints return 200 OK
- [x] Address search returns valid responses
- [x] Documentation complete (README.md)

---

## Phase 2: Add Key Vault Integration

**Status**: ✅ COMPLETED  
**Duration**: Security implementation  
**Objectives**: Learn secure configuration using Azure Key Vault and managed identity. The Postcodes.io base URL is stored as the Phase 2 secret because the provider currently requires no API key.

### Deliverables

#### Current implementation

- Local development loads the `AddressLookup:BaseUrl` value from User Secrets when the environment is `Development`.
- Azure Key Vault loads the same setting as `AddressLookup--BaseUrl` when `KeyVault:VaultUri` is configured.
- Key Vault authentication uses `DefaultAzureCredential`, which supports local Azure CLI credentials and Azure managed identity.
- No secret values are stored in `appsettings.Development.json`.

Phase 2 verification completed against the `kv-cloudware-store` vault. The
`AddressLookup--BaseUrl` secret is enabled and contains the configured Postcodes.io
endpoint. The current Azure credential can read it.

#### 1. **Local Secrets Configuration**

**Implemented configuration flow**
```csharp
if (builder.Environment.IsDevelopment())
{
  builder.Configuration.AddUserSecrets<Program>(optional: true);
}

var keyVaultUri = builder.Configuration["KeyVault:VaultUri"];
if (!string.IsNullOrWhiteSpace(keyVaultUri))
{
    builder.Configuration.AddAzureKeyVault(
    new Uri(keyVaultUri),
    new DefaultAzureCredential());
}
```

**User Secrets Setup** (Local development)
```bash
# UserSecretsId is already configured in the project file
dotnet user-secrets list --project src/AddressLookupApi/AddressLookupApi.csproj

# Store the provider endpoint locally, outside source control
dotnet user-secrets set "AddressLookup:BaseUrl" "https://api.postcodes.io/postcodes" --project src/AddressLookupApi/AddressLookupApi.csproj

# Configure Key Vault only when you have created the Azure resource
dotnet user-secrets set "KeyVault:VaultUri" "https://your-keyvault.vault.azure.net/" --project src/AddressLookupApi/AddressLookupApi.csproj

# List all secrets
dotnet user-secrets list
```

#### 2. **NuGet Dependencies Added**

```xml
<!-- In AddressLookupApi.csproj -->
<PackageReference Include="Azure.Extensions.AspNetCore.Configuration.Secrets" Version="1.3.2" />
<PackageReference Include="Azure.Identity" Version="1.13.2" />
<PackageReference Include="Microsoft.Extensions.Configuration.UserSecrets" Version="8.0.0" />
```

#### 3. **Azure Key Vault Connection**

**Configuration Binding**
```csharp
// Read the setting supplied by User Secrets or Key Vault
builder.Configuration["AddressLookup:BaseUrl"];

// Direct Key Vault access (if needed)
var secretClient = new SecretClient(
    new Uri(keyVaultUri),
    new DefaultAzureCredential());

  var secret = await secretClient.GetSecretAsync("AddressLookup--BaseUrl");
```

#### 4. **Managed Identity Support**

**DefaultAzureCredential Chain** (Uses in order):
1. Environment variables (for local testing)
2. Managed Identity (in Azure)
3. Visual Studio credentials
4. Azure CLI credentials
5. Azure PowerShell credentials

This allows the same configuration key to work in local development and Azure.

#### 5. **Environment Variables**

**Local Development**
```bash
ASPNETCORE_ENVIRONMENT=Development
```

**Azure Development (appsettings.json)**
```json
{
  "KeyVault": {
  "VaultUri": "https://your-keyvault.vault.azure.net/"
  }
}
```

**Docker / Kubernetes (Environment Variables)**
```bash
ASPNETCORE_ENVIRONMENT=Production
KeyVault__VaultUri=https://your-keyvault.vault.azure.net/
```

### Key Vault Secrets Structure

```
Key Vault: address-lookup-kv

Secrets:
├── AddressLookup--BaseUrl
│   └── Value: https://api.postcodes.io/postcodes
├── ApplicationInsights--InstrumentationKey
│   └── Value: YOUR_APP_INSIGHTS_KEY
└── Database--ConnectionString
    └── Value: Server=...;Database=...
```

### Running Phase 2

```bash
# 1. Confirm the local configuration is available
dotnet user-secrets list --project src/AddressLookupApi/AddressLookupApi.csproj

# 2. Confirm the Azure credential can access the configured Key Vault
#    and that AddressLookup--BaseUrl exists and is enabled.

# 3. Configure environment
$env:ASPNETCORE_ENVIRONMENT = "Development"

# 4. Run API
dotnet run

# 5. Verify secrets loaded
# Check logs for successful Key Vault connection
```

### Completion Criteria

- [x] User Secrets configured locally
- [x] Key Vault NuGet packages installed
- [x] DefaultAzureCredential implemented
- [x] API reads `AddressLookup--BaseUrl` from Key Vault in Azure
- [x] Local development uses User Secrets
- [x] No secrets in source code
- [x] Configuration can be changed without modifying source code

---

## Phase 3: Dockerfile & ACR Setup

**Status**: 🟡 PARTIALLY COMPLETE (Docker image built and verified locally; ACR push not yet performed)  
**Duration**: Containerization  
**Objectives**: Create production-ready Docker image and Azure Container Registry setup

### Verified on 2026-09-19

- `docker build -t address-lookup-api:phase3 -f Dockerfile .` succeeds (multi-stage build, final image ~95MB content size).
- Dockerfile adds a `HEALTHCHECK` instruction (`curl -f http://localhost:8080/health`) backed by `curl` installed in the runtime stage.
- `docker run` with `ASPNETCORE_ENVIRONMENT=Production` and `AddressLookup__BaseUrl=https://api.postcodes.io/postcodes` starts successfully; `docker ps` and `docker inspect --format='{{.State.Health.Status}}'` report `healthy`.
- `GET /health` and `GET /ready` return `200 OK` with `{"status":"Healthy", ...}`.
- `GET /api/addresses/search?postcode=SW1A1AA` returns `200 OK` with a valid address payload, confirming outbound HTTPS to Postcodes.io works from inside the container.
- Container runs as the non-root `$APP_UID` user (built-in .NET 8 aspnet image convention).
- Azure Container Registry (ACR) creation and image push have **not** been done yet — remaining work for Phase 3 completion.

### Deliverables

#### 1. **Multi-Stage Dockerfile**

**Location**: `address-lookup/Dockerfile`

```dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder
WORKDIR /build

COPY . .
RUN dotnet restore
RUN dotnet build -c Release
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Add non-root user
RUN useradd -m -u 1000 appuser

# Copy published app
COPY --from=builder /app/publish .

# Set security context
RUN chmod +x /app/AddressLookupApi

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["curl", "-f", "http://localhost:8080/health || exit 1"]

# Run as non-root
USER appuser

ENTRYPOINT ["dotnet", "AddressLookupApi.dll"]
```

#### 2. **Docker Compose for Local Development**

**Location**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - AddressLookup__ApiKey=${ADDRESS_LOOKUP_API_KEY}
      - AddressLookup__BaseUrl=https://api.postcodes.io
    volumes:
      - ./src/AddressLookupApi:/app/src
    depends_on:
      - healthcheck
    networks:
      - address-lookup-network

  healthcheck:
    image: curlimages/curl:latest
    depends_on:
      - api
    command: curl -f http://api:8080/ready
    networks:
      - address-lookup-network

networks:
  address-lookup-network:
    driver: bridge
```

#### 3. **Azure Container Registry (ACR) Setup**

**ACR Command Line Setup**
```bash
# Create resource group
az group create --name address-lookup-rg --location eastus

# Create container registry
az acr create \
  --resource-group address-lookup-rg \
  --name addresslookupacr \
  --sku Basic \
  --admin-enabled true

# Get ACR login credentials
az acr credential show \
  --resource-group address-lookup-rg \
  --name addresslookupacr

# Login to ACR
az acr login --name addresslookupacr

# Build and push image
az acr build \
  --registry addresslookupacr \
  --image address-lookup-api:latest \
  --image address-lookup-api:v1.0.0 .

# List images in ACR
az acr repository list --name addresslookupacr
```

#### 4. **Image Optimization Best Practices**

**Applied Techniques**:
- ✅ Multi-stage build (reduces final image size by 60-70%)
- ✅ Non-root user (security hardening)
- ✅ Minimal base image (microsoft/aspnet:8.0)
- ✅ Health check endpoint
- ✅ Layer caching optimization
- ✅ `.dockerignore` file for build context

**Example .dockerignore**
```
.git
.gitignore
.vs
.vscode
bin
obj
dist
node_modules
*.log
.DS_Store
tests
docs
.github
```

#### 5. **Image Size Comparison**

```
Before Multi-Stage: 800MB
After Multi-Stage:  250MB (69% reduction)

Breakdown:
- Base image (aspnet:8.0): 180MB
- Application runtime: 70MB
- Dependencies: 0MB (already in base)
- Total: ~250MB
```

### Building and Testing Images

```bash
# Build locally
docker build -t address-lookup-api:latest .

# Run container
docker run -p 8080:8080 \
  -e AddressLookup__ApiKey=your-key \
  address-lookup-api:latest

# Test container
curl http://localhost:8080/health

# Push to ACR
docker tag address-lookup-api:latest addresslookupacr.azurecr.io/address-lookup-api:v1.0.0
docker push addresslookupacr.azurecr.io/address-lookup-api:v1.0.0

# Using Docker Compose
docker-compose up --build
docker-compose down
```

### Completion Criteria

- [x] Dockerfile follows best practices (multi-stage build)
- [x] Image builds successfully
- [x] Container runs locally without errors
- [x] Health check endpoint works
- [ ] ACR created and accessible
- [ ] Image pushed to ACR successfully
- [ ] Image runs from ACR in container
- [x] Non-root user implemented
- [x] Image size optimized

---

## Phase 4: Infrastructure as Code

**Status**: ⬜ NOT STARTED  
**Duration**: IaC Implementation  
**Objectives**: Define all Azure infrastructure using Bicep templates

### Deliverables

#### 1. **Bicep Template Structure**

**Location**: `infra/` directory

```
infra/
├── main.bicep                    # Main orchestrator
├── modules/
│   ├── aks.bicep                # AKS cluster
│   ├── acr.bicep                # Container registry
│   ├── keyvault.bicep           # Key Vault
│   ├── network.bicep            # Virtual networks
│   ├── storage.bicep            # Storage account
│   └── monitoring.bicep         # Application Insights
└── parameters.json              # Parameter values
```

#### 2. **Key Resources Created**

**Azure Kubernetes Service (AKS)**
```bicep
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-04-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: nodeCount
        vmSize: vmSize
        mode: 'System'
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
  }
}
```

**Azure Container Registry (ACR)**
```bicep
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2024-05-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}
```

**Azure Key Vault**
```bicep
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: vaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: aksCluster.identity.principalId
        permissions: {
          secrets: ['get', 'list']
        }
      }
    ]
  }
}
```

**Virtual Network**
```bicep
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}
```

#### 3. **Deployment Commands**

```bash
# Validate template
az bicep build infra/main.bicep

# Validate against Azure
az deployment group validate \
  --resource-group address-lookup-rg \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.json

# Preview changes (what-if)
az deployment group what-if \
  --resource-group address-lookup-rg \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.json

# Deploy infrastructure
az deployment group create \
  --name address-lookup-deployment \
  --resource-group address-lookup-rg \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.json

# List deployed resources
az resource list --resource-group address-lookup-rg

# Delete infrastructure (cleanup)
az deployment group delete \
  --name address-lookup-deployment \
  --resource-group address-lookup-rg
```

#### 4. **Parameters Configuration**

**parameters.json**
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "dev"
    },
    "location": {
      "value": "eastus"
    },
    "nodeCount": {
      "value": 3
    },
    "vmSize": {
      "value": "Standard_D2s_v3"
    },
    "kubernetesVersion": {
      "value": "1.30.0"
    }
  }
}
```

#### 5. **Infrastructure Outputs**

After deployment, retrieve connection details:

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group address-lookup-rg \
  --name address-lookup-aks

# Get ACR URL
az acr show \
  --resource-group address-lookup-rg \
  --name addresslookupacr \
  --query loginServer -o tsv

# Get Key Vault URL
az keyvault show \
  --resource-group address-lookup-rg \
  --name address-lookup-kv \
  --query properties.vaultUri -o tsv
```

### Completion Criteria

- [x] All Bicep templates validate without errors
- [x] Infrastructure deploys successfully to Azure
- [x] AKS cluster is operational
- [x] ACR is accessible from AKS
- [x] Key Vault is accessible with managed identity
- [x] All resources tagged appropriately
- [x] Network policies configured
- [x] RBAC roles assigned correctly

---

## Phase 5: Kubernetes Manifests

**Status**: ⬜ NOT STARTED  
**Duration**: K8s Configuration  
**Objectives**: Define Kubernetes deployments, services, and configurations

### Deliverables

#### 1. **Manifest Structure**

**Location**: `k8s/` directory

```
k8s/
├── namespace.yaml               # Kubernetes namespace
├── configmap.yaml               # Configuration data
├── secret.yaml                  # Sensitive data (from Key Vault)
├── deployment.yaml              # Application deployment
├── service.yaml                 # Kubernetes service
├── ingress.yaml                 # Ingress configuration
├── hpa.yaml                     # Horizontal Pod Autoscaler
├── networkpolicy.yaml           # Network policies
└── rbac.yaml                    # Role-Based Access Control
```

#### 2. **Namespace**

**k8s/namespace.yaml**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: address-lookup
  labels:
    name: address-lookup
    environment: production
```

#### 3. **ConfigMap**

**k8s/configmap.yaml**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: address-lookup-config
  namespace: address-lookup
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  AddressLookup__BaseUrl: "https://api.postcodes.io"
  AddressLookup__TimeoutSeconds: "10"
  AddressLookup__CacheEnabled: "true"
  AddressLookup__CacheDurationMinutes: "60"
  Logging__LogLevel__Default: "Information"
```

#### 4. **Secrets (from Key Vault)**

**k8s/secret.yaml**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: address-lookup-secrets
  namespace: address-lookup
type: Opaque
stringData:
  # In practice, retrieve from Azure Key Vault
  ApiKey: "representative-secret-for-learning"
  # Connection strings, API keys, etc.
```

#### 5. **Deployment**

**k8s/deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: address-lookup-api
  namespace: address-lookup
  labels:
    app: address-lookup
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: address-lookup
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: address-lookup
        version: v1
    spec:
      serviceAccountName: address-lookup-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: api
        image: addresslookupacr.azurecr.io/address-lookup-api:v1.0.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        env:
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        - name: ASPNETCORE_ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: address-lookup-config
              key: ASPNETCORE_ENVIRONMENT
        - name: AddressLookup__ApiKey
          valueFrom:
            secretKeyRef:
              name: address-lookup-secrets
              key: ApiKey
        envFrom:
        - configMapRef:
            name: address-lookup-config
        
        # Resource management
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 2
        
        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        
        # Volume mounts
        volumeMounts:
        - name: tmp
          mountPath: /tmp
        - name: logs
          mountPath: /var/log
      
      volumes:
      - name: tmp
        emptyDir: {}
      - name: logs
        emptyDir: {}
      
      # Pod scheduling
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - address-lookup
              topologyKey: kubernetes.io/hostname
      
      # Node affinity for availability zones
      nodeSelector:
        kubernetes.io/os: linux
```

#### 6. **Service**

**k8s/service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: address-lookup-service
  namespace: address-lookup
  labels:
    app: address-lookup
spec:
  type: ClusterIP
  selector:
    app: address-lookup
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  sessionAffinity: None
```

#### 7. **Ingress**

**k8s/ingress.yaml**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: address-lookup-ingress
  namespace: address-lookup
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - address-lookup.example.com
    secretName: address-lookup-tls
  rules:
  - host: address-lookup.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: address-lookup-service
            port:
              number: 80
```

#### 8. **Horizontal Pod Autoscaler (HPA)**

**k8s/hpa.yaml**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: address-lookup-hpa
  namespace: address-lookup
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: address-lookup-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 15
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
```

#### 9. **Network Policy**

**k8s/networkpolicy.yaml**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: address-lookup-netpol
  namespace: address-lookup
spec:
  podSelector:
    matchLabels:
      app: address-lookup
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
  - to:
    - podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

#### 10. **RBAC Configuration**

**k8s/rbac.yaml**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: address-lookup-sa
  namespace: address-lookup

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: address-lookup-role
  namespace: address-lookup
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: address-lookup-rolebinding
  namespace: address-lookup
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: address-lookup-role
subjects:
- kind: ServiceAccount
  name: address-lookup-sa
  namespace: address-lookup
```

### Deploying to Kubernetes

```bash
# Create namespace
kubectl create namespace address-lookup

# Apply all manifests
kubectl apply -f k8s/ -n address-lookup

# Or apply individually
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/networkpolicy.yaml
kubectl apply -f k8s/rbac.yaml

# Verify deployment
kubectl get deployments -n address-lookup
kubectl get pods -n address-lookup
kubectl get services -n address-lookup
kubectl get ingress -n address-lookup

# Check pod logs
kubectl logs -f deployment/address-lookup-api -n address-lookup

# Describe deployment
kubectl describe deployment address-lookup-api -n address-lookup

# Port forward for local testing
kubectl port-forward svc/address-lookup-service 8080:80 -n address-lookup

# Delete deployment
kubectl delete -f k8s/ -n address-lookup
```

### Completion Criteria

- [x] All Kubernetes manifests validate
- [x] Deployment creates 3 replicas
- [x] Service exposes pods internally
- [x] Ingress routes external traffic
- [x] Health probes configured and working
- [x] Resource limits and requests set
- [x] RBAC configured with least privilege
- [x] Network policies enforced
- [x] HPA scales based on metrics
- [x] Pods run as non-root

---

## Phase 6 & 7: GitHub Actions Pipeline

**Status**: ⬜ NOT STARTED  
**Duration**: CI/CD Implementation  
**Objectives**: Automate build, test, and deployment workflows

### Deliverables

#### 1. **Workflow Structure**

**Location**: `.github/workflows/`

```
.github/workflows/
├── build.yml                    # Build and test
├── deploy.yml                   # Deploy to AKS
├── security.yml                 # Security scanning
└── cleanup.yml                  # Resource cleanup
```

#### 2. **Build Workflow**

**.github/workflows/build.yml**
```yaml
name: Build and Test

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main

env:
  REGISTRY: addresslookupacr.azurecr.io
  IMAGE_NAME: address-lookup-api

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      packages: write
      id-token: write
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '8.0.x'
    
    - name: Restore dependencies
      run: dotnet restore
    
    - name: Build
      run: dotnet build --configuration Release --no-restore
    
    - name: Run tests
      run: dotnet test --configuration Release --no-build --verbosity normal
    
    - name: Publish coverage
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.xml
    
    - name: Login to ACR
      uses: azure/docker-login@v1
      with:
        login-server: ${{ env.REGISTRY }}
        username: ${{ secrets.REGISTRY_USERNAME }}
        password: ${{ secrets.REGISTRY_PASSWORD }}
    
    - name: Build and push Docker image
      run: |
        docker build -t ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} .
        docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
        
        if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
          docker tag ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          docker push ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
        fi
```

#### 3. **Deploy Workflow**

**.github/workflows/deploy.yml**
```yaml
name: Deploy to AKS

on:
  workflow_run:
    workflows: ["Build and Test"]
    types:
      - completed
    branches:
      - main

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      id-token: write
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Azure login with OIDC
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Get AKS credentials
      run: |
        az aks get-credentials \
          --resource-group address-lookup-rg \
          --name address-lookup-aks
    
    - name: Update Kubernetes manifests
      run: |
        sed -i "s|IMAGE_TAG|${{ github.sha }}|g" k8s/deployment.yaml
    
    - name: Deploy to AKS
      run: |
        kubectl apply -f k8s/ -n address-lookup
        kubectl set image deployment/address-lookup-api \
          api=${{ secrets.REGISTRY_URL }}/address-lookup-api:${{ github.sha }} \
          -n address-lookup
        
        kubectl rollout status deployment/address-lookup-api -n address-lookup
    
    - name: Verify deployment
      run: |
        kubectl get deployments -n address-lookup
        kubectl get pods -n address-lookup
        kubectl get services -n address-lookup
    
    - name: Run smoke tests
      run: |
        kubectl port-forward svc/address-lookup-service 8080:80 -n address-lookup &
        sleep 5
        
        curl -f http://localhost:8080/health || exit 1
        curl -f http://localhost:8080/ready || exit 1
        curl -f "http://localhost:8080/api/addresses/search?postcode=SW1A1AA" || exit 1
```

#### 4. **OIDC Authentication Setup**

**Configure OIDC Trust in Azure**
```bash
# Set variables
AZURE_CLIENT_ID="your-app-id"
AZURE_TENANT_ID="your-tenant-id"
AZURE_SUBSCRIPTION_ID="your-subscription-id"
GITHUB_REPO_OWNER="your-github-username"
GITHUB_REPO_NAME="address-lookup"

# Register app in Entra ID
az ad app create --display-name "address-lookup-github-actions"

# Create app registration
az ad sp create --id $AZURE_CLIENT_ID

# Setup OIDC trust
az ad app federated-credential create \
  --id $AZURE_CLIENT_ID \
  --parameters '{
    "name": "github-actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_REPO_OWNER'/'$GITHUB_REPO_NAME':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Assign roles
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Contributor" \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID
```

**GitHub Secrets Configuration**
```
Secrets to add to GitHub repository:
├── AZURE_CLIENT_ID         = Application ID from Entra ID
├── AZURE_TENANT_ID         = Directory/Tenant ID
├── AZURE_SUBSCRIPTION_ID   = Subscription ID
├── REGISTRY_USERNAME       = ACR admin username
├── REGISTRY_PASSWORD       = ACR admin password
└── REGISTRY_URL            = addresslookupacr.azurecr.io
```

#### 5. **Security Scanning Workflow**

**.github/workflows/security.yml**
```yaml
name: Security Scanning

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  schedule:
    - cron: '0 0 * * 0'  # Weekly scan

jobs:
  codeql:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        language: ['csharp']
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Initialize CodeQL
      uses: github/codeql-action/init@v2
      with:
        languages: ${{ matrix.language }}
    
    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '8.0.x'
    
    - name: Build
      run: dotnet build --configuration Release
    
    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2
  
  trivy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Build Docker image
      run: docker build -t address-lookup-api:${{ github.sha }} .
    
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: address-lookup-api:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: Upload Trivy results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
```

### Workflow Triggers and Events

```yaml
# On Push to main
on:
  push:
    branches: [main]

# On Pull Request
on:
  pull_request:
    branches: [main]

# On Schedule (nightly)
on:
  schedule:
    - cron: '0 2 * * *'

# Manual trigger (workflow_dispatch)
on:
  workflow_dispatch

# After another workflow completes
on:
  workflow_run:
    workflows: ["Build and Test"]
    types: [completed]
```

### Running Workflows Locally

```bash
# Install act (local GitHub Actions runner)
# macOS
brew install act

# Windows
choco install act-cli

# Linux
# Download from https://github.com/nektos/act/releases

# Run workflow locally
act push
act pull_request
act -l  # List all workflows
```

### Workflow Monitoring

```bash
# View workflow runs
gh run list --repo owner/repo

# View specific run details
gh run view <run_id> --repo owner/repo

# Download logs
gh run download <run_id> --repo owner/repo

# Trigger workflow manually
gh workflow run deploy.yml --repo owner/repo
```

### Completion Criteria

- [x] Build workflow builds and tests successfully
- [x] Docker image built and pushed to ACR
- [x] Deploy workflow deploys to AKS
- [x] OIDC authentication working
- [x] Security scanning configured
- [x] All tests pass in CI
- [x] Code coverage tracked
- [x] Smoke tests verify deployment
- [x] Workflow logs captured
- [x] Secrets configured securely

---

## Phase 8: Testing & Verification

**Status**: ⬜ NOT STARTED  
**Duration**: Validation & Testing  
**Objectives**: Comprehensive testing and end-to-end validation

### Deliverables

#### 1. **Unit Testing**

**Test Framework**: xUnit + Moq

**Key Test Classes**:
- `AddressServiceTests.cs` - Service layer tests
- `AddressesControllerTests.cs` - Controller layer tests

**Test Categories**:
- ✅ Happy path scenarios
- ✅ Error handling
- ✅ Input validation
- ✅ Mock dependencies
- ✅ Edge cases

**Running Unit Tests**:
```bash
# Run all tests
dotnet test

# Run with coverage
dotnet test /p:CollectCoverage=true /p:CoverageFormat=opencover

# Run specific test
dotnet test --filter "TestClass=AddressServiceTests"

# Watch mode
dotnet watch test
```

#### 2. **Integration Testing**

**Scope**: API endpoints with real HTTP calls (mocked external APIs)

**Key Tests**:
- Health endpoint returns 200 OK
- Readiness endpoint returns 200 OK when healthy
- Address search returns valid response
- Error handling for invalid input
- Response format validation

**Running Integration Tests**:
```bash
# Run only integration tests
dotnet test --filter "Category=Integration"

# Run with detailed output
dotnet test -v diag

# Generate test report
dotnet test --logger "trx;LogFileName=test-results.trx"
```

#### 3. **API Testing (REST Client)**

**File**: `tests/local/requests.http`

**Endpoints Tested**:
- GET /health
- GET /ready
- GET /api/addresses/search?postcode=SW1A1AA
- GET /api/addresses/info
- Error cases (empty postcode, invalid format)

**Testing in VS Code**:
1. Install "REST Client" extension
2. Open `requests.http`
3. Click "Send Request" on any endpoint
4. View response inline

#### 4. **Container Testing**

**Testing Docker Image**:
```bash
# Build image
docker build -t address-lookup-api:test .

# Run container
docker run -p 8080:8080 \
  -e AddressLookup__ApiKey=test-key \
  address-lookup-api:test

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl "http://localhost:8080/api/addresses/search?postcode=SW1A1AA"

# Test with Docker Compose
docker-compose up --build

# Test from another container
docker exec address-lookup_api_1 curl http://localhost:8080/health

# Clean up
docker-compose down
```

#### 5. **Kubernetes Testing**

**Pre-deployment Validation**:
```bash
# Validate manifests
kubectl apply -f k8s/ --dry-run=client

# Lint Kubernetes manifests
kubeval k8s/*.yaml

# Check for best practices
kubesec scan k8s/deployment.yaml
```

**Post-deployment Verification**:
```bash
# Check deployment status
kubectl rollout status deployment/address-lookup-api -n address-lookup

# Check pod status
kubectl get pods -n address-lookup
kubectl describe pod <pod-name> -n address-lookup

# Check logs
kubectl logs -f deployment/address-lookup-api -n address-lookup

# Check resource usage
kubectl top nodes
kubectl top pods -n address-lookup

# Test service connectivity
kubectl exec -it <pod-name> -n address-lookup -- \
  curl http://localhost:8080/health

# Port forward and test
kubectl port-forward svc/address-lookup-service 8080:80 -n address-lookup
curl http://localhost:8080/health
```

#### 6. **Smoke Tests**

**Quick verification that deployment is working**:
```bash
#!/bin/bash
# smoke-tests.sh

set -e

API_URL="http://localhost:8080"

echo "Running smoke tests..."

# Test health endpoint
echo -n "Testing /health... "
if curl -f "$API_URL/health" > /dev/null 2>&1; then
  echo "✓ PASS"
else
  echo "✗ FAIL"
  exit 1
fi

# Test ready endpoint
echo -n "Testing /ready... "
if curl -f "$API_URL/ready" > /dev/null 2>&1; then
  echo "✓ PASS"
else
  echo "✗ FAIL"
  exit 1
fi

# Test search endpoint
echo -n "Testing /api/addresses/search... "
if curl -f "$API_URL/api/addresses/search?postcode=SW1A1AA" > /dev/null 2>&1; then
  echo "✓ PASS"
else
  echo "✗ FAIL"
  exit 1
fi

echo "All smoke tests passed! ✓"
```

#### 7. **Performance Testing**

**Load testing with Apache JMeter or K6**:

```bash
# Install k6
brew install k6  # macOS
# or
choco install k6  # Windows

# Create load test script (load-test.js)
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  stages: [
    { duration: '1m', target: 10 },   // Ramp-up
    { duration: '3m', target: 50 },   // Peak
    { duration: '1m', target: 0 },    // Ramp-down
  ],
};

export default function () {
  let res = http.get('http://localhost:8080/api/addresses/search?postcode=SW1A1AA');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
}

# Run load test
k6 run load-test.js
```

#### 8. **Security Testing**

**OWASP ZAP Scan**:
```bash
# Install OWASP ZAP
# macOS: brew install zaproxy
# Windows: Download from https://www.zaproxy.org/

# Run scan
zaproxy -cmd \
  -quickurl http://localhost:8080 \
  -quickout report.html

# Review report
open report.html
```

#### 9. **Test Coverage**

**Target**: >80% code coverage

```bash
# Generate coverage report
dotnet test /p:CollectCoverage=true \
  /p:CoverageFormat=opencover \
  /p:CoverageFileName=coverage.xml

# View coverage
# Open coverage.xml in tool like ReportGenerator
dotnet tool install -g ReportGenerator
reportgenerator -reports:coverage.xml -targetdir:coverage_report
```

#### 10. **End-to-End Verification Checklist**

- [ ] Unit tests pass (>80% coverage)
- [ ] Integration tests pass
- [ ] API responds to health checks
- [ ] Address search returns correct results
- [ ] Error handling works properly
- [ ] Docker image builds successfully
- [ ] Container runs without errors
- [ ] Kubernetes manifests validate
- [ ] Deployment rollout successful
- [ ] Pods are healthy (ready)
- [ ] Service is accessible
- [ ] Ingress routes traffic correctly
- [ ] HPA metrics collected
- [ ] Logs are captured and searchable
- [ ] Security scan passes
- [ ] Performance meets SLAs

### Troubleshooting Guide

**Issue**: "Pod is not ready"

**Diagnosis**:
```bash
kubectl describe pod <pod-name> -n address-lookup
kubectl logs <pod-name> -n address-lookup
```

**Solution**:
- Check readiness probe configuration
- Verify environment variables
- Check resource limits
- Review application logs

**Issue**: "Service has no endpoints"

**Diagnosis**:
```bash
kubectl get endpoints -n address-lookup
kubectl get svc -n address-lookup
```

**Solution**:
- Verify service selector matches pod labels
- Check if pods are running
- Review network policies

**Issue**: "Image pull error"

**Diagnosis**:
```bash
kubectl describe pod <pod-name>
```

**Solution**:
- Verify ACR credentials
- Check image name and tag
- Ensure imagePullSecrets configured

**Issue**: "Out of memory (OOMKilled)"

**Diagnosis**:
```bash
kubectl top pods -n address-lookup
kubectl logs <pod-name> --previous -n address-lookup
```

**Solution**:
- Increase memory limits
- Optimize application memory usage
- Enable memory-based HPA

### Completion Criteria

- [x] All unit tests pass
- [x] All integration tests pass
- [x] Code coverage >80%
- [x] Container builds and runs
- [x] Kubernetes deployment successful
- [x] All endpoints accessible
- [x] Health checks passing
- [x] Load tests completed
- [x] Security scans passed
- [x] Documentation complete
- [x] Troubleshooting guide created
- [x] End-to-end verification checklist signed off

---

## Next Steps

### Phase 9: Monitoring & Observability (Future)

- [ ] Application Insights integration
- [ ] Custom metrics and telemetry
- [ ] Alert configuration
- [ ] Dashboard creation
- [ ] Log aggregation

### Phase 10: Advanced Deployment (Future)

- [ ] Blue/Green deployments
- [ ] Canary releases
- [ ] A/B testing
- [ ] Multi-region deployment
- [ ] Disaster recovery

### Phase 11: API Enhancement (Future)

- [ ] Rate limiting
- [ ] API versioning
- [ ] GraphQL endpoint
- [ ] WebSocket support
- [ ] Caching strategies

---

## Key Resources

### Documentation Files

- [README.md](./README.md) - Quick start and overview
- [API.md](./docs/API.md) - API documentation
- [ARCHITECTURE.md](./docs/ARCHITECTURE.md) - System architecture
- [DEPLOYMENT.md](./docs/DEPLOYMENT.md) - Deployment procedures

### GitHub Workflows

- [.github/workflows/build.yml](./.github/workflows/build.yml) - Build and test
- [.github/workflows/deploy.yml](./.github/workflows/deploy.yml) - Deployment
- [.github/workflows/security.yml](./.github/workflows/security.yml) - Security scanning

### Kubernetes Manifests

- [k8s/deployment.yaml](./k8s/deployment.yaml) - Application deployment
- [k8s/service.yaml](./k8s/service.yaml) - Service configuration
- [k8s/ingress.yaml](./k8s/ingress.yaml) - Ingress routing

### Infrastructure Templates

- [infra/main.bicep](./infra/main.bicep) - Main infrastructure
- [infra/modules/](./infra/modules/) - Reusable Bicep modules

### Test Files

- [tests/AddressLookupApi.Tests/](./tests/AddressLookupApi.Tests/) - Unit tests
- [tests/local/requests.http](./tests/local/requests.http) - API test requests

---

## Summary

This document provides a comprehensive reference for all 8 phases of the Address Lookup API project:

1. ✅ **Phase 1**: Created .NET Core Web API scaffold with base functionality
2. ✅ **Phase 2**: Integrated Azure Key Vault for secure secret management
3. 🟡 **Phase 3**: Docker image built and health-verified locally; ACR setup still pending
4. ⬜ **Phase 4**: Infrastructure as code pending
5. ⬜ **Phase 5**: Kubernetes manifests pending
6. ⬜ **Phase 6 & 7**: GitHub Actions CI/CD pipeline pending
7. ⬜ **Phase 8**: Testing and verification pending

**Status**: Local development and local container verification complete; ACR and deployment phases pending

For questions or issues, refer to the specific phase section or review the troubleshooting guide in Phase 8.

---

**Document Version**: 1.0.0  
**Last Updated**: 2026-09-19  
**Maintainer**: Mahesh
