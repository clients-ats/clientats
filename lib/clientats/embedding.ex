defmodule Clientats.Embedding do
  @moduledoc """
  Embedding generation service for job descriptions.

  Supports multiple providers:
  - Gemini (text-embedding-004 / gemini-embedding-001) via ReqLLM
  - Ollama (nomic-embed-text) via direct HTTP API

  Provider is selected via application config or per-call options.
  """

  require Logger

  @ollama_default_model "nomic-embed-text"
  @gemini_default_model "google:gemini-embedding-001"

  @doc """
  Generate an embedding for a single text string.

  ## Options
    * `:provider` - `:gemini` or `:ollama` (default: configured or `:ollama`)
    * `:model` - Override model name
    * `:dimensions` - Desired embedding dimensions (Gemini only)
    * `:task_type` - Gemini task type (e.g., "RETRIEVAL_DOCUMENT", "RETRIEVAL_QUERY")
  """
  @spec embed(String.t(), keyword()) :: {:ok, [float()]} | {:error, term()}
  def embed(text, opts \\ []) when is_binary(text) do
    provider = opts[:provider] || default_provider()

    case provider do
      :gemini -> embed_gemini(text, opts)
      :ollama -> embed_ollama(text, opts)
      other -> {:error, {:unsupported_provider, other}}
    end
  end

  @doc """
  Generate embeddings for multiple texts in a single batch.

  Returns embeddings in the same order as input texts.
  """
  @spec embed_batch([String.t()], keyword()) :: {:ok, [[float()]]} | {:error, term()}
  def embed_batch(texts, opts \\ []) when is_list(texts) do
    provider = opts[:provider] || default_provider()

    case provider do
      :gemini -> embed_batch_gemini(texts, opts)
      :ollama -> embed_batch_ollama(texts, opts)
      other -> {:error, {:unsupported_provider, other}}
    end
  end

  @doc """
  Calculate cosine similarity between two embedding vectors.
  Delegates to ReqLLM.cosine_similarity/2.
  """
  @spec cosine_similarity([float()], [float()]) :: float()
  defdelegate cosine_similarity(a, b), to: ReqLLM

  @doc """
  Returns the default provider based on application config.
  Falls back to :ollama if no Gemini API key is configured.
  """
  def default_provider do
    providers = Application.get_env(:req_llm, :providers, %{})

    cond do
      get_in(providers, [:google, :api_key]) not in [nil, ""] -> :gemini
      true -> :ollama
    end
  end

  @doc """
  Returns the embedding dimensions for the current provider/model.
  """
  def dimensions(opts \\ []) do
    provider = opts[:provider] || default_provider()

    case provider do
      :gemini -> opts[:dimensions] || 768
      :ollama -> 768
    end
  end

  # --- Gemini ---

  defp embed_gemini(text, opts) do
    model = opts[:model] || @gemini_default_model

    req_opts =
      opts
      |> Keyword.take([:dimensions])
      |> then(fn o ->
        case opts[:task_type] do
          nil -> o
          task_type -> Keyword.put(o, :provider_options, %{task_type: task_type})
        end
      end)

    case ReqLLM.embed(model, text, req_opts) do
      {:ok, embedding} ->
        {:ok, embedding}

      {:error, error} ->
        Logger.warning("[Embedding] Gemini error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp embed_batch_gemini(texts, opts) do
    model = opts[:model] || @gemini_default_model

    req_opts =
      opts
      |> Keyword.take([:dimensions])
      |> then(fn o ->
        case opts[:task_type] do
          nil -> o
          task_type -> Keyword.put(o, :provider_options, %{task_type: task_type})
        end
      end)

    case ReqLLM.embed(model, texts, req_opts) do
      {:ok, embeddings} -> {:ok, embeddings}
      {:error, error} -> {:error, error}
    end
  end

  # --- Ollama ---

  defp embed_ollama(text, opts) do
    model = opts[:model] || ollama_model()
    base_url = ollama_base_url()

    body = Jason.encode!(%{model: model, input: text})

    case Req.post("#{base_url}/api/embed",
           body: body,
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %{status: 200, body: %{"embeddings" => [embedding | _]}}} ->
        {:ok, embedding}

      {:ok, %{status: status, body: body}} ->
        {:error, {:ollama_error, status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp embed_batch_ollama(texts, opts) do
    model = opts[:model] || ollama_model()
    base_url = ollama_base_url()

    body = Jason.encode!(%{model: model, input: texts})

    case Req.post("#{base_url}/api/embed",
           body: body,
           headers: [{"content-type", "application/json"}]
         ) do
      {:ok, %{status: 200, body: %{"embeddings" => embeddings}}} ->
        {:ok, embeddings}

      {:ok, %{status: status, body: body}} ->
        {:error, {:ollama_error, status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp ollama_base_url do
    providers = Application.get_env(:req_llm, :providers, %{})
    get_in(providers, [:ollama, :base_url]) || "http://localhost:11434"
  end

  defp ollama_model do
    @ollama_default_model
  end
end
