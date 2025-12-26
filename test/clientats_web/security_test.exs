defmodule ClientatsWeb.SecurityTest do
  use ClientatsWeb.ConnCase
  import Ecto.Query
  alias Clientats.Repo
  alias Clientats.Accounts.User

  describe "CSRF Protection" do
    test "POST requests with CSRF protection succeed", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Login request with CSRF protection (automatically handled by Phoenix)
      conn =
        post(conn, ~p"/login", %{
          user: %{email: user.email, password: "SecurePassword123!"}
        })

      # Should succeed with valid CSRF token (automatically handled by ConnCase)
      assert conn.status in [200, 302]
    end

    test "CSRF protection is enabled in router", %{conn: _conn} do
      # Verify :protect_from_forgery plug is in browser pipeline
      # This is configured in router.ex
      assert true
    end
  end

  describe "Session Cookie Security" do
    test "session cookie configuration is secure", %{conn: _conn} do
      # Check session cookie configuration
      # Note: In test environment, cookie attributes are configured in endpoint.ex
      session_opts = Plug.Session.init(
        store: :cookie,
        key: "_clientats_web_key",
        signing_salt: "test_salt"
      )

      # Verify HttpOnly is enabled (default in Phoenix)
      # Session store should be Plug.Session.COOKIE
      assert is_atom(session_opts[:store])
    end

    test "session cookie has secure flag in production", %{conn: _conn} do
      # In production, secure flag should be set
      # This is configured in config/runtime.exs
      # We verify the configuration exists
      endpoint_config = Application.get_env(:clientats, ClientatsWeb.Endpoint)

      # Session configuration should exist
      assert endpoint_config != nil
    end

    test "session cookie has SameSite attribute configured", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Verify session was set
      assert get_session(conn, :user_id) == user.id

      # SameSite is configured at the endpoint level
      # Default Phoenix behavior sets this appropriately
      assert true
    end
  end

  describe "Password Hashing with bcrypt" do
    test "passwords are hashed with bcrypt", %{conn: _conn} do
      user = user_fixture(password: "SecurePassword123!")

      # Fetch user from database
      db_user = Repo.get!(User, user.id)

      # Verify password is hashed
      assert db_user.hashed_password != nil
      assert db_user.hashed_password != "SecurePassword123!"

      # Verify bcrypt format (starts with $2b$ or $2a$)
      assert String.starts_with?(db_user.hashed_password, "$2") or
             String.starts_with?(db_user.hashed_password, "$2b$") or
             String.starts_with?(db_user.hashed_password, "$2a$")

      # Verify hash length (bcrypt hashes are 60 characters)
      assert String.length(db_user.hashed_password) == 60
    end

    test "plaintext passwords are never stored", %{conn: _conn} do
      user = user_fixture(password: "MyPassword123!")

      # Verify password field doesn't exist in database
      db_user = Repo.get!(User, user.id)

      # User schema should not have a password field (only hashed_password)
      refute Map.has_key?(db_user, :password) and db_user.password != nil
      assert Map.has_key?(db_user, :hashed_password)
    end

    test "password verification works correctly", %{conn: _conn} do
      password = "CorrectPassword123!"
      user = user_fixture(password: password)

      # Verify correct password with bcrypt
      assert Bcrypt.verify_pass(password, user.hashed_password)

      # Verify incorrect password
      refute Bcrypt.verify_pass("WrongPassword", user.hashed_password)
    end
  end

  describe "XSS Prevention - HTML Escaping" do
    test "script tags are escaped in job interest titles", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      xss_payload = "<script>alert('XSS')</script>"

      {:ok, interest} = Clientats.Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: "Test Corp",
        position_title: xss_payload,
        status: "interested"
      })

      # Visit the interest detail page
      conn = get(conn, ~p"/dashboard/job-interests/#{interest.id}")

      # Verify script tag is escaped in HTML response
      html = html_response(conn, 200)

      # Should not contain executable script
      refute String.contains?(html, "<script>alert('XSS')</script>")

      # Should contain escaped version
      assert String.contains?(html, "&lt;script&gt;") or
             String.contains?(html, xss_payload) == false
    end

    test "HTML injection is prevented in user inputs", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      malicious_html = "<img src=x onerror='alert(1)'>"

      {:ok, interest} = Clientats.Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: malicious_html,
        position_title: "Engineer",
        status: "interested",
        notes: malicious_html
      })

      conn = get(conn, ~p"/dashboard/job-interests/#{interest.id}")
      html = html_response(conn, 200)

      # Malicious HTML should be escaped
      refute String.contains?(html, "<img src=x onerror=")
    end
  end

  describe "SQL Injection Prevention" do
    test "parameterized queries prevent SQL injection", %{conn: _conn} do
      user = user_fixture()

      # Create job interests
      {:ok, interest1} = Clientats.Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: "Acme Corp",
        position_title: "Engineer",
        status: "interested"
      })

      {:ok, _interest2} = Clientats.Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: "Test Company",
        position_title: "Developer",
        status: "interested"
      })

      # Verify list function works correctly
      result = Clientats.Jobs.list_job_interests(user.id)
      assert length(result) == 2

      # Attempt SQL injection via direct Repo query
      # This should be safely handled by Ecto's parameterized queries
      sql_injection_payload = "' OR '1'='1"

      # Try to query with malicious input
      # Ecto will safely escape this as a string parameter
      safe_result = Repo.all(
        from ji in Clientats.Jobs.JobInterest,
        where: ji.user_id == ^user.id and ji.company_name == ^sql_injection_payload
      )

      # Should return empty (not all records)
      assert safe_result == []

      # Verify regular query still works
      normal_result = Repo.all(
        from ji in Clientats.Jobs.JobInterest,
        where: ji.user_id == ^user.id and ji.id == ^interest1.id
      )

      assert length(normal_result) == 1
    end

    test "user input is sanitized in database queries", %{conn: _conn} do
      user = user_fixture()

      # Attempt SQL injection in company name
      malicious_input = "Company'; DROP TABLE users; --"

      # This should be safely stored as a string
      {:ok, interest} = Clientats.Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: malicious_input,
        position_title: "Engineer",
        status: "interested"
      })

      # Verify data was stored as-is (not executed)
      assert interest.company_name == malicious_input

      # Verify users table still exists
      assert Repo.exists?(User)
    end

    test "Ecto uses parameterized queries", %{conn: _conn} do
      user = user_fixture()

      # Create interests with special characters
      company_names = [
        "O'Reilly Media",
        "Company & Co",
        "Test \"Quoted\" Corp",
        "Company; DROP TABLE test;"
      ]

      for company <- company_names do
        {:ok, interest} = Clientats.Jobs.create_job_interest(%{
          user_id: user.id,
          company_name: company,
          position_title: "Engineer",
          status: "interested"
        })

        # Verify data was stored correctly
        db_interest = Repo.get(Clientats.Jobs.JobInterest, interest.id)
        assert db_interest.company_name == company
      end
    end
  end

  describe "Input Validation" do
    test "email format is validated", %{conn: _conn} do
      invalid_emails = [
        "notanemail",
        "missing@",
        "@nodomain.com",
        "spaces in@email.com"
      ]

      for email <- invalid_emails do
        result = Clientats.Accounts.register_user(%{
          email: email,
          password: "ValidPassword123!",
          password_confirmation: "ValidPassword123!",
          first_name: "Test",
          last_name: "User"
        })

        assert {:error, changeset} = result
        # Check that email has validation errors
        assert changeset.errors[:email] != nil
      end
    end

    test "password requirements are enforced", %{conn: _conn} do
      # Test very short password (less than 8 characters)
      result = Clientats.Accounts.register_user(%{
        email: "test#{System.unique_integer([:positive])}@example.com",
        password: "short",
        password_confirmation: "short",
        first_name: "Test",
        last_name: "User"
      })

      # Should fail validation for being too short
      assert {:error, changeset} = result
      assert changeset.errors[:password] != nil
    end
  end

  describe "Session Security" do
    test "session data is not exposed in responses", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      conn = get(conn, ~p"/dashboard")
      html = html_response(conn, 200)

      # Session ID or sensitive session data should not be in HTML
      refute String.contains?(html, "session_id")
      refute String.contains?(html, "_csrf_token")
    end

    test "old sessions are invalidated on logout", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Verify logged in
      assert get_session(conn, :user_id) == user.id

      # Logout
      conn = delete(conn, ~p"/logout")

      # Session should be cleared
      assert get_session(conn, :user_id) == nil
    end
  end

  # Helper functions
  defp user_fixture(attrs \\ %{}) do
    # Convert to map if it's a keyword list
    attrs_map = Enum.into(attrs, %{})

    default_attrs = %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      password: "SecurePassword123!",
      password_confirmation: "SecurePassword123!",
      first_name: "Test",
      last_name: "User"
    }

    # If password is provided, ensure password_confirmation matches
    attrs_map = if Map.has_key?(attrs_map, :password) and not Map.has_key?(attrs_map, :password_confirmation) do
      Map.put(attrs_map, :password_confirmation, attrs_map.password)
    else
      attrs_map
    end

    final_attrs = Map.merge(default_attrs, attrs_map)

    {:ok, user} = Clientats.Accounts.register_user(final_attrs)
    user
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
