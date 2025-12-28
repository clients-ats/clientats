defmodule ClientatsWeb.ResumeController do
  use ClientatsWeb, :controller

  plug :fetch_current_user

  def download(conn, %{"id" => id}) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to download resumes")
        |> redirect(to: "/login")

      user ->
        download_resume(conn, id, user.id)
    end
  end

  defp download_resume(conn, id, user_id) do
    resume = Clientats.Repo.get(Clientats.Documents.Resume, id)

    cond do
      is_nil(resume) ->
        conn
        |> put_flash(:error, "Resume not found")
        |> redirect(to: ~p"/dashboard/resumes")

      resume.user_id != user_id ->
        conn
        |> put_flash(:error, "You don't have permission to download this resume")
        |> redirect(to: ~p"/dashboard/resumes")

      !resume.is_valid ->
        conn
        |> put_flash(:error, "Resume file is invalid or missing")
        |> redirect(to: ~p"/dashboard/resumes")

      true ->
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
  end

  defp mime_type(filename) do
    MIME.from_path(filename)
  end

  defp fetch_current_user(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil)

      user_id ->
        user = Clientats.Accounts.get_user(user_id)
        assign(conn, :current_user, user)
    end
  end
end
