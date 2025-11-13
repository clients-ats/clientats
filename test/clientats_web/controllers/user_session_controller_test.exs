defmodule ClientatsWeb.UserSessionControllerTest do
  use ClientatsWeb.ConnCase

  describe "POST /login" do
    test "logs user in with valid credentials", %{conn: conn} do
      user = user_fixture(email: "test@example.com", password: "password123")

      conn =
        post(conn, ~p"/login", %{
          user: %{email: "test@example.com", password: "password123"}
        })

      assert redirected_to(conn) == ~p"/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Welcome back!"
      assert get_session(conn, :user_id) == user.id
    end

    test "shows error with invalid password", %{conn: conn} do
      user_fixture(email: "test@example.com", password: "password123")

      conn =
        post(conn, ~p"/login", %{
          user: %{email: "test@example.com", password: "wrongpassword"}
        })

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert get_session(conn, :user_id) == nil
    end

    test "shows error with non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/login", %{
          user: %{email: "nonexistent@example.com", password: "password123"}
        })

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert get_session(conn, :user_id) == nil
    end
  end

  describe "DELETE /logout" do
    test "logs user out", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = delete(conn, ~p"/logout")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Logged out successfully."
      assert get_session(conn, :user_id) == nil
    end

    test "works even if user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/logout")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Logged out successfully."
    end
  end

  describe "POST /login-after-registration" do
    test "logs user in after registration", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/login-after-registration", %{
          session: %{user_id: to_string(user.id)}
        })

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_id) == user.id
    end
  end

  defp user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }

    attrs = Enum.into(attrs, default_attrs)

    {:ok, user} = Clientats.Accounts.register_user(attrs)
    user
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
