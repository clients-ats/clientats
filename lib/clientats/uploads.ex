defmodule Clientats.Uploads do
  @moduledoc """
  Handles file upload storage with support for configurable upload directories.

  In development, files are stored in priv/static/uploads.
  In Tauri production builds, files are stored in the app data directory
  via the UPLOAD_DIR environment variable.
  """

  @doc """
  Returns the base directory for uploads.

  Uses UPLOAD_DIR environment variable if set, otherwise falls back to
  priv/static/uploads for development compatibility.
  """
  def upload_dir do
    case System.get_env("UPLOAD_DIR") do
      nil ->
        # Development fallback
        Path.join([:code.priv_dir(:clientats), "static", "uploads"])

      dir ->
        dir
    end
  end

  @doc """
  Returns the full path for storing a resume file.
  """
  def resume_path(filename) do
    Path.join([upload_dir(), "resumes", filename])
  end

  @doc """
  Returns the URL path for accessing an uploaded file.
  """
  def url_path(subdir, filename) do
    "/uploads/#{subdir}/#{filename}"
  end

  @doc """
  Ensures the upload directory exists.
  """
  def ensure_dir!(subdir) do
    dir = Path.join(upload_dir(), subdir)
    File.mkdir_p!(dir)
    dir
  end

  @doc """
  Resolves a URL path like /uploads/resumes/file.pdf to the actual file path.
  Returns {:ok, path} if file exists, {:error, :not_found} otherwise.
  """
  def resolve_path(url_path) do
    case url_path do
      "/uploads/" <> rest ->
        file_path = Path.join(upload_dir(), rest)

        if File.exists?(file_path) do
          {:ok, file_path}
        else
          {:error, :not_found}
        end

      _ ->
        {:error, :not_found}
    end
  end
end
