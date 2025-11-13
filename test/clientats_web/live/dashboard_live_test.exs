defmodule ClientatsWeb.DashboardLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "dashboard page" do
    test "redirects to login if not authenticated", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/dashboard")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "renders dashboard when authenticated", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Clientats Dashboard"
      assert html =~ user.first_name
      assert html =~ user.last_name
    end

    test "displays user name in header", %{conn: conn} do
      user = user_fixture(first_name: "John", last_name: "Doe")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "John Doe"
    end

    test "shows logout link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Logout"
    end

    test "displays job interests section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Job Interests"
      assert html =~ "Add Interest"
    end

    test "displays applications section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Applications"
      assert html =~ "Add Application"
    end

    test "shows placeholder when no data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "No job interests yet"
      assert html =~ "No applications yet"
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
