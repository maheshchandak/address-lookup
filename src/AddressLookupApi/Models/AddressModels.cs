using System.Text.Json.Serialization;

namespace AddressLookupApi.Models;

/// <summary>
/// Request model for address search by postcode.
/// </summary>
public class AddressSearchRequest
{
    /// <summary>
    /// UK postcode to search for (for example, "SW1A1AA" or "SW1A 1AA").
    /// </summary>
    public required string Postcode { get; set; }
}

/// <summary>
/// Address data returned to the source caller from the Postcodes.io provider.
/// </summary>
public class Address
{
    /// <summary>
    /// UK postcode.
    /// </summary>
    [JsonPropertyName("postcode")]
    public string? Postcode { get; set; }

    /// <summary>
    /// Country name.
    /// </summary>
    [JsonPropertyName("country")]
    public string? Country { get; set; }

    /// <summary>
    /// Region name.
    /// </summary>
    [JsonPropertyName("region")]
    public string? Region { get; set; }

    /// <summary>
    /// Administrative district.
    /// </summary>
    [JsonPropertyName("admin_district")]
    public string? AdminDistrict { get; set; }

    /// <summary>
    /// Parliamentary constituency.
    /// </summary>
    [JsonPropertyName("parliamentary_constituency")]
    public string? ParliamentaryConstituency { get; set; }

    /// <summary>
    /// Latitude coordinate.
    /// </summary>
    [JsonPropertyName("latitude")]
    public decimal? Latitude { get; set; }

    /// <summary>
    /// Longitude coordinate.
    /// </summary>
    [JsonPropertyName("longitude")]
    public decimal? Longitude { get; set; }

    /// <summary>
    /// Nested code keys returned by Postcodes.io.
    /// </summary>
    [JsonPropertyName("codes")]
    public PostcodeCodes? Codes { get; set; }

    /// <summary>
    /// Human-friendly summary string.
    /// </summary>
    [JsonPropertyName("formatted_address")]
    public string? FormattedAddress { get; set; }
}

/// <summary>
/// Nested code set returned by Postcodes.io.
/// </summary>
public class PostcodeCodes
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

/// <summary>
/// Response DTO for postcode search results.
/// </summary>
public class AddressSearchResponse
{
    /// <summary>
    /// List of addresses for the postcode.
    /// </summary>
    public List<Address> Addresses { get; set; } = new();

    /// <summary>
    /// Number of locations returned.
    /// </summary>
    public int Count => Addresses.Count;

    /// <summary>
    /// Search postcode used.
    /// </summary>
    public string? SearchPostcode { get; set; }

    /// <summary>
    /// When the search was performed.
    /// </summary>
    public DateTime SearchedAt { get; set; } = DateTime.UtcNow;
}

/// <summary>
/// Error response structure.
/// </summary>
public class ErrorResponse
{
    public string? Code { get; set; }
    public string? Message { get; set; }
    public Dictionary<string, object>? Details { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}
