# Migration Guide: API v1 to v2

## Overview

This guide helps you migrate your ClientATS API integration from v1 to v2. The migration is straightforward as v2 maintains backward compatibility with v1 endpoints while adding new features and improvements.

## Quick Start

### Change Endpoint URLs

Simply update your API endpoint URLs from v1 to v2:

```
Before (v1):
POST https://app.example.com/api/v1/scrape_job

After (v2):
POST https://app.example.com/api/v2/scrape_job
```

## Detailed Changes

### 1. Endpoint URL Changes

Update all endpoint URLs to use `/api/v2/` instead of `/api/v1/`:

#### Job Scraping Endpoint

```javascript
// v1
const response = await fetch('/api/v1/scrape_job', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ url: 'https://...' })
});

// v2 - Same request format
const response = await fetch('/api/v2/scrape_job', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ url: 'https://...' })
});
```

#### Provider Listing Endpoint

```javascript
// v1
const providers = await fetch('/api/v1/llm/providers');

// v2
const providers = await fetch('/api/v2/llm/providers');
```

#### Configuration Endpoint

```javascript
// v1
const config = await fetch('/api/v1/llm/config');

// v2
const config = await fetch('/api/v2/llm/config');
```

### 2. Response Format Changes

Responses remain compatible. The main addition is the `_api` metadata field:

#### v1 Response Structure

```json
{
  "success": true,
  "data": {
    "company_name": "Tech Corp",
    "position_title": "Senior Engineer",
    "job_description": "...",
    "location": "San Francisco, CA",
    "work_model": "hybrid"
  },
  "message": "Job data extracted successfully"
}
```

#### v2 Response Structure

```json
{
  "success": true,
  "data": {
    "company_name": "Tech Corp",
    "position_title": "Senior Engineer",
    "job_description": "...",
    "location": "San Francisco, CA",
    "work_model": "hybrid"
  },
  "message": "Job data extracted successfully",
  "_api": {
    "version": "v2",
    "supported_versions": ["v1", "v2"]
  }
}
```

**How to handle**: The new `_api` field is optional and can be ignored if not needed.

### 3. Response Headers

Both versions include version information in response headers:

```
api-version: v2
content-type: application/json
```

**How to handle**: Check the `api-version` header to verify you're using the correct endpoint version.

### 4. Error Response Changes

Error responses are backward compatible with added metadata:

#### v1 Error Response

```json
{
  "success": false,
  "error": "Invalid URL format",
  "message": "Job scraping failed"
}
```

#### v2 Error Response

```json
{
  "success": false,
  "error": "Invalid URL format",
  "message": "Job scraping failed",
  "_api": {
    "version": "v2",
    "supported_versions": ["v1", "v2"]
  }
}
```

**How to handle**: Existing error handling code will continue to work. Optionally, use the `_api` field for debugging.

## Feature Additions in v2

*(Coming in future v2 releases)*

- Enhanced response metadata
- Additional performance metrics
- Extended error details
- Future backward-compatible enhancements

## Breaking Changes

**None!** v2 is fully backward compatible with v1 request and response formats.

## Testing Your Migration

### 1. Test Endpoints in Order

```bash
# Test providers endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://app.example.com/api/v2/llm/providers

# Test config endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://app.example.com/api/v2/llm/config

# Test scrape endpoint
curl -X POST https://app.example.com/api/v2/scrape_job \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"url":"https://example.com/job"}'
```

### 2. Verify Response Format

Ensure responses include the new `_api` metadata:

```bash
curl -i https://app.example.com/api/v2/llm/providers | grep -i api-version
# Should output: api-version: v2
```

### 3. Test Error Handling

Verify error responses are handled correctly:

```bash
# Should return 400 with error details
curl -X POST https://app.example.com/api/v2/scrape_job \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"url":"invalid"}'
```

## Common Migration Issues

### Issue 1: 404 on /api/v2/endpoints

**Cause**: v2 endpoints not deployed yet

**Solution**: Verify your environment has v2 support. Contact support if using hosted version.

### Issue 2: Unexpected Response Format

**Cause**: Old response caching

**Solution**: Clear HTTP cache and retry requests. Check response headers for actual version.

### Issue 3: Breaking Integration

**Cause**: Older client library cached responses

**Solution**: Update client library to latest version that supports v2.

## Rollback Plan

If issues occur during migration, you can continue using v1:

```javascript
// Fall back to v1 while debugging
const endpoint = '/api/v1/scrape_job';
```

v1 will remain supported for an extended period (timeline in API_VERSIONING.md).

## Support Resources

- [API Versioning Documentation](./API_VERSIONING.md)
- [General API Documentation](./API.md)
- GitHub Issues: Report migration issues
- Support Contact: support@example.com

## Deprecation Timeline

| Phase | Timeline | Action |
|-------|----------|--------|
| Beta | Now | Test v2 in development |
| Stable | Week 2 | Deploy to production |
| Deprecation Notice | Week 3-12 | Extended support period |
| Sunset | Week 13+ | v1 endpoints retired |

## Summary

Migrating from v1 to v2 is simple:
1. Change `/api/v1/` to `/api/v2/` in endpoint URLs
2. Update response parsing if using `_api` metadata
3. Test endpoints in your environment
4. Deploy to production

No changes needed to request bodies or error handling logic.

Last Updated: 2025-12-15
