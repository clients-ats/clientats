defmodule Clientats.Logging.PlaywrightLogger do
  @moduledoc """
  Logging handler for Playwright test screenshots and snapshots.

  This module provides utilities to log Playwright test artifacts for debugging purposes.
  """

  alias Clientats.Logging.{LogWriter, Timestamp, Utils}
  require Logger

  @doc """
  Log a Playwright test screenshot.

  Parameters:
  - test_name: name of the test
  - screenshot_path: path to the screenshot file
  - page_url: URL of the page when screenshot was taken
  - metadata: optional metadata (step, action, expected_result, etc.)

  Returns: {:ok, filename} or {:error, reason}
  """
  def log_screenshot(test_name, screenshot_path, page_url, metadata \\ %{}) do
    case File.exists?(screenshot_path) do
      true ->
        log_screenshot_internal(test_name, screenshot_path, page_url, metadata)

      false ->
        Logger.warning("Screenshot file not found: #{screenshot_path}")
        {:error, :file_not_found}
    end
  end

  @doc """
  Log a Playwright accessibility snapshot.

  Parameters:
  - test_name: name of the test
  - snapshot_path: path to the snapshot JSON file
  - page_url: URL of the page when snapshot was taken
  - metadata: optional metadata

  Returns: {:ok, filename} or {:error, reason}
  """
  def log_snapshot(test_name, snapshot_path, page_url, metadata \\ %{}) do
    case File.exists?(snapshot_path) do
      true ->
        log_snapshot_internal(test_name, snapshot_path, page_url, metadata)

      false ->
        Logger.warning("Snapshot file not found: #{snapshot_path}")
        {:error, :file_not_found}
    end
  end

  @doc """
  Log multiple artifacts from a single test.

  Parameters:
  - test_name: name of the test
  - artifacts: list of %{type: :screenshot | :snapshot, path: "...", url: "..."}
  - metadata: optional common metadata

  Returns: {:ok, filenames} or {:error, reason}
  """
  def log_test_artifacts(test_name, artifacts, metadata \\ %{}) do
    results =
      Enum.map(artifacts, fn artifact ->
        case artifact do
          %{type: :screenshot, path: path, url: url} ->
            log_screenshot(test_name, path, url, Map.merge(metadata, artifact))

          %{type: :snapshot, path: path, url: url} ->
            log_snapshot(test_name, path, url, Map.merge(metadata, artifact))

          _ ->
            {:error, :invalid_artifact}
        end
      end)

    case Enum.filter(results, fn {status, _} -> status == :error end) do
      [] -> {:ok, Enum.map(results, fn {:ok, name} -> name end)}
      errors -> {:error, errors}
    end
  end

  @doc """
  Get all logged screenshots for a test.

  Returns: list of screenshot entries from index
  """
  def get_test_screenshots(test_name) do
    entries = LogWriter.read_index(:playwright_screenshots, "index.json")

    Enum.filter(entries, fn entry ->
      String.contains?(entry["test_name"], test_name)
    end)
  end

  @doc """
  Get all logged screenshots for the last N days.

  Returns: list of screenshot entries
  """
  def get_recent_screenshots(days \\ 7) do
    Utils.logs_from_last_days(:playwright_screenshots, days)
  end

  defp log_screenshot_internal(test_name, screenshot_path, page_url, metadata) do
    timestamp = Timestamp.filename_safe_now(:microsecond)
    safe_test_name = sanitize_name(test_name)
    filename = "#{timestamp}_#{safe_test_name}.json"

    log_entry = %{
      "timestamp" => Timestamp.iso8601_now(),
      "timestamp_unix_ms" => Timestamp.unix_ms_now(),
      "test_name" => test_name,
      "url" => page_url,
      "screenshot_path" => screenshot_path,
      "screenshot_filename" => Path.basename(screenshot_path),
      "type" => "screenshot",
      "metadata" => metadata
    }

    with {:ok, _path} <- LogWriter.write_log(:playwright_screenshots, filename, log_entry),
         {:ok, _path} <-
           LogWriter.append_index(:playwright_screenshots, "index.json", %{
             "timestamp" => log_entry["timestamp"],
             "test_name" => test_name,
             "url" => page_url,
             "screenshot_filename" => Path.basename(screenshot_path),
             "type" => "screenshot",
             "filename" => filename
           }) do
      {:ok, filename}
    else
      {:error, reason} ->
        Logger.error("Failed to log Playwright screenshot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp log_snapshot_internal(test_name, snapshot_path, page_url, metadata) do
    timestamp = Timestamp.filename_safe_now(:microsecond)
    safe_test_name = sanitize_name(test_name)
    filename = "#{timestamp}_#{safe_test_name}_snapshot.json"

    log_entry = %{
      "timestamp" => Timestamp.iso8601_now(),
      "timestamp_unix_ms" => Timestamp.unix_ms_now(),
      "test_name" => test_name,
      "url" => page_url,
      "snapshot_path" => snapshot_path,
      "snapshot_filename" => Path.basename(snapshot_path),
      "type" => "snapshot",
      "metadata" => metadata
    }

    with {:ok, _path} <- LogWriter.write_log(:playwright_screenshots, filename, log_entry),
         {:ok, _path} <-
           LogWriter.append_index(:playwright_screenshots, "index.json", %{
             "timestamp" => log_entry["timestamp"],
             "test_name" => test_name,
             "url" => page_url,
             "snapshot_filename" => Path.basename(snapshot_path),
             "type" => "snapshot",
             "filename" => filename
           }) do
      {:ok, filename}
    else
      {:error, reason} ->
        Logger.error("Failed to log Playwright snapshot: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp sanitize_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "_")
    |> String.slice(0..64)
  end
end
