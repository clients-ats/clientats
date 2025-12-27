defmodule Clientats.Audit do
  @moduledoc """
  Audit logging context for user activity and compliance tracking.
  """

  import Ecto.Query
  require Logger

  alias Clientats.Repo
  alias Clientats.Audit.AuditLog

  @doc """
  Log a user action asynchronously.
  """
  def log_action(attrs) do
    Task.start_link(fn ->
      log_action_sync(attrs)
    end)
  end

  @doc """
  Log a user action synchronously (waits for database write).
  """
  def log_action_sync(attrs) do
    case AuditLog.create_entry(attrs) |> Repo.insert() do
      {:ok, entry} ->
        Logger.info("Audit log: #{entry.action} on #{entry.resource_type}")
        {:ok, entry}

      {:error, changeset} ->
        Logger.error("Failed to create audit log: #{inspect(changeset)}")
        {:error, changeset}
    end
  end

  @doc """
  Log a user's sensitive action (create/update/delete).

  Options:
    - :conn - connection for IP/user agent extraction
    - :user_id - ID of user performing action
    - :old_values - previous field values (for updates)
    - :new_values - new field values
    - :description - human readable description
    - :metadata - additional context as map
    - :status - "success", "failure", or "partial"
    - :error_message - error details if status is failure
  """
  def log_resource_action(resource_type, action, resource_id, opts \\ []) do
    conn = opts[:conn]
    ip = if conn, do: AuditLog.extract_ip_address(conn), else: nil
    user_agent = if conn, do: AuditLog.extract_user_agent(conn), else: nil

    attrs = %{
      user_id: opts[:user_id],
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      description: opts[:description],
      ip_address: ip,
      user_agent: user_agent,
      old_values: opts[:old_values],
      new_values: opts[:new_values],
      status: opts[:status] || "success",
      error_message: opts[:error_message],
      metadata: opts[:metadata] || %{}
    }

    log_action_sync(attrs)
  end

  @doc """
  Log an authentication event.
  """
  def log_auth_event(user_id, action, conn, status \\ "success", error \\ nil) do
    attrs = %{
      user_id: user_id,
      action: action,
      resource_type: "auth",
      ip_address: AuditLog.extract_ip_address(conn),
      user_agent: AuditLog.extract_user_agent(conn),
      status: status,
      error_message: error,
      metadata: %{}
    }

    log_action_sync(attrs)
  end

  @doc """
  Log an API key event.
  """
  def log_api_key_event(user_id, action, provider, status \\ "success") do
    attrs = %{
      user_id: user_id,
      action: action,
      resource_type: "llm_settings",
      description: "API key #{action} for provider: #{provider}",
      status: status,
      metadata: %{"provider" => provider}
    }

    log_action_sync(attrs)
  end

  @doc """
  Log a data export event.
  """
  def log_export_event(user_id, export_type, status \\ "success") do
    attrs = %{
      user_id: user_id,
      action: "export",
      resource_type: "data_export",
      description: "Exported #{export_type} data for compliance",
      status: status,
      metadata: %{"export_type" => export_type}
    }

    log_action_sync(attrs)
  end

  @doc """
  Get audit logs for a user with filtering and pagination.

  Options:
    - :resource_type - filter by resource type
    - :action - filter by action type
    - :days - last N days (default: 90)
    - :limit - results per page (default: 50)
    - :offset - pagination offset (default: 0)
  """
  def get_user_audit_logs(user_id, opts \\ []) do
    days = opts[:days] || 90
    limit = opts[:limit] || 50
    offset = opts[:offset] || 0

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    query =
      AuditLog
      |> where([a], a.user_id == ^user_id)
      |> where([a], a.inserted_at >= ^cutoff)

    query =
      if opts[:resource_type] do
        where(query, [a], a.resource_type == ^opts[:resource_type])
      else
        query
      end

    query =
      if opts[:action] do
        where(query, [a], a.action == ^opts[:action])
      else
        query
      end

    query
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Get total count of audit logs for pagination.
  """
  def count_user_audit_logs(user_id, opts \\ []) do
    days = opts[:days] || 90
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    query =
      AuditLog
      |> where([a], a.user_id == ^user_id)
      |> where([a], a.inserted_at >= ^cutoff)

    query =
      if opts[:resource_type] do
        where(query, [a], a.resource_type == ^opts[:resource_type])
      else
        query
      end

    query =
      if opts[:action] do
        where(query, [a], a.action == ^opts[:action])
      else
        query
      end

    Repo.aggregate(query, :count)
  end

  @doc """
  Get all audit logs for a resource (admin view).
  """
  def get_resource_audit_logs(resource_type, resource_id) do
    AuditLog
    |> where([a], a.resource_type == ^resource_type and a.resource_id == ^resource_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Search audit logs by description or metadata.
  """
  def search_audit_logs(user_id, search_term, opts \\ []) do
    days = opts[:days] || 90
    limit = opts[:limit] || 50
    offset = opts[:offset] || 0

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)
    search_pattern = "%#{search_term}%"

    query =
      AuditLog
      |> where([a], a.user_id == ^user_id)
      |> where([a], a.inserted_at >= ^cutoff)
      |> where(
        [a],
        like(a.description, ^search_pattern) or like(a.action, ^search_pattern) or
          like(a.resource_type, ^search_pattern)
      )

    query
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Export audit logs for compliance (GDPR, CCPA).

  Returns data in requested format: :json, :csv
  """
  def export_audit_logs(user_id, format \\ :json, opts \\ []) do
    logs = get_user_audit_logs(user_id, opts)

    case format do
      :json ->
        {:ok, Jason.encode!(logs)}

      :csv ->
        {:ok, logs_to_csv(logs)}

      _ ->
        {:error, :invalid_format}
    end
  end

  defp logs_to_csv(logs) do
    headers = [
      "Timestamp",
      "Action",
      "Resource Type",
      "Resource ID",
      "Status",
      "Description",
      "IP Address",
      "User Agent",
      "Metadata"
    ]

    rows =
      Enum.map(logs, fn log ->
        [
          NaiveDateTime.to_iso8601(log.inserted_at),
          log.action,
          log.resource_type,
          log.resource_id || "",
          log.status,
          log.description || "",
          log.ip_address || "",
          log.user_agent || "",
          inspect(log.metadata)
        ]
      end)

    [headers | rows]
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.join("\n")
  end

  @doc """
  Delete audit logs older than retention period (admin only).

  Default retention: 7 years (per GDPR guidelines)
  """
  def cleanup_old_logs(retention_years \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_years * 365 * 24 * 3600, :second)

    {deleted_count, _} =
      AuditLog
      |> where([a], a.inserted_at < ^cutoff)
      |> Repo.delete_all()

    Logger.info("Deleted #{deleted_count} audit logs older than #{retention_years} years")
    {:ok, deleted_count}
  end

  @doc """
  Get audit statistics for user (useful for compliance reports).
  """
  def get_audit_statistics(user_id, days \\ 90) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    query = where(AuditLog, [a], a.user_id == ^user_id and a.inserted_at >= ^cutoff)

    %{
      total_actions: Repo.aggregate(query, :count),
      by_action: get_stats_by(query, :action),
      by_resource_type: get_stats_by(query, :resource_type),
      failures: Repo.aggregate(where(query, [a], a.status == "failure"), :count),
      last_activity: get_last_activity(query)
    }
  end

  defp get_stats_by(query, field) do
    query
    |> group_by([a], field(a, ^field))
    |> select([a], {field(a, ^field), count()})
    |> Repo.all()
    |> Enum.into(%{})
  end

  defp get_last_activity(query) do
    case query
         |> order_by([a], desc: a.inserted_at)
         |> limit(1)
         |> select([a], a.inserted_at)
         |> Repo.one() do
      nil -> nil
      timestamp -> NaiveDateTime.to_iso8601(timestamp)
    end
  end
end
