defmodule ClientatsWeb.ResumeController do
  use ClientatsWeb, :controller
  alias Clientats.Documents

  def download(conn, %{"id" => id}) do
    resume = Documents.get_resume!(id)

    # Check if data exists in DB
    content = 
      if resume.data do
        resume.data
      else
        # Fallback to file system
        case Clientats.Uploads.resolve_path(resume.file_path) do
          {:ok, path} ->
            case File.read(path) do
              {:ok, data} -> data
              _ -> nil
            end
          _ -> nil
        end
      end

    if content do
      conn
      |> put_resp_content_type(mime_type(resume.original_filename))
      |> put_resp_header("content-disposition", "attachment; filename=\"#{resume.original_filename}\"")
      |> send_resp(200, content)
    else
      conn
      |> put_flash(:error, "Resume file not found")
      |> redirect(to: ~p"/dashboard/resumes")
    end
  end

  defp mime_type(filename) do
    MIME.from_path(filename)
  end
end
