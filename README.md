# Address Lookup API - Phase 1: Local Development

## Overview

This is a production-ready .NET Core 8 Web API that searches for UK addresses by postcode using the **getAddress.io** service. This is **Phase 1** of a multi-phase project focusing on local development setup and core functionality.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      Client Applications                         │
│            (Web, Mobile, Desktop, Postman, curl)                │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Ingress / Load Balancer                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              Address Lookup API (ASP.NET Core 8)                │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │             Controllers (HTTP Endpoints)                 │   │
│  │  GET /health                   (Liveness Probe)          │   │
│  │  GET /ready                    (Readiness Probe)         │   │
│  │  GET /api/addresses/search     (Main Search Endpoint)    │   │
│  │  GET /api/addresses/info       (Service Information)     │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Business Logic Layer (Services)             │   │
│  │  AddressService                                          │   │
│  │    - Postcode validation & normalization                │   │
│  │    - External API integration                           │   │
│  │    - Response transformation & caching                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │        Data Models & Configuration                       │   │
│  │  - Address Model                                         │   │
│  │  - API Response Envelope                                │   │
│  │  - Configuration Management                             │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              External Dependencies                               │
│  - getAddress.io REST API (Address Data Source)                │
│  - Configuration Providers (appsettings.json, Env Vars)        │
│  - Logging (Console, File, Application Insights)              │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
address-lookup/
├── src/
│   └── AddressLookupApi/
│       ├── Controllers/
│       │   ├── HealthController.cs          # Health check endpoints
│       │   └── AddressesController.cs        # Main API endpoints
│       ├── Models/
│       │   ├── Address.cs                   # Core address model
│       │   ├── ApiResponse.cs               # Response envelope
│       │   └── ConfigurationOptions.cs      # Configuration models
│       ├── Services/
│       │   ├── IAddressService.cs           # Service interface
│       │   └── AddressService.cs            # Implementation
│       ├── Middleware/
│       │   ├── ErrorHandlingMiddleware.cs   # Global error handling
│       │   └── RequestLoggingMiddleware.cs  # Request/response logging
│       ├── appsettings.json                 # Configuration
│       ├── appsettings.Development.json     # Dev configuration
│       ├── Program.cs                       # Startup configuration
│       ├── AddressLookupApi.csproj          # Project file
│       └── Dockerfile                       # Container image
├── tests/
│   ├── AddressLookupApi.Tests/
│   │   ├── AddressServiceTests.cs           # Service unit tests
│   │   ├── AddressesControllerTests.cs      # Controller tests
│   │   └── AddressLookupApi.Tests.csproj    # Test project
│   └── local/
│       └── requests.http                    # REST client test file
├── docs/
│   ├── API.md                               # API documentation
│   ├── ARCHITECTURE.md                      # Architecture details
│   └── DEPLOYMENT.md                        # Deployment guide
├── .github/
│   ├── workflows/
│   │   ├── build.yml                        # CI workflow
│   │   └── deploy.yml                       # CD workflow
│   └── instructions/
│       ├── dotnet-architecture-good-practices.instructions.md
│       ├── github-actions-ci-cd-best-practices.instructions.md
│       ├── containerization-docker-best-practices.instructions.md
│       └── kubernetes-deployment-best-practices.instructions.md
├── AddressLookup.sln                        # Solution file
├── Dockerfile                               # Production container
├── docker-compose.yml                       # Local development compose
├── README.md                                # This file
└── .gitignore                               # Git ignore rules

```

## Quick Start

### Prerequisites

- .NET 8 SDK ([Install](https://dotnet.microsoft.com/download/dotnet/8.0))
- getAddress.io API Key ([Free tier available](https://getaddress.io))
- VS Code or Visual Studio
- REST Client Extension (VS Code) - optional but recommended
- Docker & Docker Compose - for containerized development

### 1. Clone and Setup

```bash
# Navigate to project
cd c:\MaHESH\Learn\CoPilot\address-lookup

# Restore dependencies
dotnet restore

# Build solution
dotnet build

# Run unit tests
dotnet test
```

### 2. Configure API Key

Create or update `src/AddressLookupApi/appsettings.Development.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft": "Information"
    }
  },
  "AddressLookup": {
    "ApiKey": "YOUR_GETADDRESS_IO_API_KEY",
    "BaseUrl": "https://api.getaddress.io",
    "TimeoutSeconds": 10,
    "CacheEnabled": true,
    "CacheDurationMinutes": 60
  }
}
```

### 3. Run Locally

**Option A: Direct CLI**
```bash
cd src/AddressLookupApi
dotnet run
# API available at: http://localhost:5000
```

**Option B: Docker Compose**
```bash
docker-compose up --build

