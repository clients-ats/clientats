defmodule Clientats.Logging.LogCleanup do
  @moduledoc """
  Log cleanup and archival utilities.

  Manages log file lifecycle - keeps recent logs and archives old ones.
  """

  alias Clientats.Logging.LogWriter
  require Logger

  @doc """
  Clean up logs older than the specified number of days.

  Parameters:
  - days_to_keep: number of days to keep (default: 7)
  - archive: whether to archive old logs instead of deleting (default: true)

  Returns: {:ok, %{deleted: count, archived: count}} or {:error, reason}
  """
  def cleanup_logs(days_to_keep \\ 7, archive \\ true) do
    Logger.info(
      "Starting log cleanup (keeping logs from last #{days_to_keep} days, archive=#{archive})"
    )

    cutoff_time = DateTime.utc_now() |> DateTime.add(-days_to_keep * 24 * 3600)

    categories = [:form_data, :llm_requests, :playwright_screenshots]
    results = Enum.map(categories, &cleanup_category(&1, cutoff_time, archive))

    stats =
      Enum.reduce(results, %{deleted: 0, archived: 0, errors: []}, fn
        {:ok, category_stats}, acc ->
          acc
          |> Map.update!(:deleted, &(&1 + category_stats[:deleted]))
          |> Map.update!(:archived, &(&1 + category_stats[:archived]))

        {:error, error}, acc ->
          Map.update!(acc, :errors, &[error | &1])
      end)

    case stats.errors do
      [] ->
        Logger.info(
          "Cleanup completed: deleted #{stats.deleted} files, archived #{stats.archived} files"
        )

        {:ok, stats}

      errors ->
        Logger.warning("Cleanup completed with errors: #{inspect(errors)}")
        {:ok, stats}
    end
  end

  @doc """
  Archive logs from a specific category.

  Parameters:
  - category: :form_data, :llm_requests, or :playwright_screenshots
  - days_threshold: days old to archive (default: 7)

  Returns: {:ok, count} or {:error, reason}
  """
  def archive_category(category, days_threshold \\ 7) when is_atom(category) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-days_threshold * 24 * 3600)

    try do
      category_dir = LogWriter.get_log_path(category, "")

      old_files =
        File.ls!(category_dir)
        |> Enum.filter(fn filename ->
          not String.starts_with?(filename, ".")
        end)
        |> Enum.filter(fn filename ->
          filepath = Path.join(category_dir, filename)

          case File.stat(filepath) do
            {:ok, stat} ->
              DateTime.compare(DateTime.from_unix!(stat.mtime, :second), cutoff_time) in [
                :eq,
                :lt
              ]

            {:error, _} ->
              false
          end
        end)

      archive_old_files(category_dir, old_files, cutoff_time)
    rescue
      e ->
        Logger.error("Error archiving category #{category}: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Delete logs older than the specified number of days.

  Parameters:
  - category: :form_data, :llm_requests, or :playwright_screenshots
  - days_threshold: days old to delete (default: 30)

  Returns: {:ok, count} or {:error, reason}
  """
  def delete_old_logs(category, days_threshold \\ 30) when is_atom(category) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-days_threshold * 24 * 3600)

    try do
      category_dir = LogWriter.get_log_path(category, "")

      deleted_count =
        File.ls!(category_dir)
        |> Enum.reduce(0, fn filename, count ->
          if String.starts_with?(filename, ".") do
            count
          else
            filepath = Path.join(category_dir, filename)

            case File.stat(filepath) do
              {:ok, stat} ->
                if DateTime.compare(DateTime.from_unix!(stat.mtime, :second), cutoff_time) in [
                     :eq,
                     :lt
                   ] do
                  File.rm!(filepath)
                  Logger.debug("Deleted old log: #{filepath}")
                  count + 1
                else
                  count
                end

              {:error, _} ->
                count
            end
          end
        end)

      Logger.info("Deleted #{deleted_count} old log files from #{category}")
      {:ok, deleted_count}
    rescue
      e ->
        Logger.error("Error deleting old logs for #{category}: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Get cleanup statistics for all log categories.

  Returns: map with file counts and sizes
  """
  def get_cleanup_stats do
    categories = [:form_data, :llm_requests, :playwright_screenshots]

    Enum.reduce(categories, %{}, fn category, acc ->
      category_stats = get_category_stats(category)
      Map.put(acc, category, category_stats)
    end)
  end

  defp cleanup_category(category, cutoff_time, archive) do
    try do
      category_dir = LogWriter.get_log_path(category, "")

      result =
        File.ls!(category_dir)
        |> Enum.reduce(%{deleted: 0, archived: 0}, fn filename, acc ->
          if String.starts_with?(filename, ".") do
            acc
          else
            filepath = Path.join(category_dir, filename)

            case File.stat(filepath) do
              {:ok, stat} ->
                if DateTime.compare(DateTime.from_unix!(stat.mtime, :second), cutoff_time) in [
                     :eq,
                     :lt
                   ] do
                  if archive do
                    case archive_file(filepath, category) do
                      :ok ->
                        File.rm!(filepath)
                        Map.update!(acc, :archived, &(&1 + 1))

                      {:error, reason} ->
                        Logger.warning("Failed to archive #{filepath}: #{inspect(reason)}")
                        acc
                    end
                  else
                    File.rm!(filepath)
                    Map.update!(acc, :deleted, &(&1 + 1))
                  end
                else
                  acc
                end

              {:error, _} ->
                acc
            end
          end
        end)

      {:ok, result}
    rescue
      e ->
        Logger.error("Error cleaning up category #{category}: #{inspect(e)}")
        {:error, e}
    end
  end

  defp archive_old_files(category_dir, files, _cutoff_time) do
    archive_base = LogWriter.archive_dir()
    File.mkdir_p!(archive_base)

    # Create date-based subdirectory in archive
    date = DateTime.utc_now() |> Date.to_string()
    archive_date_dir = Path.join(archive_base, date)
    File.mkdir_p!(archive_date_dir)

    deleted_count =
      Enum.reduce(files, 0, fn filename, count ->
        src = Path.join(category_dir, filename)
        dest = Path.join(archive_date_dir, filename)

        case File.cp(src, dest) do
          :ok ->
            File.rm!(src)
            Logger.debug("Archived: #{filename}")
            count + 1

          {:error, reason} ->
            Logger.warning("Failed to archive #{filename}: #{inspect(reason)}")
            count
        end
      end)

    {:ok, deleted_count}
  end

  defp archive_file(filepath, _category) do
    archive_base = LogWriter.archive_dir()
    File.mkdir_p!(archive_base)

    date = DateTime.utc_now() |> Date.to_string()
    category_archive_dir = Path.join(archive_base, date)
    File.mkdir_p!(category_archive_dir)

    filename = Path.basename(filepath)
    dest = Path.join(category_archive_dir, filename)

    File.cp(filepath, dest)
  end

  defp get_category_stats(category) do
    try do
      category_dir = LogWriter.get_log_path(category, "dummy.json") |> Path.dirname()

      stats =
        File.ls!(category_dir)
        |> Enum.reduce(%{file_count: 0, total_size: 0, oldest_file: nil}, fn filename, acc ->
          if String.starts_with?(filename, ".") do
            acc
          else
            filepath = Path.join(category_dir, filename)

            case File.stat(filepath) do
              {:ok, stat} ->
                acc
                |> Map.update!(:file_count, &(&1 + 1))
                |> Map.update!(:total_size, &(&1 + stat.size))
                |> Map.update!(:oldest_file, fn oldest ->
                  if is_nil(oldest) or stat.mtime < oldest do
                    stat.mtime
                  else
                    oldest
                  end
                end)

              {:error, _} ->
                acc
            end
          end
        end)

      oldest_date =
        if stats.oldest_file do
          # stat.mtime is an Erlang universal_time tuple {{Y,M,D},{H,M,S}}
          case stats.oldest_file do
            {{_, _, _}, {_, _, _}} = erl_datetime ->
              DateTime.from_naive!(NaiveDateTime.from_erl!(erl_datetime), "Etc/UTC")
              |> DateTime.to_iso8601()

            _other ->
              nil
          end
        else
          nil
        end

      stats
      |> Map.delete(:oldest_file)
      |> Map.put(:oldest_date, oldest_date)
      |> Map.put(:total_size_mb, Float.round(stats.total_size / 1024 / 1024, 2))
    rescue
      e ->
        Logger.debug("Error getting category stats for #{category}: #{inspect(e)}")
        %{file_count: 0, total_size: 0, total_size_mb: 0.0, oldest_date: nil}
    end
  end
end
