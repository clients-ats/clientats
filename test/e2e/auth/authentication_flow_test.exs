defmodule ClientatsWeb.E2E.AuthenticationFlowTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query
  import ClientatsWeb.E2E.UserFixtures

  @moduletag :feature

  describe "user registration" do
    test "successful registration creates account and logs in", %{session: session} do
      user = user_attrs()

      session
      |> visit("/")
      |> click(link("Get Started"))
      |> assert_has(css("h2", text: "Create your account"))
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[first_name]']"), with: user.first_name)
      |> fill_in(css("input[name='user[last_name]']"), with: user.last_name)
      |> fill_in(css("input[name='user[password]']"), with: user.password)
      |> fill_in(css("input[name='user[password_confirmation]']"),
        with: user.password_confirmation
      )
      |> click(button("Create an account"))
      |> assert_has(css("h1", text: "Welcome to Clientats"))
      |> assert_has(link("Go to Dashboard"))
    end

    test "registration with invalid email shows error", %{session: session} do
      user = user_attrs()

      session
      |> visit("/register")
      |> fill_in(css("input[name='user[email]']"), with: "invalid-email")
      |> fill_in(css("input[name='user[first_name]']"), with: user.first_name)
      |> fill_in(css("input[name='user[last_name]']"), with: user.last_name)
      |> fill_in(css("input[name='user[password]']"), with: user.password)
      |> fill_in(css("input[name='user[password_confirmation]']"),
        with: user.password_confirmation
      )
      |> click(button("Create an account"))
      |> assert_has(css(".phx-form-error", text: "must have the @ sign and no spaces"))
    end

    test "registration with short password shows error", %{session: session} do
      user = user_attrs()

      session
      |> visit("/register")
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[first_name]']"), with: user.first_name)
      |> fill_in(css("input[name='user[last_name]']"), with: user.last_name)
      |> fill_in(css("input[name='user[password]']"), with: "short")
      |> fill_in(css("input[name='user[password_confirmation]']"), with: "short")
      |> click(button("Create an account"))
      |> assert_has(css(".phx-form-error", text: "should be at least 8 character(s)"))
    end

    test "registration with mismatched passwords shows error", %{session: session} do
      user = user_attrs()

      session
      |> visit("/register")
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[first_name]']"), with: user.first_name)
      |> fill_in(css("input[name='user[last_name]']"), with: user.last_name)
      |> fill_in(css("input[name='user[password]']"), with: user.password)
      |> fill_in(css("input[name='user[password_confirmation]']"), with: "different_password")
      |> click(button("Create an account"))
      |> assert_has(css(".phx-form-error", text: "does not match password"))
    end

    test "registration with duplicate email shows error", %{session: session} do
      # Create a user first
      user = create_user()

      # Try to register with the same email
      session
      |> visit("/register")
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[first_name]']"), with: "Another")
      |> fill_in(css("input[name='user[last_name]']"), with: "User")
      |> fill_in(css("input[name='user[password]']"), with: "password123")
      |> fill_in(css("input[name='user[password_confirmation]']"), with: "password123")
      |> click(button("Create an account"))
      |> assert_has(css(".phx-form-error", text: "has already been taken"))
    end

    test "can navigate to login from registration page", %{session: session} do
      session
      |> visit("/register")
      |> assert_has(css("h2", text: "Create your account"))
      |> click(link("Sign in"))
      |> assert_has(css("h2", text: "Sign in to your account"))
    end
  end

  describe "user login" do
    test "successful login with valid credentials", %{session: session} do
      user = create_user()

      session
      |> visit("/login")
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[password]']"), with: user.password)
      |> click(button("Sign in"))
      |> assert_has(css("h1", text: "Clientats Dashboard"))
    end

    test "login with invalid email shows error", %{session: session} do
      session
      |> visit("/login")
      |> fill_in(css("input[name='user[email]']"), with: "nonexistent@example.com")
      |> fill_in(css("input[name='user[password]']"), with: "password123")
      |> click(button("Sign in"))
      |> assert_has(css(".alert-danger", text: "Invalid email or password"))
    end

    test "login with incorrect password shows error", %{session: session} do
      user = create_user()

      session
      |> visit("/login")
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[password]']"), with: "wrong_password")
      |> click(button("Sign in"))
      |> assert_has(css(".alert-danger", text: "Invalid email or password"))
    end

    test "can navigate to registration from login page", %{session: session} do
      session
      |> visit("/login")
      |> assert_has(css("h2", text: "Sign in to your account"))
      |> click(link("Sign up"))
      |> assert_has(css("h2", text: "Create your account"))
    end
  end

  describe "user logout" do
    test "logout redirects to home page", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> assert_has(css("h1", text: "Clientats Dashboard"))
      |> click(link("Log out"))
      |> assert_has(css("h1", text: "Welcome to Clientats"))
    end

    test "after logout, cannot access protected routes", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> assert_has(css("h1", text: "Clientats Dashboard"))
      |> click(link("Log out"))
      |> assert_has(css("h1", text: "Welcome to Clientats"))
      # Try to access dashboard again
      |> visit("/dashboard")
      |> assert_has(css("h2", text: "Sign in to your account"))
    end
  end

  describe "session management" do
    test "authenticated user can access dashboard", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> assert_has(css("h1", text: "Clientats Dashboard"))
    end

    test "authenticated user can navigate to different dashboard sections", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> assert_has(css("h1", text: "Clientats Dashboard"))
      |> click(link("Add Interest"))
      |> assert_has(css("h2", text: "New Job Interest"))
      |> visit("/dashboard")
      |> assert_has(css("h1", text: "Clientats Dashboard"))
    end

    test "session persists across page navigation", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> assert_has(css("h1", text: "Clientats Dashboard"))
      |> visit("/dashboard/resumes")
      |> assert_has(css("h1", text: "My Resumes"))
      |> visit("/dashboard/cover-letters")
      |> assert_has(css("h1", text: "Cover Letter Templates"))
      |> visit("/dashboard")
      |> assert_has(css("h1", text: "Clientats Dashboard"))
    end

    test "authenticated user can access settings", %{session: session} do
      user = create_user_and_login(session)

      session
      |> visit("/dashboard/settings")
      |> assert_has(css("h2", text: "Change Email"))
      |> assert_has(css("input[value='#{user.email}']"))
    end
  end

  describe "protected routes" do
    test "unauthenticated user redirected to login when accessing dashboard", %{session: session} do
      session
      |> visit("/dashboard")
      |> assert_has(css("h2", text: "Sign in to your account"))
    end

    test "unauthenticated user redirected to login when accessing job interests", %{
      session: session
    } do
      session
      |> visit("/dashboard/job-interests/new")
      |> assert_has(css("h2", text: "Sign in to your account"))
    end

    test "unauthenticated user redirected to login when accessing resumes", %{session: session} do
      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("h2", text: "Sign in to your account"))
    end

    test "unauthenticated user redirected to login when accessing applications", %{
      session: session
    } do
      session
      |> visit("/dashboard/applications")
      |> assert_has(css("h2", text: "Sign in to your account"))
    end

    test "unauthenticated user redirected to login when accessing settings", %{session: session} do
      session
      |> visit("/dashboard/settings")
      |> assert_has(css("h2", text: "Sign in to your account"))
    end

    test "after login, user is redirected to originally requested page", %{session: session} do
      user = create_user()

      session
      |> visit("/dashboard/resumes")
      |> assert_has(css("h2", text: "Sign in to your account"))
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[password]']"), with: user.password)
      |> click(button("Sign in"))
      |> assert_has(css("h1", text: "My Resumes"))
    end
  end

  describe "complete authentication workflow" do
    test "full user journey: register -> dashboard -> logout -> login", %{session: session} do
      user = user_attrs()

      # Register
      session
      |> visit("/")
      |> click(link("Get Started"))
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[first_name]']"), with: user.first_name)
      |> fill_in(css("input[name='user[last_name]']"), with: user.last_name)
      |> fill_in(css("input[name='user[password]']"), with: user.password)
      |> fill_in(css("input[name='user[password_confirmation]']"),
        with: user.password_confirmation
      )
      |> click(button("Create an account"))
      |> assert_has(css("h1", text: "Welcome to Clientats"))

      # Go to Dashboard
      session
      |> click(link("Go to Dashboard"))
      |> assert_has(css("h1", text: "Clientats Dashboard"))

      # Logout
      session
      |> click(link("Log out"))
      |> assert_has(css("h1", text: "Welcome to Clientats"))

      # Login again
      session
      |> click(link("Sign In"))
      |> fill_in(css("input[name='user[email]']"), with: user.email)
      |> fill_in(css("input[name='user[password]']"), with: user.password)
      |> click(button("Sign in"))
      |> assert_has(css("h1", text: "Clientats Dashboard"))
    end
  end
end