# API available at: http://localhost:8080
# Swagger UI at: http://localhost:8080/swagger/index.html
```

**Option C: IDE (VS Code/Visual Studio)**
- Press `F5` or `Ctrl+F5` to start debugging
- Set breakpoints and step through code

### 4. Test the API

Using `tests/local/requests.http` in VS Code with REST Client extension:

```http
### Search for addresses by postcode
GET http://localhost:8080/api/addresses/search?postcode=SW1A1AA

### Check API health
GET http://localhost:8080/health

### Check API readiness
GET http://localhost:8080/ready
```

Or using `curl`:

```bash
curl -X GET "http://localhost:8080/api/addresses/search?postcode=SW1A1AA"
curl -X GET "http://localhost:8080/health"
curl -X GET "http://localhost:8080/ready"
```

## API Endpoints

### Health Check Endpoints

#### GET /health
- **Purpose**: Liveness probe (is the API alive?)
- **Response**: 200 OK
- **Body**: `{ "status": "healthy", "timestamp": "2024-01-01T00:00:00Z" }`
- **Kubernetes**: Used by `livenessProbe`

#### GET /ready
- **Purpose**: Readiness probe (is the API ready to serve traffic?)
- **Response**: 200 OK or 503 Service Unavailable
- **Body**: `{ "ready": true, "timestamp": "2024-01-01T00:00:00Z" }`
- **Kubernetes**: Used by `readinessProbe`

### Address Search Endpoints

#### GET /api/addresses/search
- **Description**: Search for UK addresses by postcode
- **Parameters**:
  - `postcode` (required): UK postcode (e.g., "SW1A1AA" or "SW1A 1AA")
- **Response**: 200 OK
- **Example**:
  ```json
  {
    "data": [
      {
        "formattedAddress": "1 Parliament Street, London, SW1A 1AA",
        "street": "Parliament Street",
        "city": "London",
        "postcode": "SW1A1AA",
        "latitude": 51.5010,
        "longitude": -0.1246
      }
    ],
    "count": 1,
    "searchPostcode": "SW1A1AA",
    "success": true,
    "message": null
  }
  ```
- **Error Responses**:
  - `400 Bad Request`: Missing or invalid postcode
  - `429 Too Many Requests`: API rate limit exceeded
  - `503 Service Unavailable`: External API unreachable

#### GET /api/addresses/info
- **Description**: Get API information and status
- **Response**: 200 OK
- **Example**:
  ```json
  {
    "serviceName": "Address Lookup API",
    "version": "1.0.0",
    "environment": "Development",
    "cacheEnabled": true
  }
  ```

## Configuration

### Application Settings

**appsettings.json** (committed to repo):
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

**appsettings.Development.json** (local only, git-ignored):
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft": "Information"
    }
  },
  "AddressLookup": {
    "ApiKey": "YOUR_KEY_HERE",
    "BaseUrl": "https://api.getaddress.io"
  }
}
```

**Environment Variables** (Docker/K8s):
```bash
ASPNETCORE_ENVIRONMENT=Production
AddressLookup__ApiKey=your-api-key
AddressLookup__BaseUrl=https://api.getaddress.io
AddressLookup__TimeoutSeconds=10
AddressLookup__CacheEnabled=true
AddressLookup__CacheDurationMinutes=60
```

## Development Workflow

### Local Development Loop

1. **Make Code Changes**
   ```bash
   # Edit controllers, services, models
   ```

2. **Run Unit Tests**
   ```bash
   dotnet test
   # or with coverage:
   dotnet test /p:CollectCoverage=true
   ```

3. **Run API Locally**
   ```bash
   dotnet run
   ```

4. **Test API Endpoints**
   - Use `tests/local/requests.http` with REST Client
   - Or use Swagger UI at http://localhost:5000/swagger

5. **Debug Issues**
   - Check Application Insights logs
   - Review console output
   - Use breakpoints in VS Code/Visual Studio

