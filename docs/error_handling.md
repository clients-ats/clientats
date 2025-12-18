# Error Handling and Fallback Mechanisms

This document describes the comprehensive error handling system implemented for LLM operations in ClientATS.

## Overview

The error handling system provides:

1. **Error Classification** - Distinguishes between retryable (temporary) and permanent errors
2. **Retry Logic** - Implements exponential backoff for transient failures
3. **Fallback Mechanisms** - Attempts multiple providers when primary fails
4. **User-Friendly Messages** - Converts technical errors to understandable messages
5. **Circuit Breaking** - Prevents repeated calls to failing services
6. **Comprehensive Logging** - Tracks errors for debugging and monitoring

## Architecture

### Key Modules

#### 1. `Clientats.LLM.ErrorHandler`

Centralized error handling utilities:

- **`retryable?(error)`** - Determines if error should trigger a retry
- **`calculate_backoff(attempt, base_delay)`** - Computes exponential backoff delay
- **`with_retry(fun, options)`** - Executes function with automatic retry logic
- **`user_friendly_message(error)`** - Converts errors to user-facing messages
- **`normalize_error(error)`** - Standardizes error formats
- **`error_context(error, context)`** - Creates detailed error metadata

#### 2. `Clientats.LLM.CircuitBreaker`

Provider health management:

- **`register_provider(provider, health_check_fn, opts)`** - Register a provider
- **`record_success(provider)`** - Mark successful operation
- **`record_failure(provider)`** - Mark failed operation
- **`available?(provider)`** - Check if provider accepts requests
- **`health_status()`** - Get health of all providers

States:
- `:closed` - Normal operation
- `:open` - Too many failures, rejecting requests
- `:half_open` - Testing recovery with limited requests

#### 3. `Clientats.LLM.Service`

Main extraction service with integrated error handling:

- Uses `ErrorHandler.retryable?` to decide whether to fallback
- Implements exponential backoff in retry loops
- Provides detailed logging at each step
- Routes to fallback providers automatically

## Error Classification

### Retryable Errors (Temporary)

These errors indicate transient failures that may succeed on retry:

- **Timeouts** - `:timeout`, `{:timeout, details}`
- **Rate Limiting** - `:rate_limited`, `{:rate_limited, details}`
- **Server Errors** - `{:http_error, 5xx}` (500, 502, 503, etc.)
- **Specific Status Codes** - 408 (Request Timeout), 429 (Rate Limit)
- **Connection Issues** - `:unavailable`, `:connection_refused`, `{:connection_error, details}`

### Non-Retryable Errors (Permanent)

These errors indicate issues that won't be resolved by retry:

- **Invalid Input** - `:invalid_content`, `:content_too_large`, `:invalid_url`
- **Authentication** - `:invalid_api_key` (but `:auth_error` is retryable)
- **Format Issues** - `:invalid_response_format`, `:missing_required_fields`
- **Client Errors** - `{:http_error, 4xx}` except 408 and 429
- **Exceptions** - `{:exception, message}`

## Usage Examples

### Basic Retry with Backoff

```elixir
ErrorHandler.with_retry(
  fn -> perform_operation() end,
  max_retries: 3,
  base_delay: 100
)
```

### Custom Retry Logic

```elixir
ErrorHandler.with_retry(
  fn -> call_external_api() end,
  max_retries: 5,
  base_delay: 500,
  retryable: &my_custom_retryable_fn/1
)
```

### Error Context for Logging

```elixir
case extract_job_data(content, url) do
  {:ok, data} -> {:ok, data}
  {:error, reason} ->
    context = ErrorHandler.error_context(reason, %{url: url})
    Logger.error("Extraction failed", context)
    {:error, reason}
end
```

### User-Friendly Messages

```elixir
case Service.extract_job_data_from_url(url) do
  {:ok, data} -> {:ok, data}
  {:error, reason} ->
    message = ErrorHandler.user_friendly_message(reason)
    send_error_to_user(message)  # "Request timed out. Please try again."
end
```

## Exponential Backoff

The system implements exponential backoff with jitter:

```
Formula: delay = base_delay * (2 ^ attempt) + random(0, delay * 0.1)

Examples (base_delay = 100ms):
  Attempt 0: ~100ms + jitter
  Attempt 1: ~200ms + jitter
  Attempt 2: ~400ms + jitter
  Attempt 3: ~800ms + jitter
```

