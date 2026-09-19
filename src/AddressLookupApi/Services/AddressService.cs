using System.Net.Http.Json;
using System.Text.Json.Serialization;
using AddressLookupApi.Models;
using Microsoft.Extensions.Logging;

namespace AddressLookupApi.Services;

/// <summary>
/// Address service implementation using Postcodes.io API.
/// </summary>
public class AddressService : IAddressService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<AddressService> _logger;
    private readonly string _baseUrl;

    public AddressService(HttpClient httpClient, ILogger<AddressService> logger, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _logger = logger;
        _baseUrl = configuration["AddressLookup:BaseUrl"]?.TrimEnd('/')
            ?? throw new InvalidOperationException("AddressLookup:BaseUrl is not configured.");
    }

    /// <inheritdoc/>
    public async Task<AddressSearchResponse> SearchByPostcodeAsync(string postcode, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(postcode))
        {
            throw new ArgumentException("Postcode cannot be empty", nameof(postcode));
        }

        var normalizedPostcode = postcode.Trim().Replace(" ", "").ToUpperInvariant();

        _logger.LogInformation("Searching for postcode: {Postcode}", normalizedPostcode);

        try
        {
            var url = $"{_baseUrl}/{normalizedPostcode}";
            var response = await _httpClient.GetAsync(url, cancellationToken);

            if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                return new AddressSearchResponse
                {
                    SearchPostcode = normalizedPostcode,
                    Addresses = new List<Address>()
                };
            }

            response.EnsureSuccessStatusCode();

            var payload = await response.Content.ReadFromJsonAsync<PostcodesIoResponse>(cancellationToken)
                ?? new PostcodesIoResponse();

            var result = payload.Result;
            var address = result is null
                ? null
                : new Address
                {
                    Postcode = result.Postcode,
                    Country = result.Country,
                    Region = result.Region,
                    AdminDistrict = result.AdminDistrict,
                    ParliamentaryConstituency = result.ParliamentaryConstituency,
                    Latitude = result.Latitude,
                    Longitude = result.Longitude,
                    Codes = result.Codes is null
                        ? null
                        : new PostcodeCodes
                        {
                            AdminDistrict = result.Codes.AdminDistrict,
                            ParliamentaryConstituency = result.Codes.ParliamentaryConstituency,
                            AdminWard = result.Codes.AdminWard,
                            Ccg = result.Codes.Ccg,
                            Nuts = result.Codes.Nuts
                        },
                    FormattedAddress = $"{result.Postcode}, {result.AdminDistrict}, {result.Country}"
                };

            var addresses = address is null ? new List<Address>() : new List<Address> { address };

            _logger.LogInformation("Found {Count} postcode record(s) for {Postcode}", addresses.Count, normalizedPostcode);

            return new AddressSearchResponse
            {
                SearchPostcode = normalizedPostcode,
                Addresses = addresses
            };
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "HTTP request failed when searching for postcode {Postcode}", normalizedPostcode);
            throw new InvalidOperationException($"Failed to search addresses: {ex.Message}", ex);
        }
        catch (TaskCanceledException ex)
        {
            _logger.LogError(ex, "Request timeout when searching for postcode {Postcode}", normalizedPostcode);
            throw new InvalidOperationException($"Address search request timed out: {ex.Message}", ex);
        }
    }

    private sealed class PostcodesIoResponse
    {
        public int Status { get; set; }
        public PostcodesIoResult? Result { get; set; }
    }

    private sealed class PostcodesIoResult
    {
        [JsonPropertyName("postcode")]
        public string? Postcode { get; set; }

        [JsonPropertyName("country")]
        public string? Country { get; set; }

        [JsonPropertyName("region")]
        public string? Region { get; set; }

        [JsonPropertyName("admin_district")]
        public string? AdminDistrict { get; set; }

        [JsonPropertyName("parliamentary_constituency")]
        public string? ParliamentaryConstituency { get; set; }

        [JsonPropertyName("longitude")]
        public decimal? Longitude { get; set; }

        [JsonPropertyName("latitude")]
        public decimal? Latitude { get; set; }

        [JsonPropertyName("codes")]
        public PostcodesIoCodes? Codes { get; set; }
    }

    private sealed class PostcodesIoCodes
    {
        [JsonPropertyName("admin_district")]
        public string? AdminDistrict { get; set; }

        [JsonPropertyName("parliamentary_constituency")]
        public string? ParliamentaryConstituency { get; set; }

        [JsonPropertyName("admin_ward")]
        public string? AdminWard { get; set; }

        [JsonPropertyName("ccg")]
        public string? Ccg { get; set; }

        [JsonPropertyName("nuts")]
        public string? Nuts { get; set; }
    }
}
