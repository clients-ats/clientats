defmodule Clientats.LLM.Service do
  @moduledoc """
  LLM Service for job scraping and text analysis.
  
  Provides a unified interface for interacting with various LLM providers
  with built-in error handling, fallback mechanisms, and token management.
  """
  
  alias Clientats.LLM.{PromptTemplates, Cache}
  
  @type provider :: :openai | :anthropic | :mistral | atom()
  @type extraction_result :: {
          :ok,
          map() |
          %{
            company_name: String.t(),
            position_title: String.t(),
            job_description: String.t(),
            location: String.t(),
            work_model: String.t(),
            salary: map() | nil,
            skills: list(String.t()),
            metadata: map()
          }
        } |
        {:error, atom() | String.t()}
  
  @doc """
  Extract job data from URL content using LLM.
  
  ## Parameters
    - content: Raw HTML or text content from job posting
    - url: Original URL for context and source detection
    - mode: :specific (for known job boards) or :generic (for any content)
    - provider: Specific LLM provider to use (optional)
    - options: Additional options like temperature, max_tokens, etc.
  
  ## Returns
    - {:ok, extracted_data} on success
    - {:error, reason} on failure
  """
  def extract_job_data(content, url, mode \\ :generic, provider \\ nil, options \\ []) do
    # Validate input
    with {:ok, content} <- validate_content(content),
         {:ok, url} <- validate_url(url),
         {:ok, provider} <- determine_provider(provider) do
      
      # Try to extract with primary provider first
      case attempt_extraction(content, url, mode, provider, options) do
        {:ok, result} -> {:ok, result}
        {:error, :rate_limited} -> retry_with_fallback(content, url, mode, options)
        {:error, :auth_error} -> retry_with_fallback(content, url, mode, options)
        {:error, :timeout} -> retry_with_fallback(content, url, mode, options)
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, _} = error -> error
    end
  end
  
  @doc """
  Extract job data from URL by fetching content first.
  
  ## Parameters
    - url: URL of the job posting
    - mode: :specific or :generic extraction mode
    - options: Additional options for content fetching and LLM processing
  """
  def extract_job_data_from_url(url, mode \\ :generic, options \\ []) do
    with {:ok, content} <- fetch_url_content(url),
         {:ok, extracted} <- extract_job_data(content, url, mode, nil, options) do
      {:ok, Map.put(extracted, :source_url, url)}
    else
      {:error, _} = error -> error
    end
  end
  
  @doc """
  Get available LLM providers and their status.
  """
  def get_available_providers do
    providers = Application.get_env(:req_llm, :providers) || %{}
    
    Enum.map(providers, fn {name, config} ->
      %{name: name, available: Map.has_key?(config, :api_key) && !is_nil(config[:api_key])}
    end)
  end
  
  @doc """
  Get current LLM configuration.
  """
  def get_config do
    Application.get_env(:req_llm, :providers) || %{}
  end
  
  # Private functions
  
  defp validate_content(content) when is_binary(content) and byte_size(content) > 0 do
    if byte_size(content) > Application.get_env(:req_llm, :max_content_length, 10_000) do
      {:error, :content_too_large}
    else
      {:ok, content}
    end
  end
  defp validate_content(_), do: {:error, :invalid_content}
  
  defp validate_url(url) when is_binary(url) do
    uri = URI.parse(url)
    if uri.scheme in ["http", "https"] do
      {:ok, url}
    else
      {:error, :invalid_url}
    end
  end
  defp validate_url(_), do: {:error, :invalid_url}
  
  defp determine_provider(nil) do
    primary = Application.get_env(:req_llm, :primary_provider, :openai)
    {:ok, primary}
  end
  defp determine_provider(provider) when is_atom(provider) do
    {:ok, provider}
  end
  defp determine_provider(_), do: {:error, :invalid_provider}
  
  defp attempt_extraction(content, url, mode, provider, options) do
    # Check cache first
    case Cache.get(url) do
      {:ok, cached} -> {:ok, cached}
      :not_found ->
        # Build prompt based on mode
        prompt = PromptTemplates.build_job_extraction_prompt(content, url, mode)
        
        IO.puts("[DEBUG] Attempting extraction with provider: #{inspect(provider)}")
        IO.puts("[DEBUG] Using model: #{get_model_for_provider(provider)}")
        
        # Call LLM with provider
        try do
          result =
            case provider do
              :ollama ->
                # Use direct Ollama client
                IO.puts("[DEBUG] Calling Ollama with prompt length: #{byte_size(prompt)}")
                call_ollama(prompt, options)

              _ ->
                # Use req_llm for other providers
                IO.puts("[DEBUG] Calling #{provider} via ReqLLM")
                # TODO: Implement proper ReqLLM integration
                # For now, return an error for non-Ollama providers until ReqLLM is properly integrated
                {:error, {:llm_error, "ReqLLM provider #{provider} not yet fully integrated"}}
            end
          
          IO.puts("[DEBUG] Received LLM result: #{inspect(result)}")
          
          # Parse and validate response
          case parse_llm_response(result) do
            {:ok, parsed} ->
              # Cache successful result
              Cache.put(url, parsed)
              {:ok, parsed}
            {:error, reason} ->
              IO.puts("[ERROR] Failed to parse LLM response: #{inspect(reason)}")
              {:error, reason}
          end
        rescue
          e ->
            IO.puts("[ERROR] Exception in LLM extraction: #{Exception.message(e)}")
            IO.puts("[ERROR] Stacktrace: #{inspect(__STACKTRACE__)}")
            {:error, {:llm_error, Exception.message(e)}}
        end
    end
  end
  
  defp retry_with_fallback(content, url, mode, options) do
    fallback_providers = Application.get_env(:req_llm, :fallback_providers, [])
    
    # Try each fallback provider
    case try_fallbacks(fallback_providers, content, url, mode, options, []) do
      {:ok, result} -> {:ok, result}
      [] -> {:error, :all_providers_failed}
    end
  end
  
  defp try_fallbacks([provider | rest], content, url, mode, options, tried) do
    case attempt_extraction(content, url, mode, provider, options) do
      {:ok, result} -> {:ok, result}
      {:error, _reason} -> try_fallbacks(rest, content, url, mode, options, [provider | tried])
    end
  end
  defp try_fallbacks([], _content, _url, _mode, _options, _tried), do: :error
  
  defp call_ollama(prompt, options) do
    # Get Ollama configuration
    providers = Application.get_env(:req_llm, :providers, %{})
    ollama_config = providers[:ollama] || %{}

    model = ollama_config[:default_model] || "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL"
    base_url = ollama_config[:base_url] || "http://localhost:11434"
    
    # Build Ollama options
    ollama_options = [
      temperature: options[:temperature] || 0.1,
      top_p: options[:top_p] || 0.9,
      num_predict: options[:max_tokens] || 4096
    ]
    
    # Call Ollama provider
    Clientats.LLM.Providers.Ollama.generate(model, prompt, ollama_options, base_url)
  end
  
  defp get_model_for_provider(provider) do
    providers = Application.get_env(:req_llm, :providers, %{})
    case providers[provider] do
      %{default_model: model} -> model
      _ ->
        case provider do
          :openai -> "gpt-4o"
          :anthropic -> "claude-3-opus-20240229"
          :mistral -> "mistral-large-latest"
          :ollama -> "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL"
          _ -> "gpt-4o"
        end
    end
  end
  
  # Handle Ollama response format (string or atom keys)
  defp parse_llm_response(%{"response" => response}) when is_binary(response) do
    try do
      # Extract JSON from response (Ollama might include extra text)
      json_string = extract_json_from_text(response)
      parsed = Jason.decode!(json_string)

      extract_job_fields(parsed)
    rescue
      e -> {:error, {:parse_error, Exception.message(e)}}
    end
  end

  # Handle Ollama response format with atom keys
  defp parse_llm_response(%{response: response}) when is_binary(response) do
    try do
      # Extract JSON from response (Ollama might include extra text)
      json_string = extract_json_from_text(response)
      parsed = Jason.decode!(json_string)

      extract_job_fields(parsed)
    rescue
      e -> {:error, {:parse_error, Exception.message(e)}}
    end
  end

  # Handle OpenAI-style response format (atom keys)
  defp parse_llm_response(%{choices: [%{message: %{content: content}}]}) when is_binary(content) do
    try do
      parsed = Jason.decode!(content)
      extract_job_fields(parsed)
    rescue
      e -> {:error, {:parse_error, Exception.message(e)}}
    end
  end

  # Handle OpenAI-style response format (string keys)
  defp parse_llm_response(%{"choices" => [%{"message" => %{"content" => content}}]}) when is_binary(content) do
    try do
      parsed = Jason.decode!(content)
      extract_job_fields(parsed)
    rescue
      e -> {:error, {:parse_error, Exception.message(e)}}
    end
  end

  defp parse_llm_response(_), do: {:error, :invalid_response_format}

  # Helper function to extract job fields from parsed JSON
  defp extract_job_fields(parsed) when is_map(parsed) do
    # Get values, handling both string and atom keys
    company_name = parsed["company_name"] || parsed[:company_name] || ""
    position_title = parsed["position_title"] || parsed[:position_title] || ""
    job_description = parsed["job_description"] || parsed[:job_description] || ""

    # Validate required fields
    required_fields = [company_name, position_title, job_description]

    if Enum.all?(required_fields, &(is_binary(&1) && String.trim(&1) != "")) do
      # Transform to our standard format
      result = %{
        company_name: company_name,
        position_title: position_title,
        job_description: job_description,
        location: parsed["location"] || parsed[:location] || "",
        work_model: parsed["work_model"] || parsed[:work_model] || "remote",
        salary: parse_salary(parsed),
        skills: parse_skills(parsed),
        metadata: %{
          posting_date: parsed["posting_date"] || parsed[:posting_date] || nil,
          application_deadline: parsed["application_deadline"] || parsed[:application_deadline] || nil,
          employment_type: parsed["employment_type"] || parsed[:employment_type] || "full_time",
          seniority_level: parsed["seniority_level"] || parsed[:seniority_level] || nil
        }
      }
      {:ok, result}
    else
      {:error, :missing_required_fields}
    end
  end
  defp extract_job_fields(_), do: {:error, :invalid_response_format}
  
  defp parse_salary(parsed) do
    salary_min = parsed["salary_min"] || parsed[:salary_min]
    salary_max = parsed["salary_max"] || parsed[:salary_max]
    currency = parsed["currency"] || parsed[:currency] || "USD"
    salary_period = parsed["salary_period"] || parsed[:salary_period] || "yearly"

    cond do
      salary_min && salary_max ->
        %{
          min: salary_min,
          max: salary_max,
          currency: currency,
          period: salary_period
        }
      salary_min ->
        %{
          min: salary_min,
          currency: currency,
          period: salary_period
        }
      salary_max ->
        %{
          max: salary_max,
          currency: currency,
          period: salary_period
        }
      true -> nil
    end
  end

  defp parse_skills(parsed) do
    skills = parsed["skills"] || parsed[:skills]
    case skills do
      nil -> []
      skills when is_list(skills) -> skills
      skills when is_binary(skills) -> String.split(skills, ",") |> Enum.map(&String.trim/1)
      _ -> []
    end
  end
  
  defp fetch_url_content(url) do
    # Enhanced URL fetching with proper headers and longer timeout
    try do
      case Req.get(url,
           headers: [
             {"User-Agent", "Mozilla/5.0 (compatible; Clientats/1.0; +https://clientats.com)"},
             {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
             {"Accept-Language", "en-US,en;q=0.5"}
           ],
           receive_timeout: 30_000,  # Increased timeout for slower job sites
           follow_redirects: true
          ) do
        %{status: 200, body: body} -> {:ok, body}
        %{status: status} -> {:error, {:http_error, status}}
      end
    rescue
      e -> {:error, {:fetch_error, Exception.message(e)}}
    end
  end

  defp extract_json_from_text(text) do
    # Try to extract JSON from text that might contain extra content
    case Regex.scan(~r/\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}/, text) do
      [[json | _] | _] -> json
      _ -> text  # If no JSON found, try to parse the whole text
    end
  end
end