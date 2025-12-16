defmodule Clientats.Jobs.GenericJobWorker do
  @moduledoc """
  Generic background job worker for miscellaneous async tasks.

  Handles:
  - Data exports
  - Bulk operations
  - Cleanup tasks
  - Notifications
  """

  use Oban.Worker, queue: :default, max_attempts: 3, timeout: 300_000

  require Logger

  alias Clientats.Audit

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    job_type = args["type"]
    user_id = args["user_id"]

    Logger.info("Processing #{job_type} job for user #{user_id}")

    case execute_job(job_type, args) do
      :ok ->
        Logger.info("Completed #{job_type} job")
        :ok

      {:error, reason} ->
        Logger.error("Failed to execute #{job_type}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Error in #{job_type}: #{inspect(e)}")
      {:error, Exception.message(e)}
  end

  defp execute_job("export_data", args) do
    user_id = args["user_id"]
    format = args["format"] || "json"
    days = args["days"] || 90

    Logger.info("Exporting data for user #{user_id} in #{format} format")

    case Clientats.Audit.export_audit_logs(user_id, String.to_atom(format), days: days) do
      {:ok, _data} ->
        Audit.log_action(%{
          user_id: user_id,
          action: "export",
          resource_type: "data_export",
          status: "success",
          metadata: %{"format" => format, "days" => days}
        })
        :ok

      {:error, reason} ->
        Audit.log_action(%{
          user_id: user_id,
          action: "export",
          resource_type: "data_export",
          status: "failure",
          error_message: to_string(reason),
          metadata: %{"format" => format}
        })
        {:error, reason}
    end
  end

  defp execute_job("cleanup_old_data", args) do
    retention_days = args["retention_days"] || 2555  # ~7 years

    Logger.info("Cleaning up data older than #{retention_days} days")

    case Clientats.Audit.cleanup_old_logs(div(retention_days, 365)) do
      {:ok, count} ->
        Logger.info("Cleaned up #{count} audit logs")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_job("send_notification", args) do
    user_id = args["user_id"]
    title = args["title"]
    message = args["message"]
    notification_type = args["type"] || "info"

    Logger.info("Sending #{notification_type} notification to user #{user_id}")

    # TODO: Implement actual notification logic
    # For now, just log it
    Audit.log_action(%{
      user_id: user_id,
      action: "notification_sent",
      resource_type: "notification",
      status: "success",
      metadata: %{
        "type" => notification_type,
        "title" => title,
        "message" => message
      }
    })

    :ok
  end

  defp execute_job(type, _args) do
    Logger.warning("Unknown job type: #{type}")
    {:error, :unknown_job_type}
  end
end
