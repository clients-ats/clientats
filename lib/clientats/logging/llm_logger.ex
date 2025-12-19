defmodule Clientats.Logging.LLMLogger do
  @moduledoc """
  Logging handler for LLM API requests and responses.

  This module provides utilities to log all LLM interactions for debugging and monitoring.
  """

  alias Clientats.Logging.{LogWriter, Timestamp, Utils}
  require Logger

  @doc """
  Log an LLM request and response.

  Parameters:
  - provider: atom like :ollama, :openai, :anthropic, :mistral, :gemini
  - model: string model name
  - request: the request parameters/payload
  - response: the response data
  - latency_ms: request latency in milliseconds
  - metadata: optional map with user_id, endpoint, url, etc.

  Returns: {:ok, filename} or {:error, reason}
  """
  def log_request(provider, model, request, response, latency_ms, metadata \\ %{}) do
    Utils.log_llm_request(provider, model, request, response, latency_ms, metadata)
  end

  @doc """
  Log an LLM error.

  Parameters:
  - provider: atom like :ollama, :openai, :anthropic
  - model: string model name
  - request: the request that failed
  - error: the error details
  - latency_ms: latency before error
  - metadata: optional metadata

  Returns: {:ok, filename} or {:error, reason}
  """
  def log_error(provider, model, request, error, latency_ms, metadata \\ %{}) do
    timestamp = Timestamp.filename_safe_now(:microsecond)
    provider_str = provider |> Atom.to_string()
    filename = "#{timestamp}_#{provider_str}_#{model}_ERROR.json"

    error_response = %{
      "error" => true,
      "error_type" => error_type(error),
      "error_message" => error_message(error),
      "error_details" => inspect(error)
    }

    log_entry = %{
      "timestamp" => Timestamp.iso8601_now(),
      "timestamp_unix_ms" => Timestamp.unix_ms_now(),
      "provider" => provider_str,
      "model" => model,
      "user_id" => Map.get(metadata, :user_id),
      "endpoint" => Map.get(metadata, :endpoint),
      "request" => request,
      "error" => error_response,
      "latency_ms" => latency_ms,
      "success" => false
    }

    with {:ok, _path} <- LogWriter.write_log(:llm_requests, filename, log_entry),
         prompt_length <- count_tokens(request),
         {:ok, _path} <-
           LogWriter.append_index(:llm_requests, "index.json", %{
             "timestamp" => log_entry["timestamp"],
             "provider" => provider_str,
             "model" => model,
             "prompt_length" => prompt_length,
             "response_length" => 0,
             "latency_ms" => latency_ms,
             "success" => false,
             "error_type" => error_response["error_type"],
             "filename" => filename
           }) do
      {:ok, filename}
    else
      {:error, reason} ->
        Logger.error("Failed to log LLM error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get request logs for a specific provider.

  Returns: list of request entries
  """
  def get_provider_logs(provider) do
    provider_str = Atom.to_string(provider)
    Utils.search_by_provider(:llm_requests, provider_str)
  end

  @doc """
  Get request logs for a specific model.

  Returns: list of request entries
  """
  def get_model_logs(model) do
    entries = LogWriter.read_index(:llm_requests, "index.json")

    Enum.filter(entries, fn entry ->
      entry["model"] == model
    end)
  end

  @doc """
  Get all failed LLM requests.

  Returns: list of failed request entries
  """
  def get_failed_requests do
    entries = LogWriter.read_index(:llm_requests, "index.json")

    Enum.filter(entries, fn entry ->
      entry["success"] === false
    end)
  end

  @doc """
  Get LLM requests from the last N days.

  Returns: list of request entries
  """
  def get_recent_requests(days \\ 7) do
    Utils.logs_from_last_days(:llm_requests, days)
  end

  @doc """
  Get statistics about LLM usage.

  Returns: map with provider, model, total_requests, success_rate, avg_latency, etc.
  """
  def get_usage_stats do
    entries = LogWriter.read_index(:llm_requests, "index.json")

    stats =
      Enum.reduce(entries, %{}, fn entry, acc ->
        provider = entry["provider"] || "unknown"
        model = entry["model"] || "unknown"
        key = "#{provider}:#{model}"

        stats_entry =
          Map.get(acc, key, %{
            "provider" => provider,
            "model" => model,
            "total_requests" => 0,
            "successful_requests" => 0,
            "failed_requests" => 0,
            "total_latency_ms" => 0,
            "total_prompt_tokens" => 0,
            "total_response_tokens" => 0
          })

        updated =
          stats_entry
          |> Map.update!("total_requests", &(&1 + 1))
          |> Map.update!(
            "successful_requests",
            &(&1 + if(entry["success"] === true, do: 1, else: 0))
          )
          |> Map.update!(
            "failed_requests",
            &(&1 + if(entry["success"] === false, do: 1, else: 0))
          )
          |> Map.update!("total_latency_ms", &(&1 + (entry["latency_ms"] || 0)))
          |> Map.update!("total_prompt_tokens", &(&1 + (entry["prompt_length"] || 0)))
          |> Map.update!("total_response_tokens", &(&1 + (entry["response_length"] || 0)))

        Map.put(acc, key, updated)
      end)

    # Calculate averages
    Enum.map(stats, fn {_, stats_entry} ->
      total = stats_entry["total_requests"]

      stats_entry
      |> Map.put(
        "success_rate",
        if(total > 0, do: stats_entry["successful_requests"] / total, else: 0)
      )
      |> Map.put(
        "avg_latency_ms",
        if(total > 0, do: stats_entry["total_latency_ms"] / total, else: 0)
      )
      |> Map.put(
        "avg_prompt_tokens",
        if(total > 0, do: stats_entry["total_prompt_tokens"] / total, else: 0)
      )
      |> Map.put(
        "avg_response_tokens",
        if(total > 0, do: stats_entry["total_response_tokens"] / total, else: 0)
      )
    end)
    |> Enum.sort_by(&Map.get(&1, "total_requests"), :desc)
  end

  defp error_type(error) when is_binary(error) do
    "unknown_error"
  end

  defp error_type(%{"error" => _} = error) do
    error["error_type"] || "api_error"
  end

  defp error_type({:error, reason}) when is_binary(reason) do
    classify_error(reason)
  end

  defp error_type({:error, reason}) when is_atom(reason) do
    reason |> Atom.to_string()
  end

  defp error_type(_) do
    "unknown_error"
  end

  defp error_message(error) when is_binary(error) do
    error
  end

  defp error_message(%{"error" => msg}) when is_binary(msg) do
    msg
  end

  defp error_message({:error, msg}) when is_binary(msg) do
    msg
  end

  defp error_message({:error, msg}) when is_atom(msg) do
    Atom.to_string(msg)
  end

  defp error_message(error) do
    inspect(error)
  end

  defp classify_error(error_str) when is_binary(error_str) do
    cond do
      String.contains?(error_str, "timeout") -> "timeout"
      String.contains?(error_str, "connection") -> "connection_error"
      String.contains?(error_str, "auth") -> "authentication_error"
      String.contains?(error_str, "rate") -> "rate_limit"
      String.contains?(error_str, "404") -> "not_found"
      String.contains?(error_str, "500") -> "server_error"
      true -> "request_error"
    end
  end

  defp classify_error(_), do: "unknown_error"

  defp count_tokens(data) when is_map(data) or is_list(data) do
    data |> inspect() |> String.length() |> div(4)
  end

  defp count_tokens(data) when is_binary(data) do
    String.length(data) |> div(4)
  end

  defp count_tokens(_), do: 0
end
