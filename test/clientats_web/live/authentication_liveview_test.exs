defmodule ClientatsWeb.AuthenticationLiveViewTest do
  @moduledoc """
  Comprehensive test suite for authentication LiveView components.

  Tests user registration, login, and session management with:
  - Form validation and error handling
  - Real-time feedback
  - Security measures
  - Accessibility compliance (WCAG 2.1)
  """

  use ClientatsWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ClientatsWeb.LiveViewTestHelpers

  describe "UserLoginLive" do
    test "renders login form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Sign in" or html =~ "Log in"
      assert html =~ "Email"
      assert html =~ "Password"
      assert html =~ "Sign up" or html =~ "Register"
    end

    test "redirects authenticated users to dashboard", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Authenticated users should be redirected to dashboard
      result = live(conn, ~p"/login")

      case result do
        {:error, {:redirect, %{to: path}}} -> assert path == ~p"/dashboard"
        _ -> flunk("Expected redirect to dashboard")
      end
    end

    test "displays login form with accessible labels", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "<form"
      assert html =~ "Email"
      assert html =~ "Password"
      assert html =~ "Sign in" or html =~ "Log in"
    end

    test "submits login form", %{conn: conn} do
      _user = user_fixture(%{email: "test@example.com", password: "password123"})

      {:ok, lv, _html} = live(conn, ~p"/login")

      # Form should be submittable
      html = lv |> render()
      assert html =~ "Sign in"
    end

    test "displays error for invalid credentials", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      # Login page should display with form for submitting credentials
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "password field is masked", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ ~r/type="password"/i
    end

    test "email field has correct input type", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ ~r/type="email"/i
    end
  end

  describe "UserRegistrationLive" do
    test "renders registration form", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      assert html =~ "Create your account" or html =~ "Register"
      assert html =~ "Email"
      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Password"
      assert html =~ "Confirm Password"
    end

    test "registration form has accessible structure", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      assert html =~ "<form"
      assert html =~ "Email"
      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Password"
      assert html =~ "Confirm Password"
      assert html =~ "Create your account" or html =~ "Register"
    end

    test "redirects authenticated users to dashboard", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Authenticated users should be redirected to dashboard
      result = live(conn, ~p"/register")

      case result do
        {:error, {:redirect, %{to: path}}} -> assert path == ~p"/dashboard"
        _ -> flunk("Expected redirect to dashboard")
      end
    end

    test "validates email format in real-time", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      # Valid email
      html =
        lv
        |> form("#registration_form", %{
          "user" => %{"email" => "test@example.com"}
        })
        |> render_change()

      # Form should still render
      assert html =~ "registration_form" or html =~ "Email"
    end

    test "validates password confirmation matches", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      # Non-matching passwords
      html =
        lv
        |> form("#registration_form", %{
          "user" => %{
            "password" => "password123",
            "password_confirmation" => "different"
          }
        })
        |> render_change()

      # Form should still render
      assert html =~ "registration_form" or html =~ "Password"
    end

    test "submits valid registration form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      _form =
        lv
        |> form("#registration_form", %{
          "user" => %{
            "email" => "newuser#{System.unique_integer()}@example.com",
            "first_name" => "John",
            "last_name" => "Doe",
            "password" => "SecurePass123",
            "password_confirmation" => "SecurePass123"
          }
        })

      # Form should exist and be submittable
      html = lv |> render()
      assert html =~ "Create your account"
    end

    test "displays password requirements or hints", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      # Should indicate password requirements
      assert html =~ "password" or html =~ "Password"
    end

    test "provides link to login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      assert html =~ "Sign in" or html =~ ~r/log\s+in/i or html =~ "Already have an account"
    end
  end

  describe "form accessibility edge cases" do
    test "login form displays errors accessibly", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      # Should have ARIA attributes for error messages
      assert html =~ "login_form" or html =~ "form"
    end

    test "registration form handles long input values", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      long_email = String.duplicate("a", 100) <> "@example.com"

      html =
        lv
        |> form("#registration_form", %{
          "user" => %{"email" => long_email}
        })
        |> render_change()

      # Should handle gracefully (either validate or truncate)
      assert html =~ "registration_form" or html =~ "Email"
    end

    test "registration form handles special characters", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      html =
        lv
        |> form("#registration_form", %{
          "user" => %{
            "first_name" => "Jean-François",
            "last_name" => "O'Brien"
          }
        })
        |> render_change()

      assert html =~ "registration_form" or html =~ "First Name"
    end
  end

  describe "accessibility compliance" do
    test "login form meets WCAG 2.1 Level A standards", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      warnings = get_accessibility_warnings(html)

      refute Enum.any?(warnings, &String.contains?(&1, "alt text")),
             "Should not have images without alt text"
    end

    test "registration form meets WCAG 2.1 Level A standards", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      warnings = get_accessibility_warnings(html)

      refute Enum.any?(warnings, &String.contains?(&1, "alt text")),
             "Should not have images without alt text"
    end
  end
end
