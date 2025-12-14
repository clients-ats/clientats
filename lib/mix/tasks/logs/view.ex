defmodule Mix.Tasks.Logs.View do
  @moduledoc """
  Mix task to view and search logs.

  Usage:
    mix logs.view                     # View cleanup stats
    mix logs.view --provider ollama   # View Ollama LLM logs
    mix logs.view --provider job_interest  # View job interest form logs
    mix logs.view --type llm_requests # View all LLM request logs
    mix logs.view --type form_data    # View all form submission logs
    mix logs.view --type playwright   # View Playwright screenshot logs
    mix logs.view --days 3            # View logs from last 3 days
    mix logs.view --failed            # View failed LLM requests
  """

  use Mix.Task
  require Logger

  @impl Mix.Task
  def run(args) do
    {:ok, _} = Application.ensure_all_started(:clientats)

    {opts, _args, _invalid} =
      OptionParser.parse(args,
        switches: [provider: :string, type: :string, days: :integer, failed: :boolean]
      )

    if Keyword.get(opts, :failed) do
      view_failed_llm_requests()
    else
      case Keyword.fetch(opts, :type) do
        {:ok, "llm_requests"} ->
          view_llm_logs(opts)

        {:ok, "form_data"} ->
          view_form_logs(opts)

        {:ok, "playwright"} ->
          view_playwright_logs(opts)

        :error ->
          view_cleanup_stats()
      end
    end
  end

  defp view_cleanup_stats do
    IO.puts("\n📊 Log Cleanup Statistics\n")

    stats = Clientats.Logging.LogCleanup.get_cleanup_stats()

    Enum.each(stats, fn {category, category_stats} ->
      IO.puts("#{inspect(category)}:")
      IO.puts("  Files: #{category_stats.file_count}")
      IO.puts("  Size: #{category_stats.total_size_mb} MB")

      if category_stats.oldest_date do
        IO.puts("  Oldest: #{category_stats.oldest_date}")
      end

      IO.puts("")
    end)
  end

  defp view_llm_logs(opts) do
    IO.puts("\n📝 LLM Request Logs\n")

    days = Keyword.get(opts, :days, 7)
    provider = Keyword.get(opts, :provider)

    logs =
      if provider do
        provider_atom = String.to_atom(provider)
        Clientats.Logging.LLMLogger.get_provider_logs(provider_atom)
      else
        Clientats.Logging.LLMLogger.get_recent_requests(days)
      end

    if Enum.empty?(logs) do
      IO.puts("No logs found")
    else
      IO.puts("Found #{Enum.count(logs)} request(s)\n")

      Enum.each(logs, fn log ->
        IO.puts("  Provider: #{log["provider"]}")
        IO.puts("  Model: #{log["model"]}")
        IO.puts("  Timestamp: #{log["timestamp"]}")
        IO.puts("  Latency: #{log["latency_ms"]}ms")
        IO.puts("  Success: #{log["success"]}")
        IO.puts("")
      end)
    end

    IO.puts("\n📊 Usage Statistics\n")
    stats = Clientats.Logging.LLMLogger.get_usage_stats()

    Enum.each(stats, fn stat ->
      IO.puts("#{stat["provider"]} - #{stat["model"]}")
      IO.puts("  Total Requests: #{stat["total_requests"]}")
      IO.puts("  Success Rate: #{Float.round(stat["success_rate"] * 100, 1)}%")
      IO.puts("  Avg Latency: #{Float.round(stat["avg_latency_ms"], 0)}ms")
      IO.puts("")
    end)
  end

  defp view_form_logs(opts) do
    IO.puts("\n📋 Form Submission Logs\n")

    days = Keyword.get(opts, :days, 7)
    provider = Keyword.get(opts, :provider)

    logs =
      if provider do
        Clientats.Logging.Utils.search_by_provider(:form_data, provider)
      else
        Clientats.Logging.Utils.logs_from_last_days(:form_data, days)
      end

    if Enum.empty?(logs) do
      IO.puts("No logs found")
    else
      IO.puts("Found #{Enum.count(logs)} submission(s)\n")

      Enum.each(logs, fn log ->
        IO.puts("  Provider: #{log["provider"]}")
        IO.puts("  User ID: #{log["user_id"]}")
        IO.puts("  Timestamp: #{log["timestamp"]}")
        IO.puts("  Filename: #{log["filename"]}")
        IO.puts("")
      end)
    end
  end

  defp view_playwright_logs(opts) do
    IO.puts("\n🎬 Playwright Screenshot Logs\n")

    days = Keyword.get(opts, :days, 7)

    logs = Clientats.Logging.Utils.logs_from_last_days(:playwright_screenshots, days)

    if Enum.empty?(logs) do
      IO.puts("No logs found")
    else
      IO.puts("Found #{Enum.count(logs)} screenshot(s)\n")

      Enum.each(logs, fn log ->
        IO.puts("  Test: #{log["test_name"]}")
        IO.puts("  URL: #{log["url"]}")
        IO.puts("  Timestamp: #{log["timestamp"]}")
        IO.puts("  Type: #{log["type"]}")
        IO.puts("  Filename: #{log["filename"]}")
        IO.puts("")
      end)
    end
  end

  defp view_failed_llm_requests do
    IO.puts("\n❌ Failed LLM Requests\n")

    logs = Clientats.Logging.LLMLogger.get_failed_requests()

    if Enum.empty?(logs) do
      IO.puts("No failed requests")
    else
      IO.puts("Found #{Enum.count(logs)} failed request(s)\n")

      Enum.each(logs, fn log ->
        IO.puts("  Provider: #{log["provider"]}")
        IO.puts("  Model: #{log["model"]}")
        IO.puts("  Timestamp: #{log["timestamp"]}")
        IO.puts("  Error Type: #{log["error_type"]}")
        IO.puts("  Filename: #{log["filename"]}")
        IO.puts("")
      end)
    end
  end
end
