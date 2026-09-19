# syntax=docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY src/AddressLookupApi/AddressLookupApi.csproj src/AddressLookupApi/
RUN dotnet restore src/AddressLookupApi/AddressLookupApi.csproj

COPY src/AddressLookupApi/ src/AddressLookupApi/
RUN dotnet publish src/AddressLookupApi/AddressLookupApi.csproj \
    --configuration Release \
    --output /app/publish \
    --no-restore \
    --property:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# curl is required by the HEALTHCHECK below; installed while still root
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

COPY --from=build /app/publish .

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

USER $APP_UID
ENTRYPOINT ["dotnet", "AddressLookupApi.dll"]
