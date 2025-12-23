defmodule Clientats.Workers.BackupWorker do
  @moduledoc """
  Oban worker for performing nightly backups of the SQLite database and exporting data to JSON.
  """
  use Oban.Worker, queue: :low, max_attempts: 3

  require Logger
  alias Clientats.Repo
  alias Clientats.Accounts.User
  alias Clientats.DataExport

  @impl Oban.Worker
  def perform(_job) do
    config_dir = Clientats.Platform.config_dir()
    backup_dir = Path.join(config_dir, "backups")
    Clientats.Platform.ensure_dir(backup_dir)

    date_str = Date.utc_today() |> Date.to_iso8601(:basic)
    
    with :ok <- backup_database(backup_dir, date_str),
         :ok <- export_json_data(backup_dir, date_str),
         :ok <- rotate_backups(backup_dir) do
      Logger.info("Nightly backup (SQLite + JSON) completed successfully for #{date_str}")
      :ok
    else
      {:error, reason} ->
        Logger.error("Nightly backup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp backup_database(backup_dir, date_str) do
    db_path = Clientats.Platform.database_path()
    dest_path = Path.join(backup_dir, "clientats_#{date_str}.db")

    if File.exists?(db_path) do
      case File.cp(db_path, dest_path) do
        :ok -> :ok
        {:error, reason} -> {:error, "Database backup failed: #{inspect(reason)}"}
      end
    else
      Logger.warning("Database file not found at #{db_path}, skipping database backup.")
      :ok
    end
  end

  defp export_json_data(backup_dir, date_str) do
    # Export data for all users
    users = Repo.all(User)
    
    results = Enum.map(users, fn user ->
      data = DataExport.export_user_data(user.id)
      # Sanitize email for filename
      safe_email = String.replace(user.email, ~r/[^a-zA-Z0-9]/, "_")
      filename = "export_#{date_str}_#{safe_email}.json"
      dest_path = Path.join(backup_dir, filename)
      
      case Jason.encode(data, pretty: true) do
        {:ok, json} ->
          File.write(dest_path, json)
        {:error, reason} ->
          {:error, "JSON encoding failed for user #{user.email}: #{inspect(reason)}"}
      end
    end)

    if Enum.all?(results, &(&1 == :ok)) do
      :ok
    else
      first_error = Enum.find(results, fn r -> match?({:error, _}, r) end)
      first_error || {:error, "Failed to export some user data to JSON"}
    end
  end

  defp rotate_backups(backup_dir) do
    # Keep last 2 days of backups
    files = File.ls!(backup_dir)
    
    # Extract dates from filenames (e.g., clientats_20251223.db or export_20251223_...)
    dates = files
    |> Enum.map(fn f -> 
      case Regex.run(~r/(\d{8})/, f) do
        [_, date] -> date
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort(:desc)

    # Dates to keep (top 2)
    to_keep = Enum.take(dates, 2)
    
    # Files to delete (those that don't match any of the dates to keep)
    files_to_delete = Enum.filter(files, fn f ->
      date_in_file = case Regex.run(~r/(\d{8})/, f) do
        [_, date] -> date
        _ -> nil
      end
      
      date_in_file != nil and date_in_file not in to_keep
    end)

    Enum.each(files_to_delete, fn f ->
      path = Path.join(backup_dir, f)
      Logger.info("Rotating old backup: #{path}")
      File.rm(path)
    end)

    :ok
  end
end