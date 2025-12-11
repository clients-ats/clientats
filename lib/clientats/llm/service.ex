defmodule Clientats.LLM.Service do
  @moduledoc """
  LLM Service for job scraping and text analysis.
  
  Provides a unified interface for interacting with various LLM providers
  with built-in error handling, fallback mechanisms, and token management.
  """
  
  use ReqLLM
  
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
  def extract_job_data(content, url, mode \ :generic, provider \ nil, options \ []) do
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
  def extract_job_data_from_url(url, mode \ :generic, options \ []) do
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
    case URI.parse(url) do
      {:ok, %URI{scheme: "http" or "https"}} -> {:ok, url}
      _ -> {:error, :invalid_url}
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
        
        # Call LLM with provider
        try do
          result = 
            ReqLLM.chat(
              provider: provider,
              model: get_model_for_provider(provider),
              messages: [
                %{
                  role: "system",
                  content: PromptTemplates.system_prompt()
                },
                %{
                  role: "user",
                  content: prompt
                }
              ],
              response_format: %{type: "json_object"},
              temperature: options[:temperature] || 0.1,
              max_tokens: options[:max_tokens] || 4096
            )
          
          # Parse and validate response
          case parse_llm_response(result) do
            {:ok, parsed} ->
              # Cache successful result
              Cache.put(url, parsed)
              {:ok, parsed}
            {:error, reason} -> {:error, reason}
          end
        rescue
          e ->
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
  
  defp get_model_for_provider(provider) do
    providers = Application.get_env(:req_llm, :providers, %{})
    case providers[provider] do
      %{default_model: model} -> model
      _ -> case provider do
        :openai -> "gpt-4o"
        :anthropic -> "claude-3-opus-20240229"
        :mistral -> "mistral-large-latest"
        _ -> "gpt-4o"
      end
    end
  end
  
  defp parse_llm_response(%{choices: [%{message: %{content: content}}]}) do
    try do
      # Parse JSON response
      parsed = Jason.decode!(content)
      
      # Validate required fields
      required_fields = ["company_name", "position_title", "job_description"]
      
      if Enum.all?(required_fields, &Map.has_key?(parsed, &1)) do
        # Transform to our standard format
        result = %{
          company_name: parsed["company_name"],
          position_title: parsed["position_title"],
          job_description: parsed["job_description"],
          location: parsed["location"] || "",
          work_model: parsed["work_model"] || "remote",
          salary: parse_salary(parsed),
          skills: parse_skills(parsed),
          metadata: %{
            posting_date: parsed["posting_date"] || nil,
            application_deadline: parsed["application_deadline"] || nil,
            employment_type: parsed["employment_type"] || "full_time",
            seniority_level: parsed["seniority_level"] || nil
          }
        }
        {:ok, result}
      else
        {:error, :missing_required_fields}
      end
    rescue
      e -> {:error, {:parse_error, Exception.message(e)}}
    end
  end
  
  defp parse_salary(parsed) do
    cond do
      parsed["salary_min"] && parsed["salary_max"] ->
        %{
          min: parsed["salary_min"],
          max: parsed["salary_max"],
          currency: parsed["currency"] || "USD",
          period: parsed["salary_period"] || "yearly"
        }
      parsed["salary_min"] ->
        %{
          min: parsed["salary_min"],
          currency: parsed["currency"] || "USD",
          period: parsed["salary_period"] || "yearly"
        }
      parsed["salary_max"] ->
        %{
          max: parsed["salary_max"],
          currency: parsed["currency"] || "USD",
          period: parsed["salary_period"] || "yearly"
        }
      true -> nil
    end
  end
  
  defp parse_skills(parsed) do
    case parsed["skills"] do
      nil -> []
      skills when is_list(skills) -> skills
      skills when is_binary(skills) -> String.split(skills, ",")
      _ -> []
    end
  end
  
  defp fetch_url_content(url) do
    # In production, this would use HTTPoison, Req, or Finch
    # For now, we'll implement a basic version
    try do
      case Req.get(url, timeout: 10_000) do
        %{status: 200, body: body} -> {:ok, body}
        %{status: status} -> {:error, {:http_error, status}}
      end
    rescue
      e -> {:error, {:fetch_error, Exception.message(e)}}
    end
  end
end