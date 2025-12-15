# API Versioning and Deprecation Strategy

## Overview

ClientATS API uses URL-based versioning to manage breaking changes and maintain backward compatibility. All endpoints are prefixed with a version number (e.g., `/api/v1/`, `/api/v2/`).

## Supported Versions

### Current Versions

| Version | Status | Supported | Sunset Date | Notes |
|---------|--------|-----------|-------------|-------|
| v1 | Active | Yes | TBD | Current stable version |
| v2 | Beta | Yes | N/A | Future enhanced version (planned) |

### Legacy

| Version | Status | Notes |
|---------|--------|-------|
| /api/* | Deprecated | Legacy unversioned endpoints redirect to v1 |

## API Version Endpoints

### Version 1 (Current - Stable)

Base URL: `/api/v1`

#### Available Endpoints

```
POST   /api/v1/scrape_job        # Extract job data from URL
GET    /api/v1/llm/providers     # List available LLM providers
GET    /api/v1/llm/config        # Get LLM service configuration
```

### Version 2 (Beta - Future)

Base URL: `/api/v2`

Same endpoints as v1, with planned enhancements:
- Enhanced response metadata
- Improved error handling
- Additional performance metrics
- Extended fields for future compatibility

## Backward Compatibility

### Legacy Routes

For backward compatibility, unversioned routes are supported and automatically default to v1:

```
POST   /api/scrape_job           # Equivalent to /api/v1/scrape_job
GET    /api/llm/providers        # Equivalent to /api/v1/llm/providers
GET    /api/llm/config           # Equivalent to /api/v1/llm/config
```

**Note**: Legacy routes will be deprecated in a future release. New clients should use versioned endpoints.

## Response Format

### Versioning Metadata

All responses include API versioning metadata:

```json
{
  "success": true,
  "data": { /* response data */ },
  "message": "...",
  "_api": {
    "version": "v1",
    "supported_versions": ["v1", "v2"]
  }
}
```

### Response Headers

All API responses include version information in headers:

```
api-version: v1
content-type: application/json
```

## Deprecation Notices

### Deprecation Headers (RFC 8594)

When an endpoint is deprecated, responses include standard deprecation headers:

```
deprecation: true
sunset: Wed, 21 Nov 2025 08:00:00 GMT
link: </api/v2/endpoint>; rel="successor-version"
```

### Deprecation Metadata

Deprecated endpoints include deprecation information in response body:

```json
{
  "_deprecation": {
    "status": "deprecated",
    "sunset_date": "2025-11-21",
    "migration_guide": "https://docs.example.com/api/migration/v1-to-v2",
    "successor_version": "v2"
  }
}
```

## Migration Guide: v1 to v2

*(This will be expanded when v2 is released)*

## Version Support Timeline

### Planned Timeline

1. **Phase 1** (Week 1-2): v2 announced and made available as beta
2. **Phase 2** (Week 3-4): v2 becomes stable, v1 marked as deprecated
3. **Phase 3** (Week 5-12): Extended support period for v1
4. **Phase 4** (Week 13+): v1 sunset, removal of legacy routes

### Extended Support Period

Versions receive extended support to allow adequate migration time:

- **Active**: Full support, bug fixes and features
- **Deprecated**: Maintenance mode, only critical security fixes
- **Sunset**: Endpoint returns 410 Gone

## Best Practices

### For API Clients

1. **Use versioned endpoints** in production
   ```
   ✅ POST /api/v1/scrape_job
   ❌ POST /api/scrape_job (avoid - may change)
   ```

2. **Handle deprecation headers**
   - Monitor for `deprecation: true` header
   - Check `sunset` header for timeline
   - Follow migration guides proactively

3. **Support multiple versions** if possible
   ```javascript
   const endpoint = client.supports('v2') ? '/api/v2/scrape_job' : '/api/v1/scrape_job';
   ```

4. **Test version upgrade path** before production migration
   - Use staging environment to test v2
   - Verify response format compatibility
   - Update error handling

### For API Developers

1. **Always version new endpoints**
   ```elixir
   # ✅ Good
   scope "/api/v2" do
     post "/new_endpoint", MyController, :action
   end

   # ❌ Avoid
   scope "/api" do
     post "/new_endpoint", MyController, :action
   end
   ```

2. **Maintain backward compatibility** in v1
   - Don't break existing endpoint contracts
   - Add features in new versions
   - Use deprecation for changes

3. **Document version differences**
   - Changelog per version
   - Migration guides
   - Example requests/responses

4. **Monitor deprecation usage**
   - Track old version requests
   - Alert when reaching sunset date
   - Support clients during migration

## Response Status Codes

All versions follow same HTTP status codes:

| Code | Meaning | Example |
|------|---------|---------|
| 200 | Success | Data extracted, providers listed |
| 400 | Bad Request | Invalid URL, missing parameters |
| 401 | Unauthorized | Authentication required |
| 429 | Rate Limited | Too many requests |
| 500 | Server Error | Unexpected error |
| 503 | Service Unavailable | All LLM providers down |

## Error Handling

Errors include version info for proper debugging:

```json
{
  "success": false,
  "error": "Invalid URL format",
  "message": "Job scraping failed",
  "_api": {
    "version": "v1",
    "supported_versions": ["v1", "v2"]
  }
}
```

## Related Documents

- [API.md](./API.md) - General API documentation
- [CHANGELOG.md](../CHANGELOG.md) - Version changes and updates
- [MIGRATION.md](./MIGRATION.md) - Version migration guides

## Support

For questions about API versioning or migration:
1. Check this document and related docs
2. Review GitHub issues
3. Contact support team

Last Updated: 2025-12-15
