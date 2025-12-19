defmodule ClientatsWeb.DataExportController do
  use ClientatsWeb, :controller

  alias Clientats.DataExport
  alias Clientats.Accounts

  plug :fetch_current_user

  @doc """
  Exports all user data as a downloadable JSON file.
  Requires authentication.
  """
  def export(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to export data")
        |> redirect(to: "/login")

      user ->
        data = DataExport.export_user_data(user.id)
        filename = "clientats_export_#{Date.utc_today()}.json"

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> json(data)
    end
  end

  defp fetch_current_user(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        assign(conn, :current_user, nil)

      user_id ->
        user = Accounts.get_user(user_id)
        assign(conn, :current_user, user)
    end
  end
end
