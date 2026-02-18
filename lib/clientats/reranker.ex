defmodule Clientats.Reranker do
  @moduledoc """
  Second-stage reranking for the job matching pipeline.

  After vector search returns top candidates (100-200), the reranker
  re-scores each candidate against the query using a more powerful model
  (cross-encoder or LLM) that considers the full text of both query and document.

  ## Approaches

  1. **Gemini API** (`:gemini`) - Listwise LLM reranking. Sends batches of
     candidates to Gemini with a reranking prompt. Best quality, requires API key.

  2. **Ollama** (`:ollama`) - Pointwise LLM scoring. Scores each candidate
     individually using a local LLM. Free, offline, slower for large batches.

  3. **Vector-only** (`:vector`) - No reranking, just pass through vector
     distances. Baseline for comparison.

  ## Usage

      # Rerank vector search results against a query
      candidates = [
        %{id: 1, title: "Elixir Dev", description: "...", distance: 0.15},
        %{id: 2, title: "Python Dev", description: "...", distance: 0.20},
      ]

      {:ok, ranked} = Reranker.rerank("Senior Elixir developer with fintech", candidates)
      # Returns candidates sorted by relevance score (higher = better)
  """

  require Logger

  @default_batch_size 20
  @ollama_url "http://localhost:11434"
  @ollama_model "llama3.2"

  @type candidate :: %{
          id: integer(),
          title: String.t(),
          description: String.t() | nil,
          distance: float()
        }

  @type ranked_result :: %{
          id: integer(),
          title: String.t(),
          score: float(),
          rank: integer(),
          original_distance: float()
        }

  @doc """
  Rerank candidates against a query string.

  ## Options
    * `:strategy` - Reranking strategy: `:gemini`, `:ollama`, or `:vector` (default: auto-detect)
    * `:batch_size` - Candidates per LLM batch for Gemini (default: 20)
    * `:user_id` - User ID for API key lookup
    * `:top_k` - Return only top K results (default: all)
  """
  @spec rerank(String.t(), [candidate()], keyword()) :: {:ok, [ranked_result()]} | {:error, term()}
  def rerank(query, candidates, opts \\ []) do
    strategy = opts[:strategy] || default_strategy()
    top_k = opts[:top_k] || length(candidates)

    Logger.info("[Reranker] Strategy: #{strategy}, candidates: #{length(candidates)}, top_k: #{top_k}")

    {time_us, result} =
      :timer.tc(fn ->
        case strategy do
          :gemini -> rerank_gemini(query, candidates, opts)
          :ollama -> rerank_ollama(query, candidates, opts)
          :vector -> rerank_vector(candidates)
        end
      end)

    Logger.info("[Reranker] Completed in #{div(time_us, 1000)}ms")

    case result do
      {:ok, ranked} -> {:ok, Enum.take(ranked, top_k)}
      error -> error
    end
  end

  @doc """
  Compare multiple reranking strategies on the same query + candidates.
  Returns a map of strategy => ranked results for quality comparison.
  """
  def compare(query, candidates, strategies \\ [:gemini, :ollama, :vector], opts \\ []) do
    results =
      Enum.reduce(strategies, %{}, fn strategy, acc ->
        case rerank(query, candidates, Keyword.put(opts, :strategy, strategy)) do
          {:ok, ranked} ->
            Map.put(acc, strategy, ranked)

          {:error, reason} ->
            Logger.warning("[Reranker] Strategy #{strategy} failed: #{inspect(reason)}")
            Map.put(acc, strategy, {:error, reason})
        end
      end)

    {:ok, results}
  end

  @doc """
  Compute NDCG@K (Normalized Discounted Cumulative Gain) for a ranked list
  against ground truth relevance labels.

  `relevance_map` is a map of `id => relevance_score` (higher = more relevant).
  """
  def ndcg_at_k(ranked_results, relevance_map, k) do
    ranked = Enum.take(ranked_results, k)

    dcg =
      ranked
      |> Enum.with_index(1)
      |> Enum.reduce(0.0, fn {result, pos}, acc ->
        rel = Map.get(relevance_map, result.id, 0)
        acc + (rel / :math.log2(pos + 1))
      end)

    # Ideal DCG: sort by relevance descending
    ideal_order =
      relevance_map
      |> Enum.sort_by(fn {_id, rel} -> rel end, :desc)
      |> Enum.take(k)

    idcg =
      ideal_order
      |> Enum.with_index(1)
      |> Enum.reduce(0.0, fn {{_id, rel}, pos}, acc ->
        acc + (rel / :math.log2(pos + 1))
      end)

    if idcg == 0.0, do: 0.0, else: dcg / idcg
  end

  # --- Gemini API Reranking ---

  defp rerank_gemini(query, candidates, opts) do
    batch_size = opts[:batch_size] || @default_batch_size

    batches =
      candidates
      |> Enum.with_index()
      |> Enum.chunk_every(batch_size)

    results =
      Enum.flat_map(batches, fn batch ->
        case rerank_gemini_batch(query, batch, opts) do
          {:ok, scored} -> scored
          {:error, reason} ->
            Logger.warning("[Reranker] Gemini batch failed: #{inspect(reason)}, falling back to distances")
            # Fall back to vector distances for this batch
            Enum.map(batch, fn {candidate, _idx} ->
              %{
                id: candidate.id,
                title: candidate.title,
                score: 1.0 - (candidate.distance || 1.0),
                rank: 0,
                original_distance: candidate.distance || 1.0
              }
            end)
        end
      end)

    ranked =
      results
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {result, rank} -> %{result | rank: rank} end)

    {:ok, ranked}
  end

  defp rerank_gemini_batch(query, indexed_candidates, opts) do
    candidates_text =
      indexed_candidates
      |> Enum.map(fn {candidate, _idx} ->
        desc = candidate[:description] || candidate[:title] || ""
        desc_preview = String.slice(desc, 0, 300)
        "[#{candidate.id}] #{candidate.title}\n#{desc_preview}"
      end)
      |> Enum.join("\n---\n")

    prompt = """
    You are a job relevance scoring system. Score each job listing's relevance to the search query.

    QUERY: "#{query}"

    JOB LISTINGS:
    #{candidates_text}

    For each job, assign a relevance score from 0.0 to 1.0:
    - 1.0 = perfect match (exact role, skills, and domain)
    - 0.7-0.9 = strong match (related role/skills)
    - 0.4-0.6 = partial match (some overlap)
    - 0.1-0.3 = weak match (tangentially related)
    - 0.0 = no relevance

    Return ONLY valid JSON as an array of objects with "id" (number) and "score" (number).
    Example: [{"id": 123, "score": 0.85}, {"id": 456, "score": 0.42}]
    """

    case call_gemini(prompt, opts) do
      {:ok, scores} when is_list(scores) ->
        score_map = Map.new(scores, fn item ->
          {item["id"], item["score"] || 0.0}
        end)

        results =
          Enum.map(indexed_candidates, fn {candidate, _idx} ->
            %{
              id: candidate.id,
              title: candidate.title,
              score: Map.get(score_map, candidate.id, 0.0),
              rank: 0,
              original_distance: candidate[:distance] || 1.0
            }
          end)

        {:ok, results}

      {:ok, other} ->
        Logger.warning("[Reranker] Unexpected Gemini response format: #{inspect(other)}")
        {:error, :unexpected_format}

      {:error, _} = error ->
        error
    end
  end

  # --- Ollama Pointwise Scoring ---

  defp rerank_ollama(query, candidates, opts) do
    model = opts[:ollama_model] || @ollama_model

    results =
      candidates
      |> Task.async_stream(
        fn candidate ->
          case score_with_ollama(query, candidate, model) do
            {:ok, score} ->
              %{
                id: candidate.id,
                title: candidate.title,
                score: score,
                rank: 0,
                original_distance: candidate[:distance] || 1.0
              }

            {:error, _reason} ->
              %{
                id: candidate.id,
                title: candidate.title,
                score: 1.0 - (candidate[:distance] || 1.0),
                rank: 0,
                original_distance: candidate[:distance] || 1.0
              }
          end
        end,
        max_concurrency: 2,
        timeout: 30_000,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, _} -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {result, rank} -> %{result | rank: rank} end)

    {:ok, results}
  end

  defp score_with_ollama(query, candidate, model) do
    desc = candidate[:description] || candidate[:title] || ""
    desc_preview = String.slice(desc, 0, 500)

    prompt = """
    Rate the relevance of this job to the search query on a scale of 0.0 to 1.0.
    Respond with ONLY a single decimal number, nothing else.

    Query: "#{query}"
    Job Title: #{candidate.title}
    Description: #{desc_preview}

    Score:
    """

    url = "#{@ollama_url}/api/generate"

    body = %{
      "model" => model,
      "prompt" => prompt,
      "stream" => false,
      "options" => %{"temperature" => 0.1, "num_predict" => 10}
    }

    try do
      response = Req.post!(url, json: body, receive_timeout: 30_000)

      case response.status do
        200 ->
          text = response.body["response"] || ""
          case Float.parse(String.trim(text)) do
            {score, _} when score >= 0.0 and score <= 1.0 -> {:ok, score}
            {score, _} -> {:ok, max(0.0, min(1.0, score))}
            :error -> {:error, {:parse_error, text}}
          end

        status ->
          {:error, {:http_error, status}}
      end
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    end
  end

  # --- Vector-only (no reranking) ---

  defp rerank_vector(candidates) do
    ranked =
      candidates
      |> Enum.sort_by(& &1[:distance], :asc)
      |> Enum.with_index(1)
      |> Enum.map(fn {candidate, rank} ->
        %{
          id: candidate.id,
          title: candidate.title,
          score: 1.0 - (candidate[:distance] || 1.0),
          rank: rank,
          original_distance: candidate[:distance] || 1.0
        }
      end)

    {:ok, ranked}
  end

  # --- Gemini API Call ---

  defp call_gemini(prompt, opts) do
    user_id = opts[:user_id]

    api_key = resolve_gemini_api_key(user_id)

    model =
      if user_id do
        case Clientats.LLMConfig.get_provider_config(user_id, :gemini) do
          {:ok, setting} -> setting.default_model || "gemini-2.0-flash"
          {:error, _} -> "gemini-2.0-flash"
        end
      else
        Application.get_env(:req_llm, :providers, %{})[:google][:default_model] ||
          "gemini-2.0-flash"
      end

    api_version =
      Application.get_env(:req_llm, :providers, %{})[:google][:api_version] || "v1beta"

    if !api_key do
      {:error, :missing_api_key}
    else
      url =
        "https://generativelanguage.googleapis.com/#{api_version}/models/#{model}:generateContent"

      body = %{
        "contents" => [
          %{"parts" => [%{"text" => prompt}]}
        ],
        "generationConfig" => %{
          "responseMimeType" => "application/json",
          "temperature" => 0.1
        }
      }

      try do
        response =
          Req.post!(url,
            headers: [{"x-goog-api-key", api_key}],
            json: body,
            receive_timeout: opts[:timeout] || 30_000
          )

        case response.status do
          200 ->
            case response.body do
              %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]} ->
                case Jason.decode(text) do
                  {:ok, parsed} -> {:ok, parsed}
                  {:error, _} -> {:error, {:json_parse_error, String.slice(text, 0, 200)}}
                end

              _ ->
                {:error, {:unexpected_response, response.body}}
            end

          429 ->
            {:error, :rate_limited}

          status ->
            {:error, {:http_error, status, response.body}}
        end
      rescue
        e in [Req.TransportError] ->
          if e.reason == :timeout do
            {:error, {:timeout, "Gemini API call timed out"}}
          else
            {:error, {:transport_error, Exception.message(e)}}
          end

        e ->
          {:error, {:exception, Exception.message(e)}}
      end
    end
  end

  defp resolve_gemini_api_key(user_id) do
    user_key =
      if user_id do
        case Clientats.LLMConfig.get_provider_config(user_id, :gemini) do
          {:ok, setting} -> setting.api_key
          {:error, _} -> nil
        end
      else
        nil
      end

    user_key || Application.get_env(:req_llm, :providers, %{})[:google][:api_key]
  end

  defp default_strategy do
    cond do
      resolve_gemini_api_key(nil) -> :gemini
      true -> :ollama
    end
  end
end
