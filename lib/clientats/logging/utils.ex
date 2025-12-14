defmodule Clientats.Logging.Utils do
  @moduledoc """
  Logging utilities and helpers.
  """

  alias Clientats.Logging.{LogWriter, Timestamp}
  require Logger

  @doc """
  Log form data with automatic filename and index update.

  Parameters:
  - form_params: the form data map
  - metadata: map with user_id, provider_name, etc.

  Returns: {:ok, filename} or {:error, reason}
  """
  def log_form_submission(form_params, metadata \\ %{}) do
    timestamp = Timestamp.filename_safe_now(:microsecond)
    provider = Map.get(metadata, :provider_name, "unknown")
    filename = "#{timestamp}_#{provider}.json"

    log_entry = %{
      "timestamp" => Timestamp.iso8601_now(),
      "timestamp_unix_ms" => Timestamp.unix_ms_now(),
      "provider" => provider,
      "user_id" => Map.get(metadata, :user_id),
      "form_data" => form_params
    }

    with {:ok, _path} <- LogWriter.write_log(:form_data, filename, log_entry),
         {:ok, _path} <-
           LogWriter.append_index(:form_data, "index.json", %{
             "timestamp" => log_entry["timestamp"],
             "provider" => provider,
             "user_id" => log_entry["user_id"],
             "filename" => filename
           }) do
      {:ok, filename}
    else
      {:error, reason} ->
        Logger.error("Failed to log form submission: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Log an LLM request and response.

  Parameters:
  - provider: atom like :ollama, :openai, :anthropic
  - model: string model name
  - request: the request parameters
  - response: the response data
  - latency_ms: request latency in milliseconds
  - metadata: optional map with user_id, endpoint, etc.

  Returns: {:ok, filename} or {:error, reason}
  """
  def log_llm_request(provider, model, request, response, latency_ms, metadata \\ %{}) do
    timestamp = Timestamp.filename_safe_now(:microsecond)
    provider_str = provider |> Atom.to_string()
    filename = "#{timestamp}_#{provider_str}_#{model}.json"

    success = !is_error_response(response)

    log_entry = %{
      "timestamp" => Timestamp.iso8601_now(),
      "timestamp_unix_ms" => Timestamp.unix_ms_now(),
      "provider" => provider_str,
      "model" => model,
      "user_id" => Map.get(metadata, :user_id),
      "endpoint" => Map.get(metadata, :endpoint),
      "request" => request,
      "response" => response,
      "latency_ms" => latency_ms,
      "success" => success
    }

    with {:ok, _path} <- LogWriter.write_log(:llm_requests, filename, log_entry),
         prompt_length <- count_tokens(request),
         response_length <- count_tokens(response),
         {:ok, _path} <-
           LogWriter.append_index(:llm_requests, "index.json", %{
             "timestamp" => log_entry["timestamp"],
             "provider" => provider_str,
             "model" => model,
             "prompt_length" => prompt_length,
             "response_length" => response_length,
             "latency_ms" => latency_ms,
             "success" => success,
             "filename" => filename
           }) do
      {:ok, filename}
    else
      {:error, reason} ->
        Logger.error("Failed to log LLM request: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Log a Playwright screenshot or snapshot.

  Parameters:
  - screenshot_path: path to the screenshot file
  - test_name: name of the test
  - url: page URL when screenshot was taken
  - metadata: optional metadata

  Returns: {:ok, filename} or {:error, reason}
  """
  def log_playwright_screenshot(screenshot_path, test_name, url, metadata \\ %{}) do
    timestamp = Timestamp.filename_safe_now(:microsecond)
    filename = "#{timestamp}_#{sanitize_filename(test_name)}.json"

    # Also copy or reference the actual screenshot file
    screenshot_filename = Path.basename(screenshot_path)

    log_entry = %{
      "timestamp" => Timestamp.iso8601_now(),
      "timestamp_unix_ms" => Timestamp.unix_ms_now(),
      "test_name" => test_name,
      "url" => url,
      "screenshot_path" => screenshot_path,
      "screenshot_filename" => screenshot_filename,
      "metadata" => metadata
    }

    with {:ok, _path} <- LogWriter.write_log(:playwright_screenshots, filename, log_entry),
         {:ok, _path} <-
           LogWriter.append_index(:playwright_screenshots, "index.json", %{
             "timestamp" => log_entry["timestamp"],
             "test_name" => test_name,
             "url" => url,
             "screenshot_filename" => screenshot_filename,
             "filename" => filename
           }) do
      {:ok, filename}
    else
      {:error, reason} ->
        Logger.error("Failed to log Playwright screenshot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  View logs for a specific category and optional filter.

  Parameters:
  - category: :form_data, :llm_requests, or :playwright_screenshots
  - filters: optional map for filtering

  Returns: list of log entries
  """
  def view_logs(category, filters \\ %{})

  def view_logs(category, filters) when is_atom(category) do
    case LogWriter.read_index(category, "index.json") do
      {:error, _reason} ->
        []

      entries ->
        entries
        |> Stream.filter(&matches_filters(&1, filters))
        |> Enum.to_list()
    end
  end

  @doc """
  Search logs by provider name.
  """
  def search_by_provider(category, provider) when is_atom(category) and is_binary(provider) do
    view_logs(category, %{"provider" => provider})
  end

  @doc """
  Get logs from the last N days.
  """
  def logs_from_last_days(category, days) when is_atom(category) and is_integer(days) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600)

    view_logs(category)
    |> Enum.filter(fn entry ->
      case entry["timestamp"] do
        nil -> false
        ts -> DateTime.from_iso8601(ts) |> elem(0) |> DateTime.compare(cutoff_time) in [:eq, :gt]
      end
    end)
  end

  defp matches_filters(entry, filters) do
    Enum.all?(filters, fn {key, value} ->
      entry[key] == value
    end)
  end

  defp is_error_response(response) do
    case response do
      %{"error" => _} -> true
      %{error: _} -> true
      {:error, _} -> true
      _ -> false
    end
  end

  defp count_tokens(data) when is_map(data) or is_list(data) do
    data |> inspect() |> String.length() |> div(4)
  end

  defp count_tokens(data) when is_binary(data) do
    String.length(data) |> div(4)
  end

  defp count_tokens(_), do: 0

  defp sanitize_filename(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "_")
    |> String.slice(0..64)
  end
end
