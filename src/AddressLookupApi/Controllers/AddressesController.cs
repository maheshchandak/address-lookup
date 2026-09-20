using AddressLookupApi.Models;
using AddressLookupApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace AddressLookupApi.Controllers;

/// <summary>
/// Address lookup API endpoints
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class AddressesController : ControllerBase
{
    private readonly IAddressService _addressService;
    private readonly ILogger<AddressesController> _logger;

    public AddressesController(IAddressService addressService, ILogger<AddressesController> logger)
    {
        _addressService = addressService;
        _logger = logger;
    }

    /// <summary>
    /// Search for addresses by postcode
    /// </summary>
    /// <param name="postcode">UK postcode to search (e.g., SW1A1AA or SW1A 1AA)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of addresses matching the postcode</returns>
    /// <response code="200">Addresses found successfully</response>
    /// <response code="400">Invalid postcode format</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("search")]
    [ProducesResponseType(typeof(AddressSearchResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<AddressSearchResponse>> SearchByPostcode(
        [FromQuery] string postcode,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("SearchByPostcode endpoint called with postcode: {Postcode}", postcode);
        
        if (string.IsNullOrWhiteSpace(postcode))
        {
            var error = new ErrorResponse
            {
                Code = "INVALID_POSTCODE",
                Message = "Postcode parameter is required"
            };
            return BadRequest(error);
        }

        try
        {
            var result = await _addressService.SearchByPostcodeAsync(postcode, cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogError(ex, "Invalid operation during address search for postcode: {Postcode}", postcode);
            var error = new ErrorResponse
            {
                Code = "ADDRESS_SERVICE_ERROR",
                Message = ex.Message,
                Details = new() { { "Exception", ex.GetType().Name } }
            };
            return StatusCode(StatusCodes.Status500InternalServerError, error);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error during address search for postcode: {Postcode}", postcode);
            var error = new ErrorResponse
            {
                Code = "INTERNAL_ERROR",
                Message = "An unexpected error occurred while searching for addresses",
                Details = new() { { "Exception", ex.GetType().Name } }
            };
            return StatusCode(StatusCodes.Status500InternalServerError, error);
        }
    }

    /// <summary>
    /// Get all available address details (for demonstration)
    /// </summary>
    /// <returns>List of available address fields</returns>
    /// <response code="200">Information retrieved successfully</response>
    [HttpGet("info")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public ActionResult GetAddressInfo()
    {
        var addressFields = new
        {
            Version = "1.0.0",
            Description = "Address Lookup API using Postcodes.io",
            AvailableFields = new[]
            {
                "Postcode",
                "Country",
                "Region",
                "AdminDistrict",
                "ParliamentaryConstituency",
                "Latitude",
                "Longitude",
                "Codes"
            }
        };

        return Ok(addressFields);
    }
}
