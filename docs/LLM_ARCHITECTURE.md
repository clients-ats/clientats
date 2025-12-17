# LLM Service Architecture

**Document Version**: 1.0
**Last Updated**: December 15, 2024
**Status**: Production Ready

## Table of Contents

1. [Overview](#overview)
2. [System Design](#system-design)
3. [Core Modules](#core-modules)
4. [Data Flow](#data-flow)
5. [Provider Integration](#provider-integration)
6. [Error Handling & Resilience](#error-handling--resilience)
7. [Caching Strategy](#caching-strategy)
8. [Security Considerations](#security-considerations)
9. [Performance Optimization](#performance-optimization)
10. [API Reference](#api-reference)

---

## Overview

The LLM (Large Language Model) service is the core component of Clientats that enables intelligent extraction of job posting data from URLs. The system uses multiple LLM providers with automatic fallback and resilience patterns to ensure reliable extraction even when individual providers fail.

### Key Responsibilities

- **URL-based Extraction**: Fetch content from URLs and extract structured job data
- **Multi-Provider Support**: Fallback between providers (Gemini, Ollama, OpenAI, Anthropic, Mistral)
- **Result Caching**: Avoid redundant API calls for identical URLs
- **Error Resilience**: Automatic retry with exponential backoff and circuit breaker pattern
- **Screenshot Analysis**: Use browser screenshots for accurate visual information capture
- **Structured Output**: Convert extraction results into standardized job data format

### Design Principles

- **Separation of Concerns**: Each module has a single, well-defined responsibility
- **Resilience First**: Assume providers can fail; implement automatic recovery
- **Performance Aware**: Cache results aggressively; minimize API calls
- **Security-Focused**: Validate all inputs; prevent injection attacks
- **Observable**: Comprehensive logging for debugging and monitoring

---

## System Design

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Request                              │
│            (URL + Extraction Mode)                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │  Input Validation Layer  │
        │  (URL/Content Validation)│
        └──────────────┬───────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │    Cache Lookup          │
        │  (Result Already Cached?)│
        └──────────────┬───────────┘
                   Yes │ → Return Cached Result
                       │ No
                       ▼
        ┌──────────────────────────┐
        │  Screenshot Extraction   │
        │  (Browser Capture)       │
        └──────────────┬───────────┘
                       │ (Screenshot or HTML Fallback)
                       ▼
        ┌──────────────────────────────────────────┐
        │  Provider Selection & Error Handling     │
        │                                          │
        │  ┌─ Try Primary Provider                │
        │  │  └─ Circuit Breaker Check            │
        │  │     └─ Health Status Check           │
        │  │                                      │
        │  ├─ If Fails (Retryable) → Retry Loop  │
        │  │  └─ Exponential Backoff              │
        │  │                                      │
        │  └─ If Fails → Try Fallback Providers  │
        │     └─ Repeat for each fallback        │
        └──────────────┬───────────────────────────┘
                       │
                ┌──────┴──────┐
                ▼             ▼
         ┌────────────┐  ┌─────────────┐
         │   Success  │  │    Failure  │
         │ Store in   │  │  Return     │
         │   Cache    │  │  Error      │
         └────────────┘  └─────────────┘
                       │
                       ▼
         ┌──────────────────────────┐
         │  Structured Job Data     │
         │  (or Error Response)     │
         └──────────────────────────┘
```

### Module Dependency Graph

```
┌─────────────────────────────────────────────────────┐
│ Service (Main Entry Point)                          │
│  - extract_job_data/5                              │
│  - extract_job_data_from_url/3                     │
│  - get_available_providers/0                       │
│  - get_config/0                                    │
└──────────────┬──────────────────────────────────────┘
               │
        ┌──────┴──────┬─────────────┬──────────────┐
        ▼             ▼             ▼              ▼
    ┌────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐
    │ Cache  │  │ErrorHandler│ │Browser  │  │PromptTemplates
    │        │  │          │  │         │  │              │
    └────────┘  └──────────┘  └─────────┘  └──────────────┘
                     │
                     ├─────────────────┐
                     ▼                 ▼
              ┌────────────────┐ ┌──────────────┐
              │CircuitBreaker  │ │Providers/    │
              │(Fault Tolerance│ │Integration   │
              └────────────────┘ └──────────────┘
```

---

## Core Modules

### 1. **Service** (lib/clientats/llm/service.ex - 30KB+)

**Purpose**: Main extraction engine orchestrating all LLM operations

**Key Functions**:

```elixir
# Main extraction from content
extract_job_data(content, url, mode, provider \\ nil, options \\ [])
  Returns: {:ok, job_data} | {:error, reason}

# Main extraction from URL (preferred)
extract_job_data_from_url(url, mode \\ :generic, options \\ [])
  Returns: {:ok, job_data} | {:error, reason}

# Provider and config info
get_available_providers()
get_config()
```

**Responsibilities**:
- Validate inputs (URLs, content length)
- Attempt screenshot-based extraction (multimodal)
- Fall back to HTML extraction if screenshots fail
- Orchestrate provider selection and retry logic
- Cache successful results
- Map errors to user-friendly messages

**Key Design Decisions**:
- Tries screenshot first (better for complex layouts)
- Falls back to HTML for speed
- Caches all successful extractions
- Uses ErrorHandler for retry decisions
- Supports both "generic" and "specific" extraction modes

### 2. **ErrorHandler** (lib/clientats/llm/error_handler.ex)

**Purpose**: Centralized error classification and handling

**Key Functions**:

```elixir
retryable?(error)
  # Returns: true if error is transient, false if permanent

calculate_backoff(attempt, base_delay \\ 100)
  # Returns: milliseconds to wait (with exponential backoff + jitter)

with_retry(fun, max_retries: 3, base_delay: 100, retryable: default)
  # Returns: {:ok, result} | {:error, reason}

user_friendly_message(error)
  # Returns: Human-readable error message

normalize_error(error)
  # Returns: {error_type, message}

error_context(error, metadata)
  # Returns: %{error, retryable, user_message, context...}
```

**Error Classification**:

**Retryable Errors** (transient failures):
- `:timeout` / `{:timeout, detail}`
- `:rate_limited` / `{:rate_limited, detail}`
- `{:http_error, 5xx}` (server errors)
- `{:http_error, 408}` (request timeout)
- `{:http_error, 429}` (rate limit)
- `:connection_refused`, `:unavailable`

**Permanent Errors** (won't succeed on retry):
- `:invalid_content` (bad input)
- `:content_too_large` (exceeds limits)
- `:invalid_url` (malformed URL)
- `:invalid_api_key` (wrong credentials)
- `:invalid_response_format` (parsing issue)
- `{:http_error, 4xx}` except 408/429

**Backoff Strategy**:
- Formula: `base_delay * (2 ^ attempt) + random_jitter`
- Example: 100ms, 200ms, 400ms, 800ms...
- Jitter: ±10% of delay to prevent thundering herd

### 3. **CircuitBreaker** (lib/clientats/llm/circuit_breaker.ex)

**Purpose**: Prevent cascading failures via circuit breaker pattern

**States**:
- **Closed** (Normal): Requests pass through; failures tracked
- **Open** (Failing): Requests rejected immediately; no provider calls
- **Half-Open** (Testing): Limited requests allowed; health check performed

**Key Functions**:

```elixir
register_provider(provider, health_check_fn, opts)
available?(provider)
record_success(provider)
record_failure(provider)
health_status()
```

**Configuration**:
- `failure_threshold`: Failures before opening (default: 5)
- `success_threshold`: Successes before closing (default: 2)
- `timeout_seconds`: Time before trying recovery (default: 60)

**Benefits**:
- Fails fast when provider is down
- Prevents wasted API calls
- Allows provider recovery time
- Reduces cascading failures to users

### 4. **Cache** (lib/clientats/llm/cache.ex)

**Purpose**: Store and retrieve extraction results to avoid duplicate work

**Key Functions**:

```elixir
put(url, result)       # Store extraction result
get(url)               # Retrieve cached result
delete(url)            # Remove specific entry
clear()                # Clear all cache
```

**Cache Key**: URL (full, including query parameters)

**Cache Value**: Extracted job data structure

**Strategy**:
- In-memory ETS table for performance
- Per-user scoping (if implemented)
- No expiration (manual clearing)
- Suitable for development; consider Redis for multi-instance production

### 5. **PromptTemplates** (lib/clientats/llm/prompt_templates.ex)

**Purpose**: Generate optimized extraction prompts for different job boards

**Key Functions**:

```elixir
system_prompt()
  # System instructions for LLM

build_job_extraction_prompt(content, url, mode)
  # mode: :generic or :specific
  # Returns: Formatted extraction prompt
```

**Prompt Optimization**:
- **Specific Mode**: Tailored prompts for known job boards
- **Generic Mode**: Fallback for unknown sources
- **Board Detection**: Recognizes LinkedIn, Indeed, Glassdoor, etc.
- **Structured Output**: Requests JSON format with specific fields

**Extracted Fields**:
```json
{
  "company_name": "string",
  "position_title": "string",
  "job_description": "string",
  "location": "string",
  "work_model": "remote|hybrid|on_site",
  "salary_min": "integer",
  "salary_max": "integer",
  "job_url": "string"
}
```

### 6. **Setting** (lib/clientats/llm/setting.ex)

**Purpose**: Store and manage per-user LLM provider configurations

**Database Schema**:
```elixir
schema "llm_settings" do
  field :user_id        # FK to users
  field :provider       # Atom: :openai, :gemini, etc.
  field :api_key        # Encrypted storage
  field :base_url       # Custom endpoint (for Ollama)
  field :default_model  # Model for text extraction
  field :vision_model   # Model for screenshot analysis
  field :enabled        # Boolean
  timestamps()
end
```

**Features**:
- Per-user provider configuration
- Multiple providers per user
- Model customization
- API key encryption (if implemented)
- Connection testing support

---

## Data Flow

### Complete Extraction Flow

```
1. USER INITIATES REQUEST
   Input: URL (e.g., https://linkedin.com/jobs/view/123)
   Mode: :generic or :specific

2. INPUT VALIDATION
   ✓ URL format validation (HTTP/HTTPS scheme)
   ✓ Content length checks
   ✓ SQL injection prevention in params

3. CACHE CHECK
   → Cache HIT: Return cached result (fast path)
   → Cache MISS: Continue to extraction

4. CONTENT FETCH
   Option A: Browser Screenshot (preferred)
     ✓ Capture visual rendering
     ✓ Better for complex layouts
     ✗ Slower, more resource-intensive

   Option B: HTML Fallback (if screenshot fails)
     ✓ Faster, fewer resources
     ✗ Misses visual styling info

5. PROVIDER SELECTION
   a. Get user's provider configuration
   b. Use primary or specified provider
   c. Check circuit breaker status
   d. Proceed or skip if circuit open

6. LLM EXTRACTION
   a. Build optimized prompt (using PromptTemplates)
   b. Call selected provider
   c. Parse response
   d. Validate output format

7. ERROR HANDLING & RETRY
   If error:
     a. ErrorHandler.retryable?(error)?
     b. If YES:
        - Calculate backoff delay
        - Retry up to max_retries times
        - Exponential backoff between attempts
     c. If NO:
        - Return error immediately
        - Don't try other providers

8. FALLBACK PROVIDERS
   If all retries fail:
     a. Try next fallback provider (if configured)
     b. Reset retry counter for new provider
     c. Repeat steps 5-7

   If all providers fail:
     - Return :all_providers_failed error

9. SUCCESS PATH
   a. Validate extracted data
   b. Normalize to standard format
   c. Store in cache
   d. Return to user

10. RESPONSE TO USER
    Input extracted as structured job data with all fields
```

### Example: Extract Job from LinkedIn

```elixir
# User calls:
{:ok, job_data} = Clientats.LLM.Service.extract_job_data_from_url(
  "https://www.linkedin.com/jobs/view/123456",
  :specific
)

# Internal flow:
1. Input validation: ✓ Valid HTTPS URL
2. Cache lookup: ✗ Not found
3. Screenshot capture: ✓ Success
4. Provider selection:
   - Primary: OpenAI (configured)
   - Circuit breaker: closed (available)
5. Prompt building:
   - Detects LinkedIn URL
   - Uses specific mode prompt
   - Includes visual screenshot content
6. LLM call: OpenAI API → Success
7. Response parsing: ✓ Valid JSON
8. Cache storage: ✓ Stored
9. Return: {:ok, %{company: "...", position: "...", ...}}
```

### Example: Fallback Chain

```elixir
# Primary provider fails:
1. Try OpenAI: ✗ Rate limited (retryable)
2. Retry OpenAI: ✗ Still rate limited
3. Retry OpenAI: ✗ Rate limited (exhaust retries)
4. Try Anthropic: ✗ Timeout
5. Retry Anthropic: ✗ Timeout again
6. Try Mistral: ✗ 500 error
7. Retry Mistral: ✗ Still 500
8. Try Ollama: ✓ Success!
9. Return result and cache
```

---

## Provider Integration

### Supported Providers

| Provider | Type | Vision | Cost | Speed | Status |
|----------|------|--------|------|-------|--------|
| **Gemini** | Cloud | ✓ Yes | Free* | Fast | Supported |
| **OpenAI** | Cloud | ✓ Yes | Paid | Fast | Supported |
| **Anthropic** | Cloud | ✓ Yes | Paid | Medium | Supported |
| **Mistral** | Cloud | ✗ No | Paid | Fast | Supported |
| **Ollama** | Local | ✗ No | Free | Variable | Supported |

*Gemini has free tier with rate limits

### Provider Interface (via req_llm)

```elixir
# Generic provider call pattern
ReqLLM.chat_completion(
  model: "model-name",
  messages: [
    %{"role" => "system", "content" => system_prompt},
    %{"role" => "user", "content" => user_prompt}
  ],
  temperature: 0.3  # Lower = more deterministic
)

# Vision support (image extraction)
ReqLLM.chat_completion(
  model: "vision-capable-model",
  messages: [
    %{"role" => "user", "content" => [
      %{"type" => "text", "text" => prompt},
      %{"type" => "image_url", "image_url" => %{"url" => "data:image/png;base64,..."}}
    ]}
  ]
)
```

### Adding a New Provider

1. **Update Configuration** (config/runtime.exs):
   ```elixir
   config :req_llm,
     providers: %{
       new_provider: %{
         api_key: System.get_env("NEW_PROVIDER_API_KEY"),
         base_url: "https://api.newprovider.com"  # if needed
       }
     }
   ```

2. **Update Provider List** (PromptTemplates):
   ```elixir
   def get_available_providers do
     [
       %{name: "New Provider", description: "...", model: "..."},
       # ...
     ]
   end
   ```

3. **Add Settings** (allow users to configure):
   - API key field
   - Model selection
   - Connection testing

4. **Test Integration**:
   ```elixir
   iex> Service.extract_job_data(content, url, :generic, :new_provider)
   ```

---

## Error Handling & Resilience

### Retry Strategy

The system implements **adaptive retry with exponential backoff**:

```
Attempt 0: Immediate
Attempt 1: ~100ms + jitter
Attempt 2: ~200ms + jitter
Attempt 3: ~400ms + jitter
Attempt 4: ~800ms + jitter
(Max 3 retries by default)
```

### Circuit Breaker Logic

```
CLOSED (Normal) ─┬─ Failure ─→ Count failures
                 │             If count ≥ threshold
                 │             ↓
                 │          OPEN
                 │
SUCCESS ─────────┘

OPEN (Failing) ──┐─ Reject all requests
                 │  If timeout_seconds passed
                 │  ↓
                 │ HALF_OPEN
                 │
                 │ Try one request
                 │ Success? → CLOSED
                 │ Failure? → OPEN again

HALF_OPEN ───────┘
```

### Error Messages to Users

| Technical Error | User Message |
|---|---|
| `:timeout` | "Request timed out. Please try again." |
| `:rate_limited` | "Rate limited. Please wait a moment and try again." |
| `:invalid_api_key` | "Invalid API key or credentials." |
| `:content_too_large` | "Job posting content is too large. Please try a different page." |
| `:invalid_url` | "Job page not found. Please verify the URL." |
| `:all_providers_failed` | "All LLM providers failed. Please check your configuration and try again." |

---

## Caching Strategy

### Current Implementation (ETS)

```
Cache Structure:
┌─────────────────────────────────┐
│ URL → Extracted Job Data         │
├─────────────────────────────────┤
│ "https://linkedin.com/..." →    │
│   %{                            │
│     company: "Acme Corp",       │
│     position: "Engineer",       │
│     ...                         │
│   }                             │
└─────────────────────────────────┘
```

**Advantages**:
- Fast in-process lookup
- No external dependencies
- No network latency

**Limitations**:
- Single-server only (not shared across instances)
- Lost on application restart
- No expiration (manual clearing required)

### Production Recommendations

For multi-instance deployments, consider:

1. **Redis Cache**:
   ```elixir
   defp cache_key(url), do: "job:#{url}"
   # TTL: 30 days for most jobs
   # Key: Full URL (deterministic)
   ```

2. **Database Cache** (with timestamps):
   ```sql
   CREATE TABLE llm_cache (
     url TEXT PRIMARY KEY,
     result JSON,
     created_at TIMESTAMP,
     expires_at TIMESTAMP,
     provider TEXT
   );
   ```

3. **Hybrid Approach**:
   - L1: ETS (fast, local)
   - L2: Redis (shared, cluster-aware)
   - L3: Database (persistent)

---

## Security Considerations

### Input Security

1. **URL Validation**:
   - Must be HTTP/HTTPS scheme only
   - Valid URL structure validation
   - No JavaScript/data schemes

2. **Content Sanitization**:
   - Escape HTML entities
   - Remove script tags
   - Remove event handlers
   - Strip null bytes

3. **API Key Protection**:
   - Store encrypted in database
   - Never log full keys
   - Use environment variables in production
   - Rotate keys regularly

### Output Security

1. **Response Validation**:
   - Validate JSON structure
   - Type check extracted fields
   - Sanitize text content from LLM
   - Limit field lengths

2. **Rate Limiting**:
   - Implement per-user rate limits
   - Prevent abuse of extraction endpoint
   - Consider quota system

3. **Logging**:
   - Never log API keys
   - Log URLs for debugging
   - Be careful with content logging

---

## Performance Optimization

### Optimization Techniques

1. **Caching**:
   - Cache all successful extractions
   - Key: Full URL
   - No expiration (manual invalidation)

2. **Provider Selection**:
   - Choose provider by speed vs. quality trade-off
   - Ollama: Fastest (local)
   - Gemini: Good balance (free tier)
   - OpenAI: Highest quality (paid)

3. **Content Handling**:
   - Prefer HTML over screenshots when possible
   - Limit screenshot resolution
   - Set request timeouts

4. **Batch Operations**:
   - Process multiple URLs sequentially
   - Not in parallel (rate limiting concerns)
   - Show progress to user

### Performance Metrics to Track

```
- Extraction time by provider
- Cache hit rate
- Error rate by provider
- Retry frequency
- Circuit breaker state transitions
- Average tokens used per extraction
```

---

## API Reference

### Main Functions

#### Service.extract_job_data/5

```elixir
extract_job_data(content, url, mode, provider \\ nil, options \\ [])

# Arguments:
#   content  - HTML or text content to extract from
#   url      - Source URL (for context)
#   mode     - :generic or :specific
#   provider - Atom (override user's default)
#   options  - Keyword list [user_id: ..., ...]

# Returns:
#   {:ok, %{company_name, position_title, ...}}
#   {:error, :invalid_content}
#   {:error, :invalid_url}
#   {:error, :all_providers_failed}
```

#### Service.extract_job_data_from_url/3

```elixir
extract_job_data_from_url(url, mode \\ :generic, options \\ [])

# Arguments:
#   url      - Full URL to job posting
#   mode     - :generic or :specific
#   options  - Keyword list

# Returns:
#   Same as extract_job_data/5
#   Handles URL fetching and screenshot internally
```

#### ErrorHandler.with_retry/2

```elixir
with_retry(fun, max_retries: 3, base_delay: 100, retryable: default)

# Arguments:
#   fun      - 0-arity function returning {:ok, result} | {:error, reason}
#   options  - Keyword list with retry configuration

# Returns:
#   {:ok, result} on success
#   {:error, reason} if exhausted retries
```

#### Cache Functions

```elixir
Clientats.LLM.Cache.put(url, result)  # Store result
Clientats.LLM.Cache.get(url)         # Retrieve result
Clientats.LLM.Cache.delete(url)      # Remove entry
Clientats.LLM.Cache.clear()          # Clear all cache
```

---

## Troubleshooting

### Common Issues

**"All LLM providers failed"**
- Check provider API keys in database
- Verify internet connectivity
- Check provider status pages
- Review provider-specific error logs

**"Rate limited" recurring errors**
- Increase delay between requests
- Check rate limit quotas
- Consider switching to different provider
- Implement request queuing

**Slow extractions**
- Check screenshot capture time
- Consider disabling vision mode temporarily
- Use faster provider (Ollama locally)
- Check network connectivity

**Inconsistent results**
- Try increasing model temperature (more creative)
- Improving prompt templates
- Using specific mode for known boards
- Manual review of problematic URLs

---

## Future Enhancements

1. **Streaming Responses**: Handle large extractions incrementally
2. **Fine-tuned Models**: Train on job posting samples
3. **Multi-language Support**: Handle non-English job boards
4. **Image Processing**: Extract logos, company images
5. **Real-time Updates**: Monitor for job posting changes
6. **Cost Optimization**: Auto-select cheapest provider
7. **Result Scoring**: Confidence scores for extracted data
8. **User Feedback Loop**: Learn from user corrections

---

## References

- req_llm Documentation: https://hexdocs.pm/req_llm/
- OpenAI API: https://platform.openai.com/docs/
- Google Gemini: https://ai.google.dev/
- Anthropic API: https://docs.anthropic.com/
- Circuit Breaker Pattern: https://martinfowler.com/bliki/CircuitBreaker.html
- Exponential Backoff: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/

