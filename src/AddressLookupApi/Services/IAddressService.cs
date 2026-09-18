using AddressLookupApi.Models;

namespace AddressLookupApi.Services;

/// <summary>
/// Interface for address lookup service
/// </summary>
public interface IAddressService
{
    /// <summary>
    /// Search for addresses by postcode
    /// </summary>
    /// <param name="postcode">UK postcode to search</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Address search response</returns>
    Task<AddressSearchResponse> SearchByPostcodeAsync(string postcode, CancellationToken cancellationToken = default);
}
