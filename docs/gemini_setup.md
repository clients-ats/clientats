# Google Gemini LLM Provider Setup Guide

This guide covers configuring and using Google's Gemini API as an LLM provider in Clientats for job data extraction and analysis.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Creating a Google Cloud Project](#creating-a-google-cloud-project)
3. [Enabling the Generative AI API](#enabling-the-generative-ai-api)
4. [Creating an API Key](#creating-an-api-key)
5. [Environment Configuration](#environment-configuration)
6. [Application Configuration](#application-configuration)
7. [Supported Models](#supported-models)
8. [API Quotas and Rate Limiting](#api-quotas-and-rate-limiting)
9. [Billing and Costs](#billing-and-costs)
10. [Testing the Connection](#testing-the-connection)
11. [Troubleshooting](#troubleshooting)
12. [Error Handling](#error-handling)

## Prerequisites

- A Google Cloud account (create at https://cloud.google.com/)
- Access to Google Cloud Console
- The Clientats application running with Elixir/Phoenix

## Creating a Google Cloud Project

### Step 1: Access Google Cloud Console

1. Navigate to [Google Cloud Console](https://console.cloud.google.com/)
2. Sign in with your Google account
3. Click on the project dropdown at the top of the page

### Step 2: Create a New Project

1. Click "NEW PROJECT"
2. Enter a project name (e.g., "Clientats Gemini")
3. Optionally select an organization
4. Click "CREATE"
5. Wait for the project to be created (this may take a minute)

### Step 3: Select the Project

Once created, select your new project from the project dropdown.

## Enabling the Generative AI API

### Step 1: Navigate to APIs & Services

1. In the Google Cloud Console, click the hamburger menu (three horizontal lines)
2. Go to "APIs & Services" > "Library"

### Step 2: Search for Generative AI API

1. In the search bar, type "Generative AI API" or "Vertex AI"
2. Click on "Generative AI API" from the results
3. Click the "ENABLE" button

### Step 3: Verify Activation

Once enabled, you should see the status change to "API is enabled". This process typically takes a few seconds.

## Creating an API Key

### Step 1: Access Credentials Page

1. In Google Cloud Console, go to "APIs & Services" > "Credentials"
2. Click "+ CREATE CREDENTIALS" button
3. Select "API Key" from the dropdown

### Step 2: Copy Your API Key

1. A new API key will be generated
2. Click the copy icon to copy the key to your clipboard
3. Store this key securely (you'll need it for configuration)

### Step 3: Restrict Your API Key (Recommended for Production)

For security, restrict your API key:

1. Click on the newly created key in the credentials list
2. Under "Application restrictions", select "HTTP referrers (web sites)"
3. Add your application's domain (e.g., `yourdomain.com/*`)
4. Under "API restrictions", select "Restrict key" and choose "Generative AI API"
5. Click "SAVE"

## Environment Configuration

### Development Environment

Add the following to your `.env.example` file:

```bash
# Google Gemini Configuration
GEMINI_API_KEY=AIza...your-api-key-here...
GEMINI_MODEL=gemini-2.0-flash
GEMINI_VISION_MODEL=gemini-2.0-flash
GEMINI_TEXT_MODEL=gemini-2.0-flash
GEMINI_API_VERSION=v1beta
```

### Create or Update .env File

1. Copy `.env.example` to `.env` if not already done
2. Replace the placeholder API key with your actual API key
3. Optionally customize the model selections (see [Supported Models](#supported-models))

Example:
```bash
GEMINI_API_KEY=AIzaSyD...your-actual-key-here...12345
GEMINI_MODEL=gemini-2.0-flash
GEMINI_VISION_MODEL=gemini-2.0-flash
GEMINI_TEXT_MODEL=gemini-1.5-pro
GEMINI_API_VERSION=v1beta
```

### Production Environment

Set environment variables through your deployment platform:

- **Heroku**: Use Config Vars in Settings
- **AWS**: Use Systems Manager Parameter Store or Secrets Manager
- **Google Cloud**: Use Secret Manager
- **Docker**: Use environment variables or secrets
- **Traditional Server**: Use systemd environment files

Example for Docker Compose:
```yaml
environment:
  GEMINI_API_KEY: ${GEMINI_API_KEY}
  GEMINI_MODEL: gemini-2.0-flash
  GEMINI_VISION_MODEL: gemini-2.0-flash
```

## Application Configuration

The application automatically picks up Gemini configuration from environment variables. The configuration is used in:

### Development Configuration (`config/dev.exs`)

```elixir
config :req_llm,
  providers: %{
    google: %{
      api_key: System.get_env("GEMINI_API_KEY"),
      default_model: System.get_env("GEMINI_MODEL") || "gemini-2.0-flash",
      vision_model: System.get_env("GEMINI_VISION_MODEL") || "gemini-2.0-flash",
      api_version: System.get_env("GEMINI_API_VERSION") || "v1beta"
    }
  },
  fallback_providers: [:anthropic, :mistral, :google, :ollama]
```

### Production Configuration (`config/runtime.exs`)

```elixir
config :req_llm,
  providers: %{
    google: %{
      api_key: System.get_env("GEMINI_API_KEY"),
      default_model: System.get_env("GEMINI_MODEL") || "gemini-2.0-flash",
      vision_model: System.get_env("GEMINI_VISION_MODEL") || "gemini-2.0-flash",
      api_version: System.get_env("GEMINI_API_VERSION") || "v1beta",
      timeout: 30_000,
      max_retries: 3
    }
  },
  fallback_providers: [:anthropic, :mistral, :google, :ollama]
```

## Supported Models

Google Gemini offers multiple models optimized for different use cases:

### Current Available Models

| Model | Type | Best For | Input Limit |
|-------|------|----------|------------|
| **gemini-2.0-flash** | Multimodal | Fast, general-purpose extraction | 1M tokens |
| **gemini-2.0-flash-lite** | Multimodal | Fast, lightweight tasks | 1M tokens |
| **gemini-1.5-pro** | Multimodal | Complex reasoning, detailed analysis | 2M tokens |
| **gemini-1.5-pro-002** | Multimodal | Latest 1.5 version with improvements | 2M tokens |
| **gemini-1.5-flash** | Multimodal | Fast, cost-effective | 1M tokens |
| **gemini-1.5-flash-002** | Multimodal | Latest 1.5 flash version | 1M tokens |

### Recommended Configuration

- **For job posting extraction (HTML)**: `gemini-2.0-flash` (default)
  - Fast response time (typically 1-3 seconds)
  - Excellent JSON parsing capability
  - Good balance of cost and quality

- **For screenshot analysis (vision)**: `gemini-2.0-flash`
  - Strong visual understanding
  - Can read screenshots accurately
  - Handles complex UI layouts

- **For detailed analysis**: `gemini-1.5-pro`
  - Better reasoning for complex job requirements
  - More accurate for nuanced salary/benefits extraction
  - Slower response time, higher cost

## API Quotas and Rate Limiting

### Default Quotas

Google provides free quota for Gemini API:

- **Requests per minute (RPM)**: Varies by model
  - Flash models: 360 RPM (free tier)
  - Pro models: 180 RPM (free tier)

- **Tokens per minute (TPM)**: Varies by tier
  - Free tier: Limited TPM

### Paid Quota

Once you enable billing:

- **Standard tier**: Higher quotas based on billing
- **Enterprise tier**: Custom quotas, volume discounts

### Rate Limit Handling

The application includes automatic retry logic for rate limit errors (HTTP 429):

- Exponential backoff with jitter
- Max 3 retries by default (configurable)
- Fallback to alternative providers if available

### Checking Quotas

1. Go to "APIs & Services" > "Quotas" in Google Cloud Console
2. Filter by your project
3. Look for "Generative AI API"
4. Current usage and limits are displayed

## Billing and Costs

### Pricing Model

Google Gemini uses a token-based pricing model:

- **Input tokens**: Charged per 1 million tokens
- **Output tokens**: Usually 2-3x cost of input tokens

### Current Pricing (as of latest update)

| Model | Input | Output |
|-------|-------|--------|
| gemini-2.0-flash | $0.075/1M | $0.30/1M |
| gemini-1.5-flash | $0.075/1M | $0.30/1M |
| gemini-1.5-pro | $1.50/1M | $6.00/1M |

### Cost Estimation for Job Posting Extraction

For a typical job posting (5KB of HTML):

- **Input tokens**: ~1,200 tokens
- **Output tokens**: ~500 tokens (JSON response)
- **Estimated cost**: $0.0015 - $0.002 per extraction

For 1,000 job postings: ~$1.50 - $2.00

### Free Tier Limitations

- 60 requests per minute
- Limited to 50,000 tokens per day combined
- Free quota resets daily
- Good for testing and small-scale usage

### Setting Budget Alerts

1. Go to "Billing" in Google Cloud Console
2. Click "Budgets and alerts"
3. Click "CREATE BUDGET"
4. Set a monthly budget and alert threshold
5. Receive email alerts when approaching budget

## Testing the Connection

### Via Application UI

1. Navigate to the LLM Configuration page in Clientats
2. Locate Google Gemini provider settings
3. Enter your API key
4. Click "Test Connection"
5. You should see a success message

### Via Command Line (IEx)

```elixir
# Start interactive console
iex -S mix

# Test Gemini connection
config = %{api_key: "AIza...your-key..."}
Clientats.LLMConfig.test_connection(:gemini, config)
# Should return: {:ok, "connected"} or {:error, reason}

# Test with actual extraction
prompt = "Extract job title from this: Senior Software Engineer position"
Clientats.LLM.Service.extract_job_data(content, url, :generic, :google)
```

### Verify Environment Variables

```bash
# Check if Gemini API key is loaded
echo $GEMINI_API_KEY

# Should output your API key (first few characters visible for security)
```

### Monitor API Usage

1. Go to "APIs & Services" > "Quotas" in Google Cloud Console
2. Filter for "Generative AI API"
3. View "Current usage" to see real-time API calls

## Troubleshooting

### Issue: 401 Authentication Error

**Error Message**: `Authentication failed: Invalid API key or expired credentials`

**Causes**:
- API key is incorrect or malformed
- API key has been revoked
- API key was copied incorrectly (trailing spaces)
- API key belongs to wrong project

**Solutions**:
1. Verify API key in Google Cloud Console
2. Delete and create a new API key
3. Check for trailing spaces in `.env` file
4. Ensure you're using key from the correct Google Cloud Project
5. Copy the key directly from the console (don't paste from email)

### Issue: 403 Access Denied

**Error Message**: `Access denied: Generative AI API may not be enabled in your Google Cloud project`

**Causes**:
- Generative AI API not enabled
- API key restrictions don't include your application's domain
- Project permissions issue

**Solutions**:
1. Go to "APIs & Services" > "Library"
2. Search for "Generative AI API"
3. Verify the status shows "API is enabled"
4. If disabled, click "ENABLE"
5. Check API key restrictions in Credentials page

### Issue: 429 Rate Limited

**Error Message**: `Rate limited: Too many requests. Please wait before trying again.`

**Causes**:
- Exceeded quota for current billing period
- Sent too many requests in short timeframe
- Free tier quota exhausted

**Solutions**:
1. Wait a few minutes and retry (automatic retry built in)
2. Check current usage in Quotas page
3. Verify you're on appropriate billing plan
4. Implement request queuing for batch operations
5. Consider upgrading to paid plan for higher quotas

### Issue: 500 Server Error

**Error Message**: `Server error: Google Generative AI service is temporarily unavailable`

**Causes**:
- Google API service temporarily down
- Network connectivity issue
- API version deprecated

**Solutions**:
1. Wait 30 seconds and retry (automatic retry built in)
2. Check Google Cloud Status Dashboard: https://status.cloud.google.com/
3. Verify network connectivity
4. Check if API version (v1beta) is still current

### Issue: Model Not Found

**Error Message**: `API returned error: Model not found`

**Causes**:
- Model name is misspelled
- Model has been deprecated
- Model not available in your region

**Solutions**:
1. Verify model name spelling
2. Check [supported models](#supported-models) section
3. Try a different model from the available list
4. Check Google Gemini API documentation for latest models

### Issue: JSON Parse Error

**Error Message**: `Failed to parse LLM response`

**Causes**:
- Response is not valid JSON
- Prompt is requesting non-JSON format
- Gemini returned error response

**Solutions**:
1. Check prompt template in `lib/clientats/llm/prompt_templates.ex`
2. Verify prompt requests JSON format explicitly
3. Check API logs for actual response
4. Try with a different model

## Error Handling

### Automatic Error Handling

The application includes comprehensive error handling:

1. **Retryable Errors** (auto-retry):
   - 429 (Rate Limited)
   - 500+ (Server Errors)
   - Connection timeouts
   - Network errors

2. **Fallback Strategy**:
   - If Gemini fails with retryable error, tries next provider
   - Fallback order: `anthropic` → `mistral` → `google` → `ollama`
   - Each fallback includes its own retry logic

3. **Permanent Errors** (no retry):
   - 400 (Bad Request)
   - 401 (Authentication)
   - 403 (Permission Denied)
   - Invalid content format

### Logging and Diagnostics

The application logs all connection attempts and errors:

```bash
# View logs during development
tail -f logs/development.log | grep -i gemini

# View specific errors
grep "ERROR.*gemini" logs/development.log
```

### Debug Mode

For detailed API request/response logging:

```bash
# In config/dev.exs
config :req_llm,
  enable_logging: true,
  debug_mode: true

# Then restart the server and check logs
```

## Fallback Provider Strategy

When using Gemini as a provider, the system maintains this fallback chain:

1. **Primary Provider**: Configured in `:primary_provider` setting
2. **Fallback Providers** (in order):
   - `anthropic` (Claude)
   - `mistral` (Mistral Large)
   - `google` (Gemini)
   - `ollama` (Local LLM)

This ensures extraction always completes, even if one provider fails.

## Performance Optimization

### Batching Requests

For extracting multiple job postings:

```elixir
# Instead of:
Enum.each(urls, fn url ->
  Clientats.LLM.Service.extract_job_data_from_url(url)
end)

# Use Task-based parallelization:
urls
|> Task.async_stream(&Clientats.LLM.Service.extract_job_data_from_url/1)
|> Enum.map(fn {:ok, result} -> result end)
```

### Caching Results

The application caches extraction results by URL:

- Default TTL: 24 hours
- Cached by content URL
- Automatically used on subsequent requests
- Reduces API calls and costs

### Token Optimization

Writing efficient prompts:

1. Keep prompts concise
2. Remove unnecessary HTML/formatting
3. Use specific, targeted prompts
4. Request only needed fields in JSON

## Support and Additional Resources

- [Google Gemini API Documentation](https://ai.google.dev/)
- [Google Cloud Support](https://cloud.google.com/support)
- [API Quotas Documentation](https://cloud.google.com/docs/quotas)
- [Token Counting Guide](https://ai.google.dev/pricing/token-counting)

## Appendix: Configuration Template

Complete `.env` template for Gemini setup:

```bash
# Google Gemini LLM Configuration
GEMINI_API_KEY=AIza...YOUR_API_KEY_HERE...
GEMINI_MODEL=gemini-2.0-flash
GEMINI_VISION_MODEL=gemini-2.0-flash
GEMINI_TEXT_MODEL=gemini-2.0-flash
GEMINI_API_VERSION=v1beta

# Optional: Enable debug logging
LLM_ENABLE_LOGGING=true

# Optional: Set request timeout (milliseconds)
GEMINI_TIMEOUT=30000
```

---

**Last Updated**: December 2024
**Gemini Models Supported**: 2.0-flash, 1.5-pro, 1.5-flash
**API Version**: v1beta
