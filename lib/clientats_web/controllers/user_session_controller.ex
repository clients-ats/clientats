defmodule ClientatsWeb.UserSessionController do
  use ClientatsWeb, :controller

  alias Clientats.Accounts

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> put_session(:user_id, user.id)
        |> redirect(to: ~p"/dashboard")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> put_flash(:email, email)
        |> redirect(to: ~p"/login")
    end
  end

  def create_after_registration(conn, %{"session" => %{"user_id" => user_id}}) do
    conn
    |> put_session(:user_id, String.to_integer(user_id))
    |> redirect(to: ~p"/")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> clear_session()
    |> redirect(to: ~p"/")
  end
end
