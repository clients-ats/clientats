defmodule ClientatsWeb.UserRegistrationLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      assert html =~ "Create your account"
      assert html =~ "Email"
      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Password"
      assert html =~ "Confirm Password"
    end

    test "redirects if already logged in", %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user)

      {:error, redirect} = live(conn, ~p"/register")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/dashboard"
    end

    test "shows link to login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      assert html =~ "Already have an account?"
      assert html =~ "Sign in"
    end
  end

  describe "register user" do
    test "creates account successfully", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            email: "test@example.com",
            password: "password123",
            password_confirmation: "password123",
            first_name: "John",
            last_name: "Doe"
          }
        )
        |> render_submit()

      assert result =~ "phx-trigger-action"

      user = Clientats.Repo.get_by(Clientats.Accounts.User, email: "test@example.com")
      assert user != nil
      assert user.first_name == "John"
      assert user.last_name == "Doe"
    end

    test "displays validation errors", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            email: "invalid",
            password: "short",
            password_confirmation: "different",
            first_name: "",
            last_name: ""
          }
        )
        |> render_submit()

      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 8 character"
      assert result =~ "does not match password"
      assert result =~ "can&#39;t be blank"
    end

    test "validates email format", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            email: "not-an-email",
            password: "password123",
            password_confirmation: "password123",
            first_name: "John",
            last_name: "Doe"
          }
        )
        |> render_submit()

      assert result =~ "must have the @ sign and no spaces"
    end

    test "validates unique email", %{conn: conn} do
      _user = user_fixture(email: "existing@example.com")

      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            email: "existing@example.com",
            password: "password123",
            password_confirmation: "password123",
            first_name: "Jane",
            last_name: "Doe"
          }
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end

    test "validates password length", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            email: "test@example.com",
            password: "short",
            password_confirmation: "short",
            first_name: "John",
            last_name: "Doe"
          }
        )
        |> render_submit()

      assert result =~ "should be at least 8 character"
    end

    test "validates password confirmation", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            email: "test@example.com",
            password: "password123",
            password_confirmation: "different",
            first_name: "John",
            last_name: "Doe"
          }
        )
        |> render_submit()

      assert result =~ "does not match password"
    end

    test "validates required fields", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#registration_form",
          user: %{
            email: "",
            password: "",
            password_confirmation: "",
            first_name: "",
            last_name: ""
          }
        )
        |> render_submit()

      assert result =~ "can&#39;t be blank"
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
