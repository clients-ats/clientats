defmodule ClientatsWeb.UserLoginLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Sign in to your account"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "redirects if already logged in", %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user)

      {:error, redirect} = live(conn, ~p"/login")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/dashboard"
    end

    test "shows link to registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Don&#39;t have an account?"
      assert html =~ "Sign up"
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
