# LLM Library Research for Clientats

## Summary
After evaluating several Elixir LLM libraries, **`req_llm`** is recommended as the primary LLM abstraction library for the job scraping feature.

## Evaluation Criteria
1. **Maturity & Stability** - Production-ready versions
2. **Provider Support** - Multiple LLM providers
3. **Ease of Use** - Clean API and good documentation
4. **Performance** - Efficient HTTP handling
5. **Maintenance** - Active development and support
6. **Licensing** - Permissive open source licenses

## Top Candidates Reviewed

### 1. `req_llm` ✅ **RECOMMENDED**
- **Version**: 1.0.0 (Stable)
- **License**: Apache 2.0
- **GitHub**: https://github.com/agentjido/req_llm
- **Docs**: https://hexdocs.pm/req_llm

**Pros:**
- ✅ Built on modern Req & Finch HTTP clients
- ✅ Unified interface for multiple LLM providers
- ✅ Production-ready (1.0.0 release)
- ✅ Good documentation and examples
- ✅ Active development with regular releases
- ✅ Supports streaming responses
- ✅ Comprehensive error handling

**Cons:**
- ❌ Newer library (first released 2023)

**Supported Providers:**
- OpenAI (GPT-3.5, GPT-4)
- Anthropic (Claude)
- Mistral
- Google (Gemini)
- Azure OpenAI
- Local models via OpenAI-compatible APIs

### 2. `ex_llm`
- **Version**: 0.8.1
- **License**: MIT
- **GitHub**: https://github.com/azmaveth/ex_llm

**Pros:**
- ✅ Mature with good version history
- ✅ Simple unified interface
- ✅ Good community adoption

**Cons:**
- ❌ Slower release cycle
- ❌ Less comprehensive documentation
- ❌ Built on older HTTP clients

### 3. `nexlm`
- **Version**: 0.1.15
- **License**: MIT
- **GitHub**: https://github.com/LiboShen/nexlm

**Pros:**
- ✅ Simple and lightweight
- ✅ Good for basic use cases

**Cons:**
- ❌ Still in early development (0.1.x)
- ❌ Limited provider support
- ❌ Less comprehensive error handling

## Recommendation: `req_llm`

### Implementation Plan

#### Step 1: Add Dependency
```elixir
# mix.exs
defp deps do
  [
    # ... other deps ...
    {:req_llm, "~> 1.0"}
  ]
end
```

#### Step 2: Configuration
```elixir
# config/runtime.exs
import Config

config :req_llm,
  primary_provider: :openai,
  providers: %{
    openai: %{
      api_key: System.get_env("OPENAI_API_KEY"),
      organization: System.get_env("OPENAI_ORG")
    },
    anthropic: %{
      api_key: System.get_env("ANTHROPIC_API_KEY")
    }
  }
```

#### Step 3: Basic Usage Example
```elixir
# Job scraping service
defmodule Clientats.LLM.JobScraper do
  use ReqLLM

  def extract_job_data(url, content) do
    prompt = """
    Extract the following job posting information from this content:
    - Company Name
    - Position Title  
    - Job Description
    - Location
    - Work Model (remote, hybrid, on-site)
    - Salary Range (min and max)
    - Required Skills (list)
    - Posting Date
    
    Return only JSON with the extracted data.
    
    Content: #{content}
    """
    
    ReqLLM.chat(
      model: "gpt-4-turbo",
      messages: [
        %{
          role: "system",
          content: "You are a job posting analysis expert. Extract structured data from job postings."
        },
        %{
          role: "user", 
          content: prompt
        }
      ],
      response_format: %{type: "json_object"}
    )
  end
end
```

#### Step 4: Error Handling
```elixir
def scrape_job_with_fallback(url) do
  case fetch_and_extract(url) do
    {:ok, data} -> {:ok, data}
    {:error, :rate_limited} -> retry_with_fallback_provider(url)
    {:error, :invalid_response} -> fallback_to_generic_mode(url)
    {:error, reason} -> {:error, reason}
  end
end

defp retry_with_fallback_provider(url) do
  # Try secondary provider
  ReqLLM.with_provider(:anthropic, fn ->
    extract_job_data(url)
  end)
end

defp fallback_to_generic_mode(url) do
  # Use simpler extraction for unknown formats
  extract_basic_info(url)
end
```

## Alternative Considerations

### Local LLM Support
For privacy-sensitive deployments, consider:
- **Ollama** integration for local models
- **LM Studio** compatibility
- Self-hosted OpenAI-compatible APIs

### Cost Optimization
- Implement caching for frequent job board scrapes
- Use smaller models for simple extractions
- Batch requests when possible
- Monitor token usage and costs

## Migration Path
If needed, `req_llm` can be easily replaced since it provides a clean abstraction layer. The service interface remains the same regardless of the underlying LLM library.

## Next Steps
1. ✅ Complete library research and selection
2. 🔄 Add `req_llm` dependency to project
3. 🔄 Set up configuration and API keys
4. 🔄 Implement basic scraping service
5. 🔄 Add error handling and fallbacks
6. 🔄 Integrate with job interest creation flow

## References
- [req_llm Documentation](https://hexdocs.pm/req_llm)
- [req_llm GitHub](https://github.com/agentjido/req_llm)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Anthropic API Reference](https://docs.anthropic.com/claude/docs)
