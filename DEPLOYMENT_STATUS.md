# Address Lookup API - Deployment Status Report

## ✅ Phase 5 Deployment Complete

### External Access: **WORKING** 🎉

The Address Lookup API is now successfully deployed to Azure Kubernetes Service (AKS) and **accessible from external clients**.

---

## Service Details

| Component | Value |
|-----------|-------|
| **External IP** | `85.210.58.36` |
| **Port** | `80` (HTTP) |
| **Health Check** | ✅ Passing |
| **Pod Status** | 1/1 Ready |
| **Kubernetes Version** | 1.37.0 |
| **AKS Cluster** | aks-address-lookup (uksouth) |

---

## Working Endpoint

```
http://85.210.58.36/api/addresses/search?postcode=SW1A1AA
```

### Example Request

```bash
curl "http://85.210.58.36/api/addresses/search?postcode=SW1A1AA"
```

### Example Response

```json
{
  "addresses": [
    {
      "postcode": "SW1A 1AA",
      "country": "England",
      "region": "London",
      "admin_district": "Westminster",
      "parliamentary_constituency": "Cities of London and Westminster",
      "latitude": 51.50101,
      "longitude": -0.141563,
      "formatted_address": "SW1A 1AA, Westminster, England",
      "codes": {
        "admin_district": "E09000033",
        "parliamentary_constituency": "E14001172",
        "admin_ward": "E05013806",
        "ccg": "E38000256",
        "nuts": "TLI35"
      }
    }
  ],
  "count": 1,
  "searchPostcode": "SW1A1AA",
  "searchedAt": "2026-09-20T12:14:53.6878832Z"
}
```

---

## Root Cause Analysis

### Initial Issue
External LoadBalancer IP (originally 20.77.190.252) was unreachable, all requests timed out.

### Investigation Steps
1. ✅ Verified pod running and healthy
2. ✅ Verified internal connectivity (port-forward worked)
3. ✅ Verified application functionality (API responses correct)
4. ✅ Added NSG rule for port 80 on node resource group NSG
5. ❌ External IP still timing out
6. ✅ Discovered subnet NSG had DenyAllInBound default rule
7. ✅ Added explicit allow rule for HTTP/HTTPS to subnet NSG
8. ✅ External access immediately functional

### Root Cause
**Azure Network Security Group (NSG) on the AKS subnet** was blocking all inbound traffic. While the default allow rules cover VNet-to-VNet and Load Balancer health checks, it explicitly denies all other inbound traffic. This prevented external clients from reaching the LoadBalancer.

### Solution Applied
Added inbound security rule to `nsg-address-lookup` (the primary resource group NSG):
- **Rule Name**: AllowHTTPInbound
- **Priority**: 100 (high priority, before DenyAll)
- **Protocol**: TCP
- **Ports**: 80, 443
- **Source**: Any (*)
- **Direction**: Inbound

---

## Kubernetes Manifests Summary

### Resources Deployed
1. **Deployment** (address-lookup-api)
   - Replicas: 1
   - Strategy: RollingUpdate (maxSurge:1, maxUnavailable:0)
   - Image: addresslookupacr.azurecr.io/address-lookup-api:latest
   - Health Probes: Liveness (/health) + Readiness (/ready)
   - Resource Limits: 500m CPU / 512Mi RAM

2. **Service** (LoadBalancer)
   - Type: LoadBalancer
   - External Port: 80
   - Internal Port: 8080
   - NodePort: 30194 (auto-assigned)

3. **ServiceAccount** (RBAC)
   - Minimal permissions (read-only on pods/services)
   - Non-root execution (UID 1000)
   - No privilege escalation

4. **ClusterRole & ClusterRoleBinding**
   - Permissions: get, list, watch on pods and services

---

## Infrastructure Configuration

### Network
- **VNet**: vnet-address-lookup (10.0.0.0/16)
- **Subnet**: subnet-aks (10.0.1.0/24)
- **Pod Network**: 10.0.1.0/24 (Azure CNI)
- **Service CIDR**: 10.1.0.0/16

### Security
- **NSG Rules Applied**:
  1. AllowHTTPInbound (priority 100, ports 80/443) - ✅ **Critical**
  2. AllowNodePortInbound (priority 440, port 30194) - agent NSG
  3. AllowHTTPInbound (priority 450, port 80) - agent NSG

### Container Registry
- **ACR**: addresslookupacr.azurecr.io
- **Image**: address-lookup-api:latest
- **Status**: Available and accessible

### Application Logging
- **Framework**: ASP.NET Core 8
- **Logging**: Serilog to stdout
- **Health Endpoints**: /health, /ready
- **External API**: Postcodes.io

---

## Next Steps

### Phase 6: GitHub Actions CI/CD
- [ ] Create build workflow (.github/workflows/build.yml)
  - Build Docker image
  - Push to ACR
  - Run tests

- [ ] Create deploy workflow (.github/workflows/deploy.yml)
  - Deploy new image to AKS
  - Run integration tests
  - Verify health checks

### Phase 7: Monitoring & Observability
- [ ] Enable Application Insights
- [ ] Configure Azure Monitor alerts
- [ ] Set up pod log aggregation
- [ ] Create Grafana dashboards

### Phase 8: Production Hardening
- [ ] Implement HTTPS/TLS
- [ ] Add API authentication
- [ ] Configure rate limiting
- [ ] Set up backup/disaster recovery
- [ ] Performance testing under load

---

## Testing the Deployment

### Quick Test
```bash
# Test with postcode
curl "http://85.210.58.36/api/addresses/search?postcode=SW1A1AA"

# Test with different postcode
curl "http://85.210.58.36/api/addresses/search?postcode=E1W1DU"
```

### Health Checks
```bash
# Liveness probe
curl "http://85.210.58.36/health"

# Readiness probe
curl "http://85.210.58.36/ready"
```

### From Kubernetes
```bash
# Check pod logs
kubectl logs -f deployment/address-lookup-api

# Check service endpoints
kubectl get endpoints address-lookup-api

# Describe service
kubectl describe svc address-lookup-api
```

---

## Key Lessons Learned

1. **NSG Configuration is Critical**: Default deny rules can block traffic even when Load Balancer is correctly configured.

2. **Layered Network Security**: Multiple NSGs are involved:
   - Subnet NSG (primary network boundary)
   - Agent node pool NSG (for Kubernetes components)
   - Both need appropriate rules for different traffic paths

3. **Debugging Connectivity**: Systematic approach helped isolate the issue:
   - Pod-level connectivity (✅)
   - Service-level connectivity (✅)
   - Infrastructure-level connectivity (❌ → fixed)

4. **Port Forwarding vs LoadBalancer**: Port-forward creates a tunnel through the Kubernetes API, bypassing network infrastructure, which is why it worked before external IP did.

---

## Documentation

- **Deployment Manifest**: [deployment.yaml](./deployment.yaml)
- **Application Code**: [src/AddressLookupApi/](./src/AddressLookupApi/)
- **Infrastructure Scripts**: [.azure/](./. azure/)

---

**Status**: ✅ Phase 5 Complete  
**Date**: 2026-09-20  
**Last Updated**: When external access was verified working
