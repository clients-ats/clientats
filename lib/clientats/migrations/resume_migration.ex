defmodule Clientats.Migrations.ResumeMigration do
  @moduledoc """
  Migrates legacy resume files from the filesystem into the database.
  """
  require Logger
  alias Clientats.Repo
  alias Clientats.Documents.Resume
  alias Clientats.Uploads

  def run do
    Logger.info("Starting resume migration from filesystem to database...")

    resumes = 
      Resume
      |> Ecto.Query.where([r], is_nil(r.data))
      |> Repo.all()

    total = length(resumes)
    
    if total > 0 do
      Logger.info("Found #{total} resumes to migrate.")
      
      Enum.each(resumes, fn resume ->
        migrate_resume(resume)
      end)
      
      Logger.info("Resume migration completed.")
    else
      Logger.info("No resumes found requiring migration.")
    end
  end

  defp migrate_resume(resume) do
    case Uploads.resolve_path(resume.file_path) do
      {:ok, path} ->
        case File.read(path) do
          {:ok, content} ->
            resume
            |> Ecto.Changeset.change(data: content, is_valid: true)
            |> Repo.update()
            |> case do
              {:ok, _} -> 
                Logger.info("Successfully migrated resume #{resume.id}: #{resume.name}")
              {:error, reason} ->
                Logger.error("Failed to update resume #{resume.id} in DB: #{inspect(reason)}")
            end

          {:error, reason} ->
            Logger.warning("Could not read file for resume #{resume.id} at #{path}: #{inspect(reason)}. Marking as invalid.")
            mark_invalid(resume)
        end

      {:error, _} ->
        Logger.warning("Could not resolve path for resume #{resume.id}: #{resume.file_path}. Marking as invalid.")
        mark_invalid(resume)
    end
  end

  defp mark_invalid(resume) do
    resume
    |> Ecto.Changeset.change(is_valid: false)
    |> Repo.update()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} ->
        Logger.error("Failed to mark resume #{resume.id} as invalid: #{inspect(reason)}")
    end
  end
end
