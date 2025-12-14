defmodule Clientats.Logging.LogWriter do
  @moduledoc """
  Handles file I/O and JSON serialization for logging.
  """

  require Logger

  @doc """
  Write a log entry to a JSON file.

  Parameters:
  - category: :form_data, :llm_requests, or :playwright_screenshots
  - filename: name of the file (without path)
  - data: map to be serialized as JSON

  Returns: {:ok, path} or {:error, reason}
  """
  def write_log(category, filename, data) when is_atom(category) and is_map(data) do
    try do
      with :ok <- ensure_directory_exists(category),
           log_path <- get_log_path(category, filename),
           json_data <- Jason.encode!(data),
           :ok <- File.write(log_path, json_data <> "\n", [:append]) do
        {:ok, log_path}
      end
    rescue
      e ->
        Logger.error("Failed to write log: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Append an entry to an index JSON file (one JSON object per line).

  Parameters:
  - category: :form_data, :llm_requests, or :playwright_screenshots
  - index_filename: name of the index file
  - entry: map to append to the index

  Returns: {:ok, path} or {:error, reason}
  """
  def append_index(category, index_filename, entry) when is_atom(category) and is_map(entry) do
    try do
      with :ok <- ensure_directory_exists(category),
           index_path <- get_log_path(category, index_filename),
           json_entry <- Jason.encode!(entry),
           :ok <- File.write(index_path, json_entry <> "\n", [:append]) do
        {:ok, index_path}
      end
    rescue
      e ->
        Logger.error("Failed to append to index: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Read all entries from an index file (one JSON object per line).

  Returns: list of maps or {:error, reason}
  """
  def read_index(category, index_filename) when is_atom(category) do
    index_path = get_log_path(category, index_filename)

    case File.read(index_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&Jason.decode!/1)

      {:error, :enoent} ->
        []

      {:error, reason} ->
        Logger.error("Failed to read index: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error parsing index: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Get the full path for a log file.
  """
  def get_log_path(category, filename) when is_atom(category) do
    category_dir =
      case category do
        :form_data -> "form_data"
        :llm_requests -> "llm_requests"
        :playwright_screenshots -> "playwright_screenshots"
      end

    Path.join(log_base_dir(), Path.join(category_dir, filename))
  end

  @doc """
  Get the base logs directory.
  """
  def log_base_dir do
    Application.get_env(:clientats, :log_dir, "logs")
  end

  @doc """
  Get the archive directory path.
  """
  def archive_dir do
    Path.join(log_base_dir(), "archive")
  end

  defp ensure_directory_exists(category) when is_atom(category) do
    dir = Path.dirname(get_log_path(category, "dummy.json"))

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
