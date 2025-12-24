defmodule ClientatsWeb.Plugs.ServeUploads do
  @moduledoc """
  Plug to serve uploaded files from a runtime-configurable directory.

  This allows uploads to be stored outside the priv/static directory,
  which is necessary for Tauri builds where the app bundle is read-only.
  """

  @behaviour Plug

  import Plug.Conn

  alias Clientats.Uploads

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/uploads/" <> _rest} = conn, _opts) do
    case Uploads.resolve_path(conn.request_path) do
      {:ok, file_path} ->
        serve_file(conn, file_path)

      {:error, :not_found} ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp serve_file(conn, file_path) do
    # Determine content type
    content_type = MIME.from_path(file_path)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000")
    |> send_file(200, file_path)
    |> halt()
  end
end
