defmodule Mix.Tasks.Logs.Cleanup do
  @moduledoc """
  Mix task to clean up old log files.

  Usage:
    mix logs.cleanup                  # Keep logs from last 7 days, archive old ones
    mix logs.cleanup --days 14        # Keep logs from last 14 days
    mix logs.cleanup --days 30 --no-archive  # Keep logs from last 30 days, delete (don't archive)
  """

  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(args) do
    {:ok, _} = Application.ensure_all_started(:clientats)

    {opts, _args, _invalid} =
      OptionParser.parse(args, options: [days: :integer, archive: :boolean])

    days_to_keep = Keyword.get(opts, :days, 7)
    archive = Keyword.get(opts, :archive, true)

    Logger.info("Starting log cleanup task...")

    case Clientats.Logging.LogCleanup.cleanup_logs(days_to_keep, archive) do
      {:ok, stats} ->
        Logger.info("✓ Cleanup successful!")
        Logger.info("  - Deleted: #{stats.deleted} files")
        Logger.info("  - Archived: #{stats.archived} files")

      {:error, reason} ->
        Logger.error("✗ Cleanup failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
