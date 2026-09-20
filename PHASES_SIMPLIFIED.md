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

**Status**: 🔄 IN PROGRESS

### Summary
Defining Azure infrastructure using Infrastructure as Code (Bicep or Terraform). Creating reusable, version-controlled infrastructure templates for AKS, Key Vault, ACR, and supporting services.

### Key Components to Define
- **Azure Kubernetes Service (AKS)**: Cluster configuration with networking
- **Azure Container Registry (ACR)**: Image repository
- **Azure Key Vault**: Secrets management
- **Virtual Network (VNet)**: Networking and security
- **Managed Identity**: Service principal for pod authentication
- **Application Insights**: Monitoring and observability
- **Storage Account** (if needed): For logs or data persistence

### IaC Approach
- **Azure CLI (`az` commands)** in PowerShell scripts
- Sequential deployment of resources (VNet, ACR, Key Vault, AKS)
- Parameter variables at the top of scripts for easy configuration
- Direct Azure API calls via CLI for resource creation and configuration

### Completion Criteria
- [ ] Bicep/Terraform templates created
- [ ] Variables and parameters defined
- [ ] Resource dependencies properly configured
- [ ] Templates validated
- [ ] Deployment tested successfully
- [ ] Cost estimated using Azure pricing calculator

---

## Phase 5: Kubernetes Manifests

**Status**: ⏳ PENDING

### Summary
Creating Kubernetes manifests for deploying the containerized application to AKS. Includes Deployments, Services, Ingress, ConfigMaps, Secrets, and RBAC configurations.

### Key Components
- **Deployment**: Manages pod replicas, rolling updates, resource limits/requests
- **Service**: Internal and external networking (ClusterIP, LoadBalancer, NodePort)
- **Ingress**: External HTTP/HTTPS routing with domain management
- **ConfigMaps**: Non-sensitive configuration data
- **Secrets**: Sensitive data (connection strings, API keys)
- **ServiceAccount & RBAC**: Pod security and permissions
- **Health Probes**: Liveness and readiness probes
- **Network Policies**: Pod-to-pod communication rules
- **Resource Quotas**: Namespace-level resource limits

### Kubernetes Best Practices to Follow
- Pod security context (non-root user, read-only filesystem)
- Resource requests and limits for all containers
- Health check probes (liveness and readiness)
- Network policies for least-privilege communication
- RBAC with minimal permissions
- ConfigMaps for configuration, Secrets for sensitive data
- Horizontal Pod Autoscaler (HPA) for dynamic scaling
- Proper labeling and selectors

### Completion Criteria
- [ ] All manifests created and validated
- [ ] Deployment creates correct number of replicas
- [ ] Service exposes pods correctly
- [ ] Ingress routes traffic properly
- [ ] Health probes configured and working
- [ ] Resource limits and requests set
- [ ] RBAC configured with least privilege
- [ ] Network policies enforced

---

## Phase 6 & 7: GitHub Actions Pipeline

**Status**: ⏳ PENDING

### Summary
Implementing CI/CD automation using GitHub Actions. Automating build, test, containerization, ACR push, and AKS deployment workflows.

### CI/CD Pipeline Stages
1. **Trigger**: On push to main branch and pull requests
2. **Build & Test**: Compile, run unit tests
3. **Container Build**: Build Docker image, scan for vulnerabilities
4. **ACR Push**: Push image to Azure Container Registry
5. **Infrastructure Deployment**: Apply Bicep/Terraform templates
6. **Kubernetes Deployment**: Deploy to AKS with kubectl or Helm
7. **Health Verification**: Run smoke tests against deployed app
8. **Notifications**: Report success/failure status

### GitHub Actions Workflows
- **CI Workflow**: Build, test, and push on every commit
- **Deployment Workflow**: Deploy to staging and production
- **Rollback Workflow**: Quick rollback capability

### Secrets Management in GitHub Actions
- Azure credentials for authentication
- Registry credentials for ACR
- Database connection strings
- API keys and tokens
- Kubernetes cluster credentials

### Completion Criteria
- [ ] GitHub Actions workflows created
- [ ] CI pipeline passes automatically
- [ ] Container built and pushed to ACR
- [ ] Infrastructure deployed automatically
- [ ] Application deployed to AKS
- [ ] Smoke tests pass
- [ ] Notifications configured
- [ ] Rollback workflow tested

---

## Phase 8: Testing & Verification

**Status**: ⏳ PENDING

### Summary
Comprehensive testing and verification of the entire system, from unit tests through integration and end-to-end tests, with monitoring and logging in production.

### Testing Scope
- **Unit Tests**: Service and controller logic
- **Integration Tests**: API endpoints with mocked external services
- **Contract Tests**: API consumer expectations
- **E2E Tests**: Full workflow through container to cloud
- **Load Tests**: Performance under stress
- **Security Tests**: Vulnerability scanning, RBAC verification

### Monitoring & Logging
- Application Insights telemetry collection
- Centralized logging (stdout/stderr)
- Prometheus metrics collection
- Grafana dashboards for visualization
- Alert configuration for anomalies

### Verification Checklist
- [ ] Unit tests pass locally
- [ ] Container tests pass
- [ ] Integration tests pass
- [ ] AKS deployment healthy
- [ ] Application metrics collected
- [ ] Logs centralized and queryable
- [ ] Health checks responding correctly
- [ ] External API (Postcodes.io) integration working
- [ ] Load tests show acceptable performance
- [ ] Security scanning passes
- [ ] Documentation complete

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
