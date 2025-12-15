defmodule Clientats.LLM.Service do
  @moduledoc """
  LLM Service for job scraping and text analysis.
  
  Provides a unified interface for interacting with various LLM providers
  with built-in error handling, fallback mechanisms, and token management.
  """
  
  alias Clientats.LLM.{PromptTemplates, Cache, ErrorHandler}
  alias Clientats.LLMConfig
  alias Clientats.Browser

  require Logger
  
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
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          if ErrorHandler.retryable?(reason) do
            # Log the error and attempt fallback
            Logger.debug("Primary provider failed with retryable error: #{inspect(reason)}")
            retry_with_fallback(content, url, mode, options)
          else
            # Permanent error, return immediately
            Logger.warning("Permanent extraction error: #{inspect(reason)}")
            {:error, reason}
          end
      end
    else
      {:error, _} = error -> error
    end
  end
  
  @doc """
  Extract job data from URL using browser screenshot + multimodal LLM.

  ## Parameters
    - url: URL of the job posting
    - mode: :specific or :generic extraction mode
    - options: Additional options for browser and LLM processing

  ## Notes
    This function captures a screenshot of the page and uses multimodal
    LLM extraction (vision model) instead of raw HTML. If screenshot fails,
    falls back to HTML fetching for non-vision providers.
  """
  def extract_job_data_from_url(url, mode \\ :generic, options \\ []) do
    # Determine provider
    provider = Keyword.get(options, :provider) || Application.get_env(:req_llm, :primary_provider, :openai)

    # Try to use browser screenshot first (better for multimodal extraction)
    case capture_page_screenshot(url) do
      {:ok, screenshot_path} ->
        IO.puts("[Service] Using screenshot-based extraction")
        extract_with_screenshot(screenshot_path, url, mode, provider, options)

      {:error, reason} ->
        IO.puts("[Service] Screenshot failed (#{inspect(reason)}), falling back to HTML extraction")
        # Fallback to HTML if screenshot unavailable
        with {:ok, content} <- fetch_url_content(url),
             {:ok, extracted} <- extract_job_data(content, url, mode, provider, options) do
          {:ok, Map.put(extracted, :source_url, url)}
        else
          {:error, _} = error -> error
        end
    end
  end

  @doc """
  Extract job data using a screenshot path for multimodal LLM processing.

  ## Parameters
    - screenshot_path: Path to the screenshot PNG file
    - url: Original URL for context
    - mode: :specific or :generic extraction mode
    - provider: LLM provider to use
    - options: Additional options
  """
  def extract_with_screenshot(screenshot_path, url, mode, provider, options) do
    with {:ok, provider} <- determine_provider(provider) do
      case attempt_screenshot_extraction(screenshot_path, url, mode, provider, options) do
        {:ok, result} ->
          {:ok, Map.put(result, :source_url, url)}

        {:error, reason} ->
          if ErrorHandler.retryable?(reason) do
            Logger.debug("Screenshot extraction failed with retryable error: #{inspect(reason)}")
            retry_with_fallback_screenshot(screenshot_path, url, mode, options)
          else
            Logger.warning("Permanent screenshot extraction error: #{inspect(reason)}")
            {:error, reason}
          end
      end
    else
      {:error, _} = error -> error
    end
  end

  defp capture_page_screenshot(url) do
    Browser.capture_screenshot(url, viewport_width: 1920, viewport_height: 1080, timeout: 30000)
  end

  defp attempt_screenshot_extraction(screenshot_path, url, mode, provider, options) do
    # Check cache first by URL
    case Cache.get(url) do
      {:ok, cached} ->
        IO.puts("[Service] Using cached result for #{url}")
        {:ok, cached}

      :not_found ->
        # Build prompt for multimodal extraction
        prompt = PromptTemplates.build_image_extraction_prompt(screenshot_path, url, mode)

        IO.puts("[Service] Attempting image-based extraction with provider: #{inspect(provider)}")

        # Call LLM with image
        try do
          result =
            case provider do
              :ollama ->
                IO.puts("[Service] Calling Ollama with screenshot: #{screenshot_path}")
                call_ollama_with_image(screenshot_path, prompt, options)

              :google ->
                IO.puts("[Service] Calling Google Gemini with screenshot: #{screenshot_path}")
                call_google_gemini_with_image(screenshot_path, prompt, options)

              _ ->
                # For other providers, would need different image handling
                IO.puts("[Service] Non-Ollama provider selected, requires image support")
                {:error, {:llm_error, "Image extraction not yet supported for provider #{provider}"}}
            end

          IO.puts("[Service] Received LLM result: #{inspect(result)}")

          # Parse and validate response
          case result do
            {:ok, response_map} ->
              case parse_llm_response(response_map) do
                {:ok, parsed} ->
                  # Cache successful result
                  Cache.put(url, parsed)
                  {:ok, parsed}

                {:error, reason} ->
                  IO.puts("[ERROR] Failed to parse LLM response: #{inspect(reason)}")
                  IO.puts("[ERROR] Response map was: #{inspect(response_map)}")
                  {:error, reason}
              end

            {:error, reason} ->
              IO.puts("[ERROR] LLM call failed: #{inspect(reason)}")
              {:error, reason}
          end
        rescue
          e ->
            IO.puts("[ERROR] Exception in image extraction: #{Exception.message(e)}")
            IO.puts("[ERROR] Stacktrace: #{inspect(__STACKTRACE__)}")
            {:error, {:llm_error, Exception.message(e)}}
        after
          # Clean up screenshot file
          if File.exists?(screenshot_path) do
            File.rm(screenshot_path)
            IO.puts("[Service] Cleaned up screenshot: #{screenshot_path}")
          end
        end
    end
  end

  defp retry_with_fallback_screenshot(screenshot_path, url, mode, options) do
    # Clean up screenshot
    File.rm(screenshot_path)

    fallback_providers = Application.get_env(:req_llm, :fallback_providers, [])

    case try_screenshot_fallbacks(fallback_providers, screenshot_path, url, mode, options, []) do
      {:ok, result} -> {:ok, result}
      :error -> {:error, :all_providers_failed}
    end
  end

  defp try_screenshot_fallbacks([provider | rest], screenshot_path, url, mode, options, _tried) do
    case attempt_screenshot_extraction(screenshot_path, url, mode, provider, options) do
      {:ok, result} -> {:ok, result}
      {:error, _reason} -> try_screenshot_fallbacks(rest, screenshot_path, url, mode, options, [provider])
    end
  end
  defp try_screenshot_fallbacks([], _screenshot_path, _url, _mode, _options, _tried), do: :error

  defp call_ollama_with_image(screenshot_path, prompt, options) do
    # Get Ollama configuration
    providers = Application.get_env(:req_llm, :providers, %{})
    ollama_config = providers[:ollama] || %{}

    # Use vision model
    model = ollama_config[:vision_model] || "llava"
    base_url = ollama_config[:base_url] || "http://localhost:11434"

    # Build Ollama options
    ollama_options = [
      temperature: options[:temperature] || 0.1,
      top_p: options[:top_p] || 0.9,
      num_predict: options[:max_tokens] || 4096
    ]

    # Call Ollama provider with image
    Clientats.LLM.Providers.Ollama.generate_with_image(model, prompt, screenshot_path, ollama_options, base_url)
  end

  defp call_google_gemini(prompt, options) do
    # Get Google configuration from application config
    providers = Application.get_env(:req_llm, :providers, %{})
    google_config = providers[:google] || %{}

    api_key = google_config[:api_key]
    model = google_config[:default_model] || "gemini-2.0-flash"
    api_version = google_config[:api_version] || "v1beta"

    if !api_key do
      {:error, :missing_api_key}
    else
      # Build Google Gemini API request
      url = "https://generativelanguage.googleapis.com/#{api_version}/models/#{model}:generateContent"

      body = %{
        "contents" => [%{
          "parts" => [%{
            "text" => prompt
          }]
        }]
      }

      try do
        response = Req.post!(
          url,
          headers: [{"x-goog-api-key", api_key}],
          json: body,
          receive_timeout: options[:timeout] || 30_000
        )

        handle_google_response(response)
      rescue
        e ->
          IO.puts("[ERROR] Google Gemini API call failed: #{Exception.message(e)}")
          {:error, {:llm_error, "Google Gemini API call failed: #{Exception.message(e)}"}}
      end
    end
  end

  defp call_google_gemini_with_image(screenshot_path, prompt, options) do
    # Get Google configuration
    providers = Application.get_env(:req_llm, :providers, %{})
    google_config = providers[:google] || %{}

    api_key = google_config[:api_key]
    model = google_config[:vision_model] || "gemini-2.0-flash"
    api_version = google_config[:api_version] || "v1beta"

    if !api_key do
      {:error, :missing_api_key}
    else
      # Read and encode image
      with {:ok, image_data} <- File.read(screenshot_path) do
        base64_image = Base.encode64(image_data)

        # Build Google Gemini API request with image
        url = "https://generativelanguage.googleapis.com/#{api_version}/models/#{model}:generateContent"

        body = %{
          "contents" => [%{
            "parts" => [
              %{
                "text" => prompt
              },
              %{
                "inlineData" => %{
                  "mimeType" => "image/png",
                  "data" => base64_image
                }
              }
            ]
          }]
        }

        try do
          response = Req.post!(
            url,
            headers: [{"x-goog-api-key", api_key}],
            json: body,
            receive_timeout: options[:timeout] || 30_000
          )

          handle_google_response(response)
        rescue
          e ->
            IO.puts("[ERROR] Google Gemini Vision API call failed: #{Exception.message(e)}")
            {:error, {:llm_error, "Google Gemini Vision API call failed: #{Exception.message(e)}"}}
        end
      else
        {:error, reason} ->
          IO.puts("[ERROR] Failed to read screenshot: #{inspect(reason)}")
          {:error, {:llm_error, "Failed to read screenshot: #{inspect(reason)}"}}
      end
    end
  end

  defp handle_google_response(%{status: 200, body: body}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]}} ->
        # Parse the response text as JSON
        case Jason.decode(text) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:ok, %{"response" => text}}
        end

      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        IO.puts("[ERROR] Failed to parse Google response: #{inspect(reason)}")
        {:error, {:parse_error, "Failed to parse Google response"}}
    end
  end

  defp handle_google_response(%{status: 200, body: body}) when is_map(body) do
    case body do
      %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]} ->
        case Jason.decode(text) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:ok, %{"response" => text}}
        end

      _ ->
        {:ok, body}
    end
  end

  defp handle_google_response(%{status: status, body: body}) when status >= 400 do
    error_msg = extract_google_error_message(body)
    IO.puts("[ERROR] Google API error (#{status}): #{error_msg}")
    {:error, {:http_error, status, error_msg}}
  end

  defp handle_google_response(%{status: status} = response) do
    IO.puts("[ERROR] Unexpected Google response status: #{status}")
    IO.puts("[ERROR] Response: #{inspect(response)}")
    {:error, {:http_error, status, "Unexpected response from Google Gemini API"}}
  end

  defp extract_google_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} -> message
      {:ok, %{"error" => error}} when is_binary(error) -> error
      _ -> body
    end
  rescue
    _ -> "Unknown error"
  end

  defp extract_google_error_message(body) when is_map(body) do
    case body do
      %{"error" => %{"message" => message}} -> message
      %{"error" => error} when is_binary(error) -> error
      _ -> inspect(body)
    end
  end

  defp extract_google_error_message(_), do: "Unknown error"

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

              :google ->
                # Use Google Gemini provider
                IO.puts("[DEBUG] Calling Google Gemini via ReqLLM")
                call_google_gemini(prompt, options)

              _ ->
                # Use req_llm for other providers
                IO.puts("[DEBUG] Calling #{provider} via ReqLLM")
                # TODO: Implement proper ReqLLM integration
                # For now, return an error for non-Ollama providers until ReqLLM is properly integrated
                {:error, {:llm_error, "ReqLLM provider #{provider} not yet fully integrated"}}
            end
          
          IO.puts("[DEBUG] Received LLM result: #{inspect(result)}")

          # Parse and validate response
          case result do
            {:ok, response_map} ->
              case parse_llm_response(response_map) do
                {:ok, parsed} ->
                  # Cache successful result
                  Cache.put(url, parsed)
                  {:ok, parsed}
                {:error, reason} ->
                  IO.puts("[ERROR] Failed to parse LLM response: #{inspect(reason)}")
                  IO.puts("[ERROR] Response map was: #{inspect(response_map)}")
                  {:error, reason}
              end
            {:error, reason} ->
              IO.puts("[ERROR] LLM call failed: #{inspect(reason)}")
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

    Logger.info("Retrying with fallback providers. Available: #{inspect(fallback_providers)}")

    # Try each fallback provider with retry logic
    case try_fallbacks(fallback_providers, content, url, mode, options, []) do
      {:ok, result} ->
        Logger.debug("Fallback extraction succeeded")
        {:ok, result}

      :error ->
        Logger.error("All fallback providers failed")
        {:error, :all_providers_failed}
    end
  end

  defp try_fallbacks([provider | rest], content, url, mode, options, tried) do
    Logger.debug("Attempting extraction with provider: #{inspect(provider)}")

    # Use exponential backoff for retries
    case attempt_extraction_with_retry(content, url, mode, provider, options) do
      {:ok, result} ->
        Logger.info("Fallback provider succeeded: #{inspect(provider)}")
        {:ok, result}

      {:error, reason} ->
        Logger.warning("Fallback provider failed: #{inspect(provider)} - #{inspect(reason)}")
        # Continue with next provider
        try_fallbacks(rest, content, url, mode, options, [provider | tried])
    end
  end

  defp try_fallbacks([], _content, _url, _mode, _options, _tried), do: :error

  defp attempt_extraction_with_retry(content, url, mode, provider, options) do
    max_retries = get_provider_max_retries(provider)

    ErrorHandler.with_retry(
      fn -> attempt_extraction(content, url, mode, provider, options) end,
      max_retries: max_retries,
      base_delay: 100,
      retryable: &ErrorHandler.retryable?/1
    )
  end

  defp get_provider_max_retries(provider) do
    providers_config = Application.get_env(:req_llm, :providers, %{})
    provider_config = Map.get(providers_config, provider, %{})
    Map.get(provider_config, :max_retries, 3)
  end
  
  defp call_ollama(prompt, options) do
    # Get Ollama configuration from env (fallback)
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
          :google -> "gemini-2.0-flash"
          :ollama -> "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL"
          _ -> "gpt-4o"
        end
    end
  end

  @doc """
  Get provider configuration from database, with fallback to environment variables.
  """
  def get_provider_config_with_fallback(user_id, provider) do
    case LLMConfig.get_provider_config(user_id, provider) do
      {:ok, config} -> {:ok, config}
      {:error, :not_found} -> get_env_provider_config(provider)
    end
  end

  defp get_env_provider_config(provider) do
    providers = Application.get_env(:req_llm, :providers, %{})

    case providers[provider] do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  @doc """
  Check if a provider is available (configured in database or environment).
  """
  def provider_available?(user_id, provider) do
    case get_provider_config_with_fallback(user_id, provider) do
      {:ok, config} ->
        case provider do
          :ollama -> true
          _ ->
            # Handle both map and struct formats
            api_key = case config do
              %{api_key: key} -> key
              %{"api_key" => key} -> key
              _ -> nil
            end
            api_key != nil
        end

      {:error, :not_found} ->
        false
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
      IO.puts("[Fetch] Fetching content from: #{url}")

      response = Req.get!(url,
           headers: [
             {"User-Agent", "Mozilla/5.0 (compatible; Clientats/1.0; +https://clientats.com)"},
             {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
             {"Accept-Language", "en-US,en;q=0.5"}
           ],
           receive_timeout: 30_000,  # Increased timeout for slower job sites
           redirect: true
          )

      case response.status do
        200 ->
          # Extract and truncate content to stay within LLM limits
          content = response.body
          max_length = Application.get_env(:req_llm, :max_content_length, 500_000)

          IO.puts("[Fetch] Response received: #{byte_size(content)} bytes")
          IO.puts("[Fetch] Max content length: #{max_length} bytes")

          if byte_size(content) > max_length do
            # If content is too large, try to extract main text and truncate
            truncated = String.slice(content, 0, max_length)
            IO.puts("[Fetch] Content truncated to #{byte_size(truncated)} bytes")
            {:ok, truncated}
          else
            IO.puts("[Fetch] Content within limits")
            {:ok, content}
          end

        status ->
          IO.puts("[Fetch] HTTP Error: #{status}")
          {:error, {:http_error, status}}
      end
    rescue
      e ->
        error_msg = Exception.message(e)
        IO.puts("[Fetch] Exception: #{error_msg}")
        {:error, {:fetch_error, error_msg}}
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