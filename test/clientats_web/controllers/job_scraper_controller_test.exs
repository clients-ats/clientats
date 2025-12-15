defmodule ClientatsWeb.JobScraperControllerTest do
  use ClientatsWeb.ConnCase

  alias Clientats.Accounts
  
  setup do
    # Create a test user
    user_attrs = %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }
    
    {:ok, user} = Accounts.register_user(user_attrs)
    
    # Create authenticated connection
    conn = 
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)
    
    %{conn: conn, user: user}
  end
  
  describe "scrape/2" do
    test "returns 401 for unauthenticated requests" do
      conn = build_conn()
      
      conn = post(conn, ~p"/api/scrape_job", %{"url" => "https://example.com"})
      
      assert response(conn, 401)
      assert json_response(conn)["error"] == "Unauthorized"
    end
    
    test "returns 400 for missing URL", %{user: user} do
      # Create authenticated connection
      conn = 
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Plug.Conn.assign(:current_user, user)
      
      conn = post(conn, ~p"/api/scrape_job", %{})
      
      assert response(conn, 400)
      assert json_response(conn)["error"] == "URL is required"
    end
    
    test "returns 400 for invalid URL format", %{user: user} do
      # Create authenticated connection
      conn = 
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Plug.Conn.assign(:current_user, user)
      
      conn = post(conn, ~p"/api/scrape_job", %{"url" => "not-a-url"})
      
      assert response(conn, 400)
      assert json_response(conn)["error"] == "URL must start with http:// or https://"
    end
    
    test "returns 400 for URL that's too long", %{user: user} do
      # Create authenticated connection
      conn = 
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Plug.Conn.assign(:current_user, user)
      
      long_url = String.duplicate("a", 2001)
      conn = post(conn, ~p"/api/scrape_job", %{"url" => "https://" <> long_url})
      
      assert response(conn, 400)
      assert json_response(conn)["error"] == "URL is too long (max 2000 characters)"
    end
    
    test "returns error for unreachable URL", %{user: user} do
      # Create authenticated connection
      conn = 
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Plug.Conn.assign(:current_user, user)
      
      conn = post(conn, ~p"/api/scrape_job", %{"url" => "https://this-url-should-not-exist-12345.com/jobs/123"})
      
      # Should return an error response
      assert response(conn, 400)
      assert match?(%{"error" => _}, json_response(conn))
    end
  end
  
  describe "providers/2" do
    test "returns 401 for unauthenticated requests" do
      conn = build_conn()
      
      conn = get(conn, ~p"/api/llm/providers")
      
      assert response(conn, 401)
      assert json_response(conn)["error"] == "Unauthorized"
    end
    
    test "returns available providers for authenticated requests", %{user: user} do
      # Create authenticated connection
      conn = 
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Plug.Conn.assign(:current_user, user)
      
      conn = get(conn, ~p"/api/llm/providers")
      
      assert response(conn, 200)
      assert json_response(conn)["success"] == true
      assert is_list(json_response(conn)["providers"])
    end
  end
  
  describe "config/2" do
    test "returns 401 for unauthenticated requests" do
      conn = build_conn()
      
      conn = get(conn, ~p"/api/llm/config")
      
      assert response(conn, 401)
      assert json_response(conn)["error"] == "Unauthorized"
    end
    
    test "returns LLM configuration for authenticated requests", %{user: user} do
      # Create authenticated connection
      conn = 
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_id, user.id)
        |> Plug.Conn.assign(:current_user, user)
      
      conn = get(conn, ~p"/api/llm/config")
      
      assert response(conn, 200)
      assert json_response(conn)["success"] == true
      assert is_map(json_response(conn)["config"])
    end
  end
  
  # Helper function to get JSON response
  defp json_response(conn) do
    if conn.halted || conn.state == :sent do
      Jason.decode!(conn.resp_body)
    else
      conn.body |> Jason.decode!()
    end
  end
end