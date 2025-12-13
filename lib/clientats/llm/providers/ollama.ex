defmodule Clientats.LLM.Providers.Ollama do
  @moduledoc """
  Ollama provider for local LLM models.

  Provides direct integration with Ollama's REST API for running
  local LLM models like Magistral-Small-2509-GGUF.
  """

  @default_base_url "http://localhost:11434"
  @default_timeout 600_000  # 10 minutes for LLM generation
  
  @type options :: Keyword.t()
  @type response :: map()
  
  @doc """
  Generate text completion using Ollama.
  
  ## Parameters
    - model: Model name (e.g., "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL")
    - prompt: Input prompt
    - options: Additional options (temperature, top_p, etc.)
    - base_url: Ollama server URL (default: http://localhost:11434)
  
  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def generate(model, prompt, options \\ [], base_url \\ nil) do
    base_url = base_url || @default_base_url

    # Build request body
    body = %{
      "model" => model,
      "prompt" => prompt,
      "stream" => false,
      "options" => build_options(options)
    }

    # Log request details
    IO.puts("[Ollama] Sending request to #{base_url}/api/generate")
    IO.puts("[Ollama] Model: #{model}")
    IO.puts("[Ollama] Prompt size: #{byte_size(prompt)} bytes")
    IO.puts("[Ollama] Options: #{inspect(body["options"])}")

    # Make HTTP request with proper error handling
    try do
      response = Req.post!("#{base_url}/api/generate",
        json: body,
        receive_timeout: @default_timeout
      )

      case response do
        %{status: 200, body: response_body} ->
          # Handle both string and map responses
          decoded = case response_body do
            %{} -> response_body
            _ -> Jason.decode!(response_body)
          end

          # Log response details
          IO.puts("[Ollama] Response received (status 200)")
          IO.puts("[Ollama] Response keys: #{inspect(Map.keys(decoded))}")
          if is_map(decoded) && Map.has_key?(decoded, "response") do
            IO.puts("[Ollama] Response text size: #{byte_size(decoded["response"])} bytes")
          end

          {:ok, decoded}

        %{status: status} ->
          IO.puts("[Ollama] HTTP Error: #{status}")
          {:error, {:http_error, status}}
      end
    rescue
      e ->
        case e do
          %Req.TransportError{reason: :timeout} ->
            IO.puts("[Ollama] Request timeout after #{@default_timeout}ms")
            {:error, {:timeout, "Ollama request timeout"}}

          _ ->
            error_msg = Exception.message(e)
            IO.puts("[Ollama] Exception: #{error_msg}")
            {:error, {:exception, error_msg}}
        end
    end
  end
  
  @doc """
  Chat completion using Ollama.
  
  ## Parameters
    - model: Model name
    - messages: List of message maps with :role and :content
    - options: Additional options
    - base_url: Ollama server URL
  
  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def chat(model, messages, options \\ [], base_url \\ nil) do
    base_url = base_url || @default_base_url
    
    # Convert messages to prompt
    prompt = build_prompt_from_messages(messages)
    
    # Use generate endpoint
    generate(model, prompt, options, base_url)
  end
  
  @doc """
  List available models from Ollama server.
  """
  def list_models(base_url \\ nil) do
    base_url = base_url || @default_base_url

    try do
      case Req.get("#{base_url}/api/tags", receive_timeout: 10_000) do
        %{status: 200, body: body} ->
          {:ok, Jason.decode!(body)}
        
        %{status: status, body: _body} ->
          {:error, {:http_error, status}}
        
        error ->
          {:error, {:request_error, inspect(error)}}
      end
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    end
  end
  
  @doc """
  Check if Ollama server is available.
  """
  def ping(base_url \\ nil) do
    base_url = base_url || @default_base_url

    try do
      response = Req.get!("#{base_url}", receive_timeout: 10_000)
      case response.status do
        200 -> {:ok, :available}
        _ -> {:error, :unavailable}
      end
    rescue
      _ -> {:error, :unavailable}
    end
  end
  
  # Private functions
  
  defp build_options(options) when is_list(options) do
    # Convert keyword list to map
    options
    |> Enum.into(%{})
  end
  defp build_options(options) when is_map(options), do: options
  defp build_options(_), do: %{}
  
  defp build_prompt_from_messages(messages) do
    messages
    |> Enum.map(fn msg ->
      role = msg[:role] || msg["role"] || "user"
      content = msg[:content] || msg["content"] || ""
      "#{role}: #{content}"
    end)
    |> Enum.join("\n")
  end
  

end