6. **Commit and Push**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   git push origin main
   ```

### Git Workflow

```
main (production-ready)
 │
 ├─ release/* (release branches)
 │
 └─ feature/* (feature branches)
     │
     └─ bugfix/* (bug fix branches)
```

Create feature branch:
```bash
git checkout -b feature/postcode-validation
```

Push changes:
```bash
git push origin feature/postcode-validation
```

Create PR on GitHub for code review.

## Running Tests

### Unit Tests

```bash
# Run all tests
dotnet test

# Run specific test class
dotnet test --filter "ClassName=AddressServiceTests"

# Run with coverage
dotnet test /p:CollectCoverage=true /p:CoverageFormat=opencover

# Watch mode (auto-rerun on file changes)
dotnet watch test
```

### Integration Tests (Phase 2)

Tests with actual API calls or mocked external services.

```bash
dotnet test --filter "Category=Integration"
```

### Test Naming Conventions

Follow **Given-When-Then** pattern:

```csharp
[Fact]
public async Task SearchByPostcodeAsync_WithValidPostcode_ReturnsAddresses()
{
    // Given: setup test data
    // When: execute action
    // Assert: verify results
}
```

## Logging

Application uses structured logging with **Serilog** (Phase 2).

### Console Output
```
[10:30:45 INF] Application started
[10:30:46 DBG] AddressService initialized
[10:30:47 INF] Searching addresses for postcode: SW1A1AA
[10:30:48 INF] Found 5 addresses
[10:30:49 ERR] External API call failed: Timeout
```

### Log Levels
- **ERR**: Errors that need immediate attention
- **WRN**: Warnings about potentially problematic situations
- **INF**: General informational messages
- **DBG**: Diagnostic information for debugging

### Viewing Logs

**Console:**
```bash
dotnet run
```

**Application Insights (Production):**
- Logs automatically collected
- Query using KQL in Azure Portal

## Performance Considerations

### Caching
- Response caching enabled (configurable)
- Cache duration: 60 minutes default
- Cache headers: `public, max-age=3600`

### Rate Limiting
- getAddress.io API rate limits: 1000 requests/day (free tier)
- Implement throttling in Phase 2

### Timeouts
- HTTP request timeout: 10 seconds
- API calls must complete within timeout or fail gracefully

## Security Considerations

### API Key Management
- ✅ Never commit API keys to repo
- ✅ Use `appsettings.Development.json` (git-ignored)
- ✅ Use Azure Key Vault in production
- ❌ Don't hardcode keys in code

### Input Validation
- ✅ Postcode format validation
- ✅ Sanitize user input
- ✅ Reject empty/null parameters

### HTTPS
- ✅ HTTPS enforced in production
- ✅ Redirect HTTP to HTTPS
- ✅ Security headers configured

### CORS
- Configured for local development (localhost:3000)
- Restricted in production to specific origins

## Dependency Injection

All services registered in `Program.cs`:

```csharp
builder.Services.AddHttpClient<IAddressService, AddressService>();
builder.Services.Configure<AddressLookupOptions>(
    builder.Configuration.GetSection("AddressLookup"));
```

Benefits:
- Testability (mock dependencies)
- Flexibility (swap implementations)
- Separation of concerns

## Error Handling

### Global Exception Handler

All unhandled exceptions caught and logged:

```csharp
// Program.cs
app.UseExceptionHandler(exceptionHandlerApp =>
{
    exceptionHandlerApp.Run(async context =>
    {
        // Log exception
        // Return user-friendly error response
    });
});
```

### API Error Response Format

```json
{
  "success": false,
  "message": "Invalid postcode format",
  "errors": [
    {
      "field": "postcode",
      "message": "Postcode must be 6-8 characters"
    }
  ],
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Next Steps (Phase 2 & Beyond)

### Phase 2: CI/CD Pipeline
- [ ] GitHub Actions workflows
- [ ] Automated testing
- [ ] Build and publish Docker images
- [ ] Deploy to staging environment

### Phase 3: Kubernetes Deployment
- [ ] Write Kubernetes manifests (Deployment, Service, Ingress)
- [ ] Configure health checks (liveness/readiness probes)
- [ ] Set resource limits and requests
- [ ] Implement autoscaling (HPA)

### Phase 4: Production Readiness
- [ ] Application Insights integration
- [ ] API rate limiting and throttling
- [ ] Advanced caching strategies
- [ ] Database integration (if needed)
- [ ] Multi-region deployment

### Phase 5: Advanced Features
- [ ] Address validation
- [ ] Distance calculation between addresses
- [ ] Batch address lookup
- [ ] GraphQL API endpoint

## Troubleshooting

### Issue: "API Key not configured"
**Solution**: Set `AddressLookup:ApiKey` in `appsettings.Development.json`

### Issue: "External API timeout"
**Solution**: Increase `AddressLookup:TimeoutSeconds` or check getAddress.io service status

### Issue: "Port 5000 already in use"
**Solution**: 
```bash
dotnet run --launch-profile https
# or specify different port:
dotnet run --urls="http://localhost:5001"
```

### Issue: "Docker build fails"
**Solution**: 
```bash
# Clear Docker cache
docker system prune -a
docker-compose up --build
```

## Resources

- [.NET 8 Documentation](https://learn.microsoft.com/en-us/dotnet/core/)
- [ASP.NET Core Best Practices](https://learn.microsoft.com/en-us/aspnet/core/)
- [getAddress.io API Docs](https://getaddress.io/documentation)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## Contributing

1. Create a feature branch
2. Make your changes
3. Write/update tests
4. Ensure tests pass
5. Submit PR with description

## License

MIT License - See LICENSE file

## Support

For issues or questions:
- Create GitHub issue with reproducible steps
- Include logs and error messages
- Describe environment (OS, .NET version, etc.)

---

**Version**: 1.0.0  
**Last Updated**: 2024-01-01  
**Maintainer**: Mahesh
