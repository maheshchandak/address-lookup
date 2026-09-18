using AddressLookupApi.Services;
using Azure.Identity;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Serilog;
using System.Net.Mime;
using System.Text.Json;

// Configure Serilog for structured logging
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .WriteTo.Console(outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz}] [{Level:u3}] {Message:lj}{NewLine}{Exception}")
    .CreateLogger();

try
{
    Log.Information("Starting Address Lookup API");

    var builder = WebApplication.CreateBuilder(args);

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

    // Add Serilog logging
    builder.Host.UseSerilog();

    // Add services to the container
    builder.Services.AddControllers();

    // Add Swagger/OpenAPI documentation
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(options =>
    {
        options.SwaggerDoc("v1", new()
        {
            Title = "Address Lookup API",
            Version = "1.0.0",
            Description = "A .NET 8 Web API for searching UK postcode metadata using Postcodes.io",
            Contact = new()
            {
                Name = "Development Team",
                Url = new Uri("https://github.com")
            },
            License = new()
            {
                Name = "MIT"
            }
        });

        var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
        var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
        if (File.Exists(xmlPath))
        {
            options.IncludeXmlComments(xmlPath);
        }
    });

    // Add health checks
    builder.Services.AddHealthChecks()
        .AddCheck("self", () => Microsoft.Extensions.Diagnostics.HealthChecks.HealthCheckResult.Healthy("API is running"));

    // Configure HttpClient for Postcodes.io API
    builder.Services.AddHttpClient<IAddressService, AddressService>(client =>
    {
        client.Timeout = TimeSpan.FromSeconds(10);
    });

    var app = builder.Build();

    // Configure the HTTP request pipeline
    if (app.Environment.IsDevelopment())
    {
        Log.Information("Running in Development environment");
        app.UseSwagger();
        app.UseSwaggerUI(options =>
        {
            options.SwaggerEndpoint("/swagger/v1/swagger.json", "Address Lookup API v1");
            options.RoutePrefix = string.Empty; // Serve Swagger UI at root
        });
    }

    // Add HTTPS redirection (disabled for local development on port 8080)
    // app.UseHttpsRedirection();

    app.UseAuthorization();

    // Map health check endpoints for Kubernetes probes
    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        ResponseWriter = WriteHealthCheckResponse,
        Predicate = _ => true
    });

    app.MapHealthChecks("/ready", new HealthCheckOptions
    {
        ResponseWriter = WriteHealthCheckResponse,
        Predicate = _ => true
    });

    // Map API routes
    app.MapControllers();

    Log.Information("Address Lookup API started successfully");
    await app.RunAsync();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

/// <summary>
/// Custom health check response writer for Kubernetes probes
/// </summary>
static Task WriteHealthCheckResponse(HttpContext context, Microsoft.Extensions.Diagnostics.HealthChecks.HealthReport report)
{
    context.Response.ContentType = MediaTypeNames.Application.Json;

    var response = new
    {
        status = report.Status.ToString(),
        timestamp = DateTime.UtcNow,
        checks = report.Entries.Select(e => new
        {
            name = e.Key,
            status = e.Value.Status.ToString(),
            duration = e.Value.Duration.TotalMilliseconds,
            description = e.Value.Description
        })
    };

    return context.Response.WriteAsJsonAsync(response);
}
