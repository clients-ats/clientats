defmodule Clientats.LLM.Providers.Ollama do
  @moduledoc """
  Ollama provider for local LLM models.
  
  Provides direct integration with Ollama's REST API for running
  local LLM models like Magistral-Small-2509-GGUF.
  """
  
  @default_base_url "http://localhost:11434"
  @default_timeout 60_000
  
  @type options :: Keyword.t()
  @type response :: map()
  
  @doc """
  Generate text completion using Ollama.
  
  ## Parameters
    - model: Model name (e.g., "unsloth/magistral-small-2509:UD-Q4_K_XL")
    - prompt: Input prompt
    - options: Additional options (temperature, top_p, etc.)
    - base_url: Ollama server URL (default: http://localhost:11434)
  
  ## Returns
    - {:ok, response} on success
    - {:error, reason} on failure
  """
  def generate(model, prompt, options \ [], base_url \ nil) do
    base_url = base_url || @default_base_url
    
    # Build request body
    body = %{
      "model" => model,
      "prompt" => prompt,
      "stream" => false,
      "options" => build_options(options)
    }
    
    # Make HTTP request
    try do
      case Req.post("#{base_url}/api/generate", json: body, timeout: @default_timeout) do
        %{status: 200, body: body} ->
          {:ok, Jason.decode!(body)}
        
        %{status: status, body: body} ->
          error_body = try_do(Jason.decode(body), %{})
          {:error, {:http_error, status, error_body}}
        
        error ->
          {:error, {:request_error, inspect(error)}}
      end
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
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
  def chat(model, messages, options \ [], base_url \ nil) do
    base_url = base_url || @default_base_url
    
    # Convert messages to prompt
    prompt = build_prompt_from_messages(messages)
    
    # Use generate endpoint
    generate(model, prompt, options, base_url)
  end
  
  @doc """
  List available models from Ollama server.
  """
  def list_models(base_url \ nil) do
    base_url = base_url || @default_base_url
    
    try do
      case Req.get("#{base_url}/api/tags", timeout: 10_000) do
        %{status: 200, body: body} ->
          {:ok, Jason.decode!(body)}
        
        %{status: status, body: body} ->
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
  def ping(base_url \ nil) do
    base_url = base_url || @default_base_url
    
    try do
      case Req.get("#{base_url}", timeout: 5_000) do
        %{status: 200} -> {:ok, :available}
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
    |> Keyword.new()
    |> Map.from_struct()
  end
  defp build_options(options) when is_map(options), do: options
  defp build_options(_), do: %{}
  
  defp build_prompt_from_messages(messages) do
    messages
    |> Enum.map(fn msg ->
      "#{msg.role || "user"}: #{msg.content}"
    end)
    |> Enum.join("\n")
  end
  
  defp try_do(fun, default) do
    try do
      fun.()
    rescue
      _ -> default
    end
  end
end