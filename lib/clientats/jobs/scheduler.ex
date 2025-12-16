defmodule Clientats.Jobs.Scheduler do
  @moduledoc """
  Job scheduler for ClientATS background jobs.

  Provides a unified interface for enqueueing jobs to the background queue.
  Supports different queues for different job types with automatic retries
  and error handling.

  ## Job Types

  - `scrape_job` - Scrape job data from URL (slow, long-running)
  - `export_data` - Export user data
  - `cleanup_old_data` - Clean up old audit logs
  - `send_notification` - Send user notification
  """

  require Logger

  alias Oban.Job
  alias Clientats.Repo

  @doc """
  Schedule a job scraping task.

  Options:
    - :mode - Extraction mode (default: "generic")
    - :provider - LLM provider to use
    - :save - Auto-save as job interest (default: false)
    - :schedule_in - Schedule for later (in seconds)
  """
  def schedule_scrape_job(url, user_id, opts \\ []) do
    mode = Keyword.get(opts, :mode, "generic")
    provider = Keyword.get(opts, :provider)
    save = Keyword.get(opts, :save, false)
    schedule_in = Keyword.get(opts, :schedule_in)

    job_args = %{
      "url" => url,
      "user_id" => user_id,
      "mode" => mode,
      "provider" => provider,
      "save" => save
    }

    Clientats.Jobs.ScrapeJobWorker.new(job_args)
    |> maybe_schedule_in(schedule_in)
    |> Repo.insert()
  end

  @doc """
  Export user data as background job.

  Options:
    - :format - Export format: :json or :csv (default: :json)
    - :days - Include last N days (default: 90)
    - :schedule_in - Schedule for later (in seconds)
  """
  def schedule_data_export(user_id, opts \\ []) do
    format = Keyword.get(opts, :format, "json")
    days = Keyword.get(opts, :days, 90)
    schedule_in = Keyword.get(opts, :schedule_in)

    job_args = %{
      "type" => "export_data",
      "user_id" => user_id,
      "format" => format,
      "days" => days
    }

    Clientats.Jobs.GenericJobWorker.new(job_args)
    |> maybe_schedule_in(schedule_in)
    |> Repo.insert()
  end

  @doc """
  Schedule data cleanup as background job.

  Options:
    - :retention_days - Keep logs for N days (default: 2555 for ~7 years)
    - :schedule_in - Schedule for later (in seconds)
  """
  def schedule_cleanup(opts \\ []) do
    retention_days = Keyword.get(opts, :retention_days, 2555)
    schedule_in = Keyword.get(opts, :schedule_in)

    job_args = %{
      "type" => "cleanup_old_data",
      "retention_days" => retention_days
    }

    Clientats.Jobs.GenericJobWorker.new(job_args)
    |> maybe_schedule_in(schedule_in)
    |> Repo.insert()
  end

  @doc """
  Send a notification as background job.

  Options:
    - :type - Notification type: "info", "warning", "error" (default: "info")
    - :schedule_in - Schedule for later (in seconds)
  """
  def schedule_notification(user_id, title, message, opts \\ []) do
    type = Keyword.get(opts, :type, "info")
    schedule_in = Keyword.get(opts, :schedule_in)

    job_args = %{
      "type" => "send_notification",
      "user_id" => user_id,
      "title" => title,
      "message" => message,
      "notification_type" => type
    }

    Clientats.Jobs.GenericJobWorker.new(job_args)
    |> maybe_schedule_in(schedule_in)
    |> Repo.insert()
  end

  @doc """
  Get job status.
  """
  def get_job_status(job_id) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      job ->
        {
          :ok,
          %{
            id: job.id,
            state: job.state,
            queue: job.queue,
            worker: job.worker,
            attempts: job.attempt,
            max_attempts: job.max_attempts,
            scheduled_at: job.scheduled_at,
            attempted_at: job.attempted_at,
            completed_at: job.completed_at,
            errors: job.errors
          }
        }
    end
  end

  @doc """
  Cancel a scheduled job.
  """
  def cancel_job(job_id) do
    case Repo.get(Job, job_id) do
      nil ->
        {:error, :not_found}

      job ->
        if job.state in ["scheduled", "available"] do
          Repo.delete(job)
        else
          {:error, :job_already_running}
        end
    end
  end

  @doc """
  Get all pending jobs for a queue.
  """
  def get_pending_jobs(queue \\ nil) do
    query =
      if queue do
        Job |> where([j], j.queue == ^queue and j.state in ["scheduled", "available"])
      else
        Job |> where([j], j.state in ["scheduled", "available"])
      end

    query
    |> order_by([j], desc: j.inserted_at)
    |> Repo.all()
  end

  @doc """
  Get job statistics.
  """
  def get_job_stats do
    %{
      pending: Repo.aggregate(Job.where(state: ["scheduled", "available"]), :count),
      processing: Repo.aggregate(Job.where(state: ["executing"]), :count),
      completed: Repo.aggregate(Job.where(state: ["completed"]), :count),
      failed: Repo.aggregate(Job.where(state: ["discarded"]), :count)
    }
  rescue
    _e ->
      %{pending: 0, processing: 0, completed: 0, failed: 0}
  end

  defp maybe_schedule_in(job, nil), do: job
  defp maybe_schedule_in(job, seconds) when is_integer(seconds) do
    Job.set_schedule(job, :timer.seconds(seconds))
  end
end
