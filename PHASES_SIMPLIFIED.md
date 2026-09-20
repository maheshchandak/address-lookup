# Address Lookup API - Project Phases Documentation

**Project**: Address Lookup API  
**Status**: Phases 1, 2, and 3 complete; Phase 4 in progress  
**Last Updated**: 2026-09-19  
**Repository**: c:\MaHESH\Learn\CoPilot\address-lookup

---

## Project Goal

Build and deploy a .NET 8 postcode lookup API to Azure Kubernetes Service (AKS), learning each stage from local development through containerization, Azure infrastructure, Kubernetes, and GitHub Actions.

### Current Architecture

- **Application**: ASP.NET Core 8 Web API with health check endpoints
- **Postcode provider**: Postcodes.io with endpoint stored as a secret
- **Deployment target**: Azure Kubernetes Service
- **Security**: Azure Key Vault and managed identity
- **CI/CD**: GitHub Actions
- **Container registry**: Azure Container Registry

---

## Table of Contents

1. [Phase 1: Create Project Scaffold](#phase-1-create-project-scaffold)
2. [Phase 2: Add Key Vault Integration](#phase-2-add-key-vault-integration)
3. [Phase 3: Dockerfile & ACR Setup](#phase-3-dockerfile--acr-setup)
4. [Phase 4: Infrastructure as Code](#phase-4-infrastructure-as-code)
5. [Phase 5: Kubernetes Manifests](#phase-5-kubernetes-manifests)
6. [Phase 6 & 7: GitHub Actions Pipeline](#phase-6--7-github-actions-pipeline)
7. [Phase 8: Testing & Verification](#phase-8-testing--verification)

---

## Phase 1: Create Project Scaffold

**Status**: ✅ COMPLETED

### Summary
Established foundational .NET Core Web API structure with ASP.NET Core 8, including Controllers (Health, Addresses), Service layer for Postcodes.io integration, Models, Dependency Injection, Error handling middleware, Health check endpoints, OpenAPI/Swagger, and unit tests.

### Key Deliverables
- ASP.NET Core 8 Web API project structure
- Service layer for address lookups
- Health check endpoints (`/health`, `/healthz`)
- Global error handling middleware
- Unit tests with xUnit and Moq
- OpenAPI/Swagger documentation

### Completion Criteria
- ✅ Solution compiles without errors
- ✅ Unit tests pass
- ✅ API responds to requests locally
- ✅ Health endpoints return 200 OK
- ✅ Address search functionality works

---

## Phase 2: Add Key Vault Integration

**Status**: ✅ COMPLETED

### Summary
Implemented secure configuration management using Azure Key Vault for non-local environments and User Secrets for local development. Configured DefaultAzureCredential chain to support multiple authentication methods.

### Key Technologies
- Azure Key Vault
- Azure Identity (DefaultAzureCredential)
- User Secrets for local development
- Configuration builder with multiple sources

### Key Deliverables
- User Secrets configured for local development
- Azure Key Vault setup with secrets
- DefaultAzureCredential authentication chain
- Configuration layer that supports both local and cloud environments

### Completion Criteria
- ✅ User Secrets configured locally
- ✅ Key Vault NuGet packages installed
- ✅ DefaultAzureCredential implemented
- ✅ API reads secrets from Key Vault in Azure
- ✅ Local development uses User Secrets
- ✅ No secrets in source control

---

## Phase 3: Dockerfile & ACR Setup

**Status**: ✅ COMPLETED

### Summary
Created a multi-stage Docker image using best practices for containerization. Configured Azure Container Registry (ACR) for image storage and management.

### Key Deliverables
- Multi-stage Dockerfile (build and runtime stages)
- Base image: `mcr.microsoft.com/dotnet/aspnet:8.0` for runtime
- Build image with .NET 8 SDK
- Minimal final image with only runtime dependencies
- Container runs on port 8080
- Non-root user execution
- Read-only root filesystem where possible

### Docker Best Practices Applied
- Multi-stage builds for reduced image size
- Distroless/minimal base images
- Non-root user execution
- Explicit port exposure
- Image vulnerability scanning ready
- Layer caching optimization

### Completion Criteria
- ✅ Dockerfile builds successfully
- ✅ Container runs and serves requests
- ✅ Health endpoints accessible in container
- ✅ ACR repository created
- ✅ Image pushed to ACR
- ✅ Image security best practices followed

---

## Phase 4: Infrastructure as Code

**Status**: ✅ COMPLETED

### Summary
Created comprehensive Bicep Infrastructure as Code templates for complete AKS deployment. Templates define all required Azure resources as versioned, reproducible code.

### Key Components Defined
- **Azure Kubernetes Service (AKS)**: Cluster with networking, logging, RBAC
- **Azure Container Registry (ACR)**: Image repository with AcrPull role assignments
- **Azure Key Vault**: Secrets management with managed identity access
- **Virtual Network (VNet)**: Segmented subnets for AKS and VMs
- **Managed Identity**: Service principal for pod and GitHub Actions authentication
- **Application Insights & Log Analytics**: Monitoring and observability
- **Role-Based Access Control (RBAC)**: Least privilege roles for identities

### IaC Approach
- **Bicep Language**: Modern, declarative Azure IaC template language
- **Bicep Parameters**: Reusable parameter files (main.bicepparam)
- **Modular Design**: Single main.bicep with variables for customization
- **Output Export**: Outputs for AKS cluster, ACR, managed identity details

### Deliverables
- ✅ `infra/main.bicep`: Complete infrastructure template
- ✅ `infra/main.bicepparam`: Configuration parameters
- ✅ Automated validation in CI/CD pipeline
- ✅ Deployment tested and verified

### Completion Criteria
- ✅ Bicep templates created and validated
- ✅ Variables and parameters defined
- ✅ Resource dependencies properly configured
- ✅ RBAC roles assigned correctly
- ✅ Deployment tested successfully
- ✅ Infrastructure provisioning automated

---

## Phase 5: Kubernetes Manifests

**Status**: ✅ COMPLETED

### Summary
Created comprehensive Kubernetes manifests for deploying the containerized application to AKS. Includes Deployments, Services, and health checks configured for production.

### Deployed Components
- **Deployment**: Single replica (for cost), resource limits/requests, rolling update strategy
- **Service**: LoadBalancer type for external access (accessible at http://85.210.58.36:80)
- **Health Probes**: Liveness probe at /health, readiness probe at /ready
- **Security Context**: Non-root user execution, security best practices applied
- **Resource Management**: CPU 100m-500m, Memory 128Mi-512Mi with limits

### Current Deployment Status
- ✅ Pod running: address-lookup-api-79865886fd-nqljc (1/1 Ready)
- ✅ Service accessible: External IP 85.210.58.36
- ✅ Health checks passing: Both liveness and readiness probes working
- ✅ API responding: /api/addresses/search endpoint returning data

### Completion Criteria
- ✅ All manifests created and validated
- ✅ Deployment creates correct number of replicas
- ✅ Service exposes pods correctly
- ✅ Health probes configured and working
- ✅ Resource limits and requests set
- ✅ Pod running successfully in AKS
- ✅ External API access verified

---

## Phase 6: Infrastructure & Application CI/CD Pipeline

**Status**: ✅ COMPLETED

### Summary
Implemented complete CI/CD automation using GitHub Actions with OIDC federated credentials. Automated infrastructure provisioning, application build/test, containerization, and deployment to AKS.

### CI/CD Pipeline Architecture

#### Workflow 1: Build & Test (`build.yml`)
- **Trigger**: Push to master branch, pull requests
- **Steps**:
  1. Checkout code
  2. Setup .NET 8
  3. Restore NuGet packages
  4. Build (Release configuration)
  5. Run xUnit tests with TRX output
  6. Publish test results as GitHub checks
  7. Build multi-stage Docker image
  8. Push to Azure Container Registry (addresslookupacr)
- **Tags**: `latest`, `master-<sha>`, `master`
- **Status**: ✅ Working - All steps pass

#### Workflow 2: Deploy Application (`deploy.yml`)
- **Trigger**: Successful completion of build.yml (workflow_run), master branch only
- **Steps**:
  1. Azure Login via OIDC federated credentials
  2. Get AKS cluster credentials
  3. Extract image tag (`latest`)
  4. Deploy to AKS using kubectl set image
  5. Wait for rollout (5 min timeout)
  6. Get LoadBalancer IP
  7. Health check: curl /health endpoint (60s retry)
  8. Smoke test: curl /api/addresses/search (verify data returned)
  9. Rollback on failure
- **Status**: ✅ Working - Pod running, API accessible

#### Workflow 3: Provision Infrastructure (`infra-provision.yml`)
- **Trigger**: Manual (workflow_dispatch) on-demand
- **Inputs**: 
  - Environment: dev/staging/prod
  - Region: Azure region selection
  - Node count: AKS node pool size
- **Steps**:
  1. Azure Login via OIDC
  2. Create Resource Group
  3. Validate Bicep templates
  4. Deploy infrastructure using main.bicep
  5. Get AKS credentials
  6. Verify cluster health
  7. Create ACR Kubernetes secret
- **Output**: AKS cluster, ACR server, infrastructure details
- **Status**: ✅ Ready for on-demand use

#### Workflow 4: Teardown Infrastructure (`infra-teardown.yml`)
- **Trigger**: Manual (workflow_dispatch) with confirmation
- **Safety**: Requires typing "yes" to confirm deletion
- **Steps**:
  1. Azure Login via OIDC
  2. Check resource group exists
  3. Delete resource group and all resources
  4. Report deletion initiated
- **Features**: 
  - Confirmation required
  - Deletion runs asynchronously (5-10 min)
  - Clean up all resources (AKS, ACR, Key Vault, VNet, etc.)
- **Status**: ✅ Ready for cost optimization

#### Workflow 5: On-Demand Provision & Deploy (`on-demand-deploy.yml`)
- **Trigger**: Manual (workflow_dispatch)
- **Purpose**: Complete automation from infrastructure to running application
- **Flow**:
  1. Check if infrastructure exists
  2. If not, provision via Bicep deployment
  3. Build and test application
  4. Build Docker image
  5. Deploy to AKS
  6. Run health checks and smoke tests
- **Output**: Live API accessible via LoadBalancer IP
- **Status**: ✅ Ready for production deployments

### Authentication & Security

#### OIDC Federated Credentials
- **Method**: Azure OIDC token exchange (no secrets stored in GitHub)
- **Managed Identity**: uami-github-actions
- **Principal ID**: b7ff7e99-18a8-4726-a401-31a980cc6937
- **Subject Format**: `repo:maheshchandak@50156171/address-lookup@1375897209:ref:refs/heads/master`
- **Security**: Immutable ID format prevents token reuse if repo transferred
- **RBAC**: Contributor role on subscription

#### Secrets Management
- **GitHub Secrets**: ACR_USERNAME, ACR_PASSWORD (for Docker push)
- **GitHub Variables**: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
- **Key Vault**: Managed centrally in Azure (Postcodes.io API endpoint)
- **Kubernetes Secrets**: acr-secret created in cluster for image pull

### Key Technologies
- GitHub Actions with OIDC authentication
- Azure Bicep for Infrastructure as Code
- Azure Container Registry for image storage
- Azure Kubernetes Service for orchestration
- Azure Key Vault for secrets
- Federated credentials for CI/CD authentication

### Workflow Execution Flow

```
1. Developer pushes to master
   ↓
2. build.yml triggered
   - Tests pass
   - Docker image built and pushed to ACR
   ↓
3. deploy.yml triggered automatically
   - Authenticates via OIDC
   - Pulls latest image from ACR
   - Updates AKS deployment
   - Runs health checks
   - Runs smoke tests
   ↓
4. Application running in AKS (http://85.210.58.36/api/addresses/search)
```

### On-Demand Workflow Flow (Cost Optimization)

```
1. Run "On-Demand: Provision & Deploy" workflow manually
   ↓
2. Check if infrastructure exists
   - If yes: Skip to step 4
   - If no: Run step 3
   ↓
3. Provision infrastructure using Bicep
   - Create AKS cluster
   - Create ACR
   - Setup Key Vault, networking, monitoring
   ↓
4. Build application
   - Compile, test, build Docker image
   ↓
5. Deploy to AKS
   - Update deployment with latest image
   - Run health checks and smoke tests
   ↓
6. Application live and accessible
   
   When done or to save costs:
   
7. Run "Teardown Infrastructure" workflow
   - Confirm deletion (safety mechanism)
   - Delete resource group and all resources
   - No recurring costs
   ↓
8. Infrastructure deleted, costs eliminated
```

### Current Status
- ✅ Build workflow: Passing all tests, pushing images to ACR
- ✅ Deploy workflow: Successfully rolling out new images to AKS
- ✅ Infrastructure provisioning: Ready for on-demand use
- ✅ Infrastructure teardown: Ready to save costs
- ✅ On-demand deployment: Complete end-to-end automation ready
- ✅ OIDC authentication: Secure, no secrets needed
- ✅ Health checks: Passing
- ✅ Smoke tests: Passing
- ✅ API accessible: http://85.210.58.36/api/addresses/search?postcode=SW1A1AA

### How to Use (Cost Optimization Pattern)

**To Deploy On-Demand:**
1. Go to GitHub Actions
2. Select "On-Demand: Provision & Deploy"
3. Click "Run workflow"
4. Choose environment, region, node count
5. Click "Run workflow"
6. Wait for completion (~15-20 minutes including infrastructure provisioning)
7. Access API via LoadBalancer IP shown in workflow summary

**To Save Costs (Teardown):**
1. Go to GitHub Actions
2. Select "Teardown Infrastructure"
3. Click "Run workflow"
4. Type "yes" in the confirm field
5. Click "Run workflow"
6. Wait for deletion (~5-10 minutes)
7. Resource group and all resources deleted, no more costs

**For Development (Keep Infrastructure):**
1. Infrastructure provisioned once
2. Push code changes to master
3. Workflows automatically build and deploy
4. Quick iteration without infrastructure wait time

### Completion Criteria
- ✅ Build workflow passing tests and pushing images
- ✅ Deploy workflow successfully rolling out to AKS
- ✅ Infrastructure provisioning automated with Bicep
- ✅ Infrastructure teardown automated
- ✅ On-demand deployment working end-to-end
- ✅ OIDC federated credentials configured
- ✅ Health checks and smoke tests passing
- ✅ Cost optimization enabled via on-demand pattern

---

## Phase 7: Testing, Monitoring & Observability

**Status**: ⏳ PENDING (After infrastructure CI/CD complete)

### Summary
Comprehensive testing, monitoring, and observability of the application running in AKS. With on-demand infrastructure, can now safely run load tests, security scans, and performance benchmarks.

### Testing Scope
- **Unit Tests**: Currently automated in build.yml ✅
- **Integration Tests**: API endpoints with real Postcodes.io service
- **Smoke Tests**: Currently automated in deploy.yml ✅
- **E2E Tests**: Full workflow through container to cloud
- **Load Tests**: Performance under sustained/spike loads
- **Security Tests**: Vulnerability scanning, RBAC verification, network policies

### Monitoring & Logging
- **Application Insights**: Telemetry collection (configured in infrastructure)
- **Log Analytics**: Centralized logging (configured in infrastructure)
- **Azure Monitor**: Metrics and alerts
- **Container Logs**: `kubectl logs` access to pod output
- **Prometheus**: Custom metrics collection (optional)
- **Grafana**: Dashboards for visualization (optional)

### Observability Enhancements
1. Application Insights SDK instrumentation
2. Correlation IDs for distributed tracing
3. Custom metrics for business logic
4. Alert rules for performance degradation
5. Dashboard for real-time monitoring
6. Log queries for troubleshooting

### Cost Optimization Pattern
Since infrastructure can be provisioned/torn down on-demand:
- Run full test suites only when needed
- Spin up infrastructure for load testing
- Tear down immediately after (no persistent costs)
- Keep dev/staging infrastructure separate from production

### Completion Criteria
- [ ] Unit tests integrated in CI pipeline
- [ ] Integration tests passing
- [ ] Smoke tests automated
- [ ] Load tests configured and passing
- [ ] Application Insights instrumentation complete
- [ ] Monitoring dashboards created
- [ ] Alert rules configured
- [ ] Log queries defined for troubleshooting
- [ ] Security scanning integrated
- [ ] Performance benchmarks established

---

## Next Steps

### Immediate Actions
1. Complete Phase 4: Infrastructure as Code (Bicep/Terraform)
2. Create Kubernetes manifests (Phase 5)
3. Set up GitHub Actions workflows (Phase 6 & 7)
4. Implement comprehensive testing (Phase 8)

### Learning Outcomes
- Azure infrastructure and resource management
- Containerization and image optimization
- Kubernetes deployment patterns
- Infrastructure as Code best practices
- CI/CD automation with GitHub Actions
- Cloud-native application design
- Security and identity management
- Monitoring and observability

---

## Key Resources

- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Azure Kubernetes Service Docs](https://docs.microsoft.com/en-us/azure/aks/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Bicep Language Reference](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/file)

---

## Questions & Troubleshooting

### Common Issues
- **Build failures**: Check .NET SDK version and NuGet package versions
- **Docker image errors**: Verify base image availability and port mappings
- **ACR authentication**: Ensure service principal has correct permissions
- **AKS deployment failures**: Check cluster capacity, node availability, and RBAC
- **Networking issues**: Verify NSG rules, subnet configuration, and Ingress controller

### Support
For issues or questions, review the project README.md and relevant phase documentation.
