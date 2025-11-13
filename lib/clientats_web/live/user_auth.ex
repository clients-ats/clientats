defmodule ClientatsWeb.UserAuth do
  use ClientatsWeb, :verified_routes

  import Phoenix.LiveView
  import Phoenix.Component

  alias Clientats.Accounts

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = Accounts.get_user(user_id)

        if user do
          {:cont, assign(socket, :current_user, user)}
        else
          {:halt, redirect(socket, to: ~p"/login")}
        end

      %{} ->
        {:halt, redirect(socket, to: ~p"/login")}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = Accounts.get_user(user_id)

        if user do
          {:halt, redirect(socket, to: ~p"/dashboard")}
        else
          {:cont, socket}
        end

      %{} ->
        {:cont, socket}
    end
  end

  def on_mount(:fetch_current_user, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = Accounts.get_user(user_id)
        {:cont, assign(socket, :current_user, user)}

      %{} ->
        {:cont, assign(socket, :current_user, nil)}
    end
  end
end