This prevents thundering herd problems when multiple clients retry simultaneously.

## Fallback Providers

When the primary LLM provider fails with a retryable error, the system automatically tries fallback providers in order:

**Configuration** (`runtime.exs`):
```elixir
fallback_providers: [:anthropic, :mistral, :ollama]
```

**Flow**:
1. Try primary provider (e.g., OpenAI)
2. If retryable error, try Anthropic
3. If retryable error, try Mistral
4. If retryable error, try Ollama
5. If all fail, return `:all_providers_failed`

Each fallback attempt also includes retry logic with exponential backoff.

## Circuit Breaker Pattern

The circuit breaker prevents cascading failures:

**States**:

1. **Closed** (Normal)
   - Requests pass through
   - Failures counted
   - After threshold failures → Open

2. **Open** (Failing)
   - Requests rejected immediately
   - No external calls made
   - After timeout (default 60s) → Half-Open

3. **Half-Open** (Testing)
   - Limited requests allowed
   - Health check performed
   - If succeeds → Closed
   - If fails → Open

**Configuration**:
```elixir
CircuitBreaker.register_provider(
  :ollama,
  fn -> Ollama.ping() end,
  failure_threshold: 5,
  success_threshold: 2,
  timeout_seconds: 60
)
```

## HTTP Status Code Handling

Specific status codes are mapped to retryable errors:

```elixir
200 - Success
401/403 - Auth Error (retryable)
404 - Not Found (not retryable)
408 - Request Timeout (retryable)
429 - Rate Limited (retryable)
500-599 - Server Errors (retryable)
```

## User-Facing Messages

Technical errors are converted to understandable messages:

| Technical Error | User Message |
|---|---|
| `:timeout` | "Request timed out. Please try again." |
| `:rate_limited` | "Rate limited. Please wait a moment and try again." |
| `{:http_error, 404}` | "Job page not found. Please verify the URL." |
| `:invalid_api_key` | "Invalid API key or credentials." |
| `:content_too_large` | "Job posting content is too large. Please try a different page." |
| `:all_providers_failed` | "All LLM providers failed. Please check your configuration and try again." |

## Configuration

### Provider Configuration

**`config/runtime.exs`**:
```elixir
config :req_llm,
  primary_provider: :openai,
  providers: %{
    openai: %{timeout: 30_000, max_retries: 3},
    anthropic: %{timeout: 30_000, max_retries: 3},
    mistral: %{timeout: 30_000, max_retries: 3},
    ollama: %{timeout: 60_000, max_retries: 2}
  },
  fallback_providers: [:anthropic, :mistral, :ollama]
```

### Retry Behavior

- **`max_retries`** - Number of retry attempts per provider (default: 3)
- **`timeout`** - Request timeout in milliseconds
- **`fallback_providers`** - List of providers to try after primary fails

## Logging

Errors are logged at different levels:

```elixir
# Debug level - Retryable errors that will be handled
Logger.debug("Primary provider failed with retryable error: #{inspect(reason)}")

# Warning level - Non-retryable errors or provider-specific issues
Logger.warning("Fallback provider failed: #{inspect(provider)} - #{inspect(reason)}")

# Error level - Complete failure after all providers exhausted
Logger.error("All fallback providers failed")
```

## Testing

Comprehensive test suite in `test/clientats/llm/error_handler_test.exs`:

- Classification of retryable vs permanent errors
- Exponential backoff calculations
- Retry logic with various scenarios
- User-friendly message generation
- Error normalization
- Context metadata creation

Run tests:
```bash
mix test test/clientats/llm/error_handler_test.exs
```

## Future Improvements

1. **Metrics Integration** - Export retry counts and failure rates to monitoring system
2. **Structured Logging** - Use `:logger` with structured metadata
3. **Adaptive Timeouts** - Adjust retry delays based on historical patterns
4. **Provider-Specific Strategies** - Different retry behavior per provider
5. **Manual Override Mode** - When all LLM providers fail, allow manual data entry

## References

- Exponential Backoff: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
- Circuit Breaker Pattern: https://martinfowler.com/bliki/CircuitBreaker.html
- Resilience Engineering: https://www.gremlin.com/blog/chaos-engineering-tools/
