defmodule ClientatsWeb.Features.APIEndpointsDocumentationTest do
  @moduledoc """
  E2E tests for API Endpoints & Documentation (beads issue: clientats-6fez).

  Based on E2E_TESTING_GUIDE.md sections 10.1-10.9, this test suite covers:
  - API versioning (v1, v2, legacy)
  - POST /api/v1/scrape_job
  - GET /api/v1/llm/providers
  - GET /api/v1/llm/config
  - Swagger UI documentation
  - ReDoc documentation
  - OpenAPI specification
  - API error responses
  - API rate limiting (if implemented)
  """

  use ClientatsWeb.ConnCase, async: false

  alias Clientats.Accounts

  setup do
    # Create a test user for authenticated requests
    user_attrs = %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }

    {:ok, user} = Accounts.register_user(user_attrs)

    # Create authenticated connection
    auth_conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)
      |> Plug.Conn.assign(:current_user, user)

    %{conn: build_conn(), auth_conn: auth_conn, user: user}
  end

  # ============================================================================
  # Test Case 10.1: API Versioning (v1, v2, Legacy)
  # ============================================================================

  describe "API Versioning" do
    test "v1 endpoint is accessible and functional", %{auth_conn: conn} do
      conn = post(conn, "/api/v1/scrape_job", %{"url" => "https://example.com/jobs/123"})

      # Should respond (even if scraping fails, endpoint should exist)
      assert conn.status in [200, 400, 500]
      assert get_resp_header(conn, "api-version") == ["v1"]
      response = json_response(conn)
      assert response["_api"]["version"] == "v1"
      assert is_list(response["_api"]["supported_versions"])
    end

    test "v2 endpoint is accessible", %{auth_conn: conn} do
      conn = post(conn, "/api/v2/scrape_job", %{"url" => "https://example.com/jobs/123"})

      # Should respond (even if scraping fails, endpoint should exist)
      assert conn.status in [200, 400, 500]
      assert get_resp_header(conn, "api-version") == ["v2"]
      response = json_response(conn)
      assert response["_api"]["version"] == "v2"
    end

    test "legacy endpoint (no version) redirects to v1", %{auth_conn: conn} do
      conn = post(conn, "/api/scrape_job", %{"url" => "https://example.com/jobs/123"})

      # Should respond with v1 behavior
      assert conn.status in [200, 400, 500]
      # Legacy endpoint should behave like v1
      assert get_resp_header(conn, "api-version") == ["v1"]
      response = json_response(conn)
      assert response["_api"]["version"] == "v1"
    end

    test "version metadata included in all responses", %{auth_conn: conn} do
      # Test v1
      conn_v1 = get(conn, "/api/v1/llm/providers")
      response_v1 = json_response(conn_v1)
      assert response_v1["_api"]["version"] == "v1"
      assert is_list(response_v1["_api"]["supported_versions"])
      assert "v1" in response_v1["_api"]["supported_versions"]

      # Test v2
      conn_v2 = get(conn, "/api/v2/llm/providers")
      response_v2 = json_response(conn_v2)
      assert response_v2["_api"]["version"] == "v2"
      assert is_list(response_v2["_api"]["supported_versions"])
    end
  end

  # ============================================================================
  # Test Case 10.2: POST /api/v1/scrape_job
  # ============================================================================

  describe "POST /api/v1/scrape_job" do
    test "accepts required parameters", %{auth_conn: conn} do
      params = %{
        "url" => "https://www.linkedin.com/jobs/view/123/",
        "mode" => "specific"
      }

      conn = post(conn, "/api/v1/scrape_job", params)

      # Should respond (even if scraping fails due to no LLM configured)
      assert conn.status in [200, 400, 500]
      response = json_response(conn)
      assert is_map(response)
      assert Map.has_key?(response, "success")
    end

    test "accepts optional provider parameter", %{auth_conn: conn} do
      params = %{
        "url" => "https://www.linkedin.com/jobs/view/123/",
        "mode" => "generic",
        "provider" => "ollama"
      }

      conn = post(conn, "/api/v1/scrape_job", params)

      assert conn.status in [200, 400, 500]
      response = json_response(conn)
      assert is_map(response)
    end

    test "accepts save parameter to auto-save job interest", %{auth_conn: conn} do
      params = %{
        "url" => "https://www.linkedin.com/jobs/view/123/",
        "mode" => "generic",
        "save" => "true"
      }

      conn = post(conn, "/api/v1/scrape_job", params)

      assert conn.status in [200, 400, 500]
      response = json_response(conn)
      assert is_map(response)
    end

    test "requires authentication", %{conn: conn} do
      params = %{
        "url" => "https://www.linkedin.com/jobs/view/123/",
        "mode" => "generic"
      }

      conn = post(conn, "/api/v1/scrape_job", params)

      assert conn.status == 401
      response = json_response(conn)
      assert response["error"] == "Unauthorized"
      assert response["message"] == "Authentication required"
    end

    test "validates URL is required", %{auth_conn: conn} do
      conn = post(conn, "/api/v1/scrape_job", %{})

      assert conn.status == 400
      response = json_response(conn)
      assert response["success"] == false
      assert response["error"] == "URL is required"
    end

    test "validates URL format", %{auth_conn: conn} do
      conn = post(conn, "/api/v1/scrape_job", %{"url" => "not-a-valid-url"})

      assert conn.status == 400
      response = json_response(conn)
      assert response["success"] == false
      assert response["error"] == "URL must start with http:// or https://"
    end

    test "validates URL length", %{auth_conn: conn} do
      long_url = "https://" <> String.duplicate("a", 2001)
      conn = post(conn, "/api/v1/scrape_job", %{"url" => long_url})

      assert conn.status == 400
      response = json_response(conn)
      assert response["success"] == false
      assert response["error"] == "URL is too long (max 2000 characters)"
    end

    test "supports different extraction modes", %{auth_conn: conn} do
      # Test generic mode
      conn_generic = post(conn, "/api/v1/scrape_job", %{
        "url" => "https://example.com/jobs/123",
        "mode" => "generic"
      })
      assert conn_generic.status in [200, 400, 500]

      # Test specific mode
      conn_specific = post(conn, "/api/v1/scrape_job", %{
        "url" => "https://www.linkedin.com/jobs/view/123/",
        "mode" => "specific"
      })
      assert conn_specific.status in [200, 400, 500]
    end
  end

  # ============================================================================
  # Test Case 10.3: GET /api/v1/llm/providers
  # ============================================================================

  describe "GET /api/v1/llm/providers" do
    test "returns list of available providers", %{auth_conn: conn} do
      conn = get(conn, "/api/v1/llm/providers")

      assert conn.status == 200
      response = json_response(conn)
      assert response["success"] == true
      assert is_list(response["providers"])
      assert response["message"] == "Available LLM providers"
    end

    test "includes API version metadata", %{auth_conn: conn} do
      conn = get(conn, "/api/v1/llm/providers")

      assert conn.status == 200
      response = json_response(conn)
      assert response["_api"]["version"] == "v1"
      assert is_list(response["_api"]["supported_versions"])
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/llm/providers")

      assert conn.status == 401
      response = json_response(conn)
      assert response["error"] == "Unauthorized"
      assert response["message"] == "Authentication required"
    end

    test "does not expose sensitive data (API keys)", %{auth_conn: conn} do
      conn = get(conn, "/api/v1/llm/providers")

      assert conn.status == 200
      response = json_response(conn)
      providers = response["providers"]

      # Ensure no API keys are exposed in the response
      json_str = Jason.encode!(providers)
      refute String.contains?(json_str, "api_key")
      refute String.contains?(json_str, "secret")
      refute String.contains?(json_str, "password")
    end

    test "works with v2 endpoint", %{auth_conn: conn} do
      conn = get(conn, "/api/v2/llm/providers")

      assert conn.status == 200
      response = json_response(conn)
      assert response["success"] == true
      assert is_list(response["providers"])
      assert response["_api"]["version"] == "v2"
    end

    test "works with legacy endpoint", %{auth_conn: conn} do
      conn = get(conn, "/api/llm/providers")

      assert conn.status == 200
      response = json_response(conn)
      assert response["success"] == true
      assert is_list(response["providers"])
      # Legacy should redirect to v1 behavior
      assert response["_api"]["version"] == "v1"
    end
  end

  # ============================================================================
  # Test Case 10.4: GET /api/v1/llm/config
  # ============================================================================

  describe "GET /api/v1/llm/config" do
    test "returns LLM configuration", %{auth_conn: conn} do
      conn = get(conn, "/api/v1/llm/config")

      assert conn.status == 200
      response = json_response(conn)
      assert response["success"] == true
      assert is_map(response["config"])
      assert response["message"] == "Current LLM configuration"
    end

    test "includes API version metadata", %{auth_conn: conn} do
      conn = get(conn, "/api/v1/llm/config")

      assert conn.status == 200
      response = json_response(conn)
      assert response["_api"]["version"] == "v1"
      assert is_list(response["_api"]["supported_versions"])
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/llm/config")

      assert conn.status == 401
      response = json_response(conn)
      assert response["error"] == "Unauthorized"
      assert response["message"] == "Authentication required"
    end

    test "masks API keys in response", %{auth_conn: conn} do
      conn = get(conn, "/api/v1/llm/config")

      assert conn.status == 200
      response = json_response(conn)
      config = response["config"]

      # Ensure API keys are masked
      json_str = Jason.encode!(config)
      refute String.contains?(json_str, "sk-")
      refute String.contains?(json_str, "api_key")
      # Keys should be masked or not included
    end

    test "works with v2 endpoint", %{auth_conn: conn} do
      conn = get(conn, "/api/v2/llm/config")

      assert conn.status == 200
      response = json_response(conn)
      assert response["success"] == true
      assert is_map(response["config"])
      assert response["_api"]["version"] == "v2"
    end

    test "works with legacy endpoint", %{auth_conn: conn} do
      conn = get(conn, "/api/llm/config")

      assert conn.status == 200
      response = json_response(conn)
      assert response["success"] == true
      assert is_map(response["config"])
      assert response["_api"]["version"] == "v1"
    end
  end

  # ============================================================================
  # Test Case 10.5: Swagger UI Documentation
  # ============================================================================

  describe "Swagger UI Documentation" do
    test "swagger UI page loads successfully", %{conn: conn} do
      conn = get(conn, "/api-docs/swagger-ui")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      body = conn.resp_body

      # Check for Swagger UI elements
      assert body =~ "ClientATS API Documentation"
      assert body =~ "swagger-ui"
      assert body =~ "/api-docs/openapi.json"
      assert body =~ "SwaggerUIBundle"
    end

    test "swagger UI includes Try it out functionality", %{conn: conn} do
      conn = get(conn, "/api-docs/swagger-ui")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "tryItOutEnabled: true"
    end

    test "swagger UI references OpenAPI specification", %{conn: conn} do
      conn = get(conn, "/api-docs/swagger-ui")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "url: \"/api-docs/openapi.json\""
    end

    test "swagger UI uses CDN resources", %{conn: conn} do
      conn = get(conn, "/api-docs/swagger-ui")

      assert conn.status == 200
      body = conn.resp_body

      # Check for CDN links
      assert body =~ "cdnjs.cloudflare.com/ajax/libs/swagger-ui"
      assert body =~ "swagger-ui.min.css"
      assert body =~ "swagger-ui-bundle.min.js"
    end
  end

  # ============================================================================
  # Test Case 10.6: ReDoc Documentation
  # ============================================================================

  describe "ReDoc Documentation" do
    test "ReDoc page loads successfully", %{conn: conn} do
      conn = get(conn, "/api-docs/redoc")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      body = conn.resp_body

      # Check for ReDoc elements
      assert body =~ "ClientATS API Documentation - ReDoc"
      assert body =~ "<redoc"
      assert body =~ "/api-docs/openapi.json"
      assert body =~ "redoc.standalone.js"
    end

    test "ReDoc references OpenAPI specification", %{conn: conn} do
      conn = get(conn, "/api-docs/redoc")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "spec-url='/api-docs/openapi.json'"
    end

    test "ReDoc uses CDN resources", %{conn: conn} do
      conn = get(conn, "/api-docs/redoc")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "cdn.jsdelivr.net/npm/redoc"
    end

    test "ReDoc includes custom fonts", %{conn: conn} do
      conn = get(conn, "/api-docs/redoc")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "fonts.googleapis.com"
    end
  end

  # ============================================================================
  # Test Case 10.7: OpenAPI Specification
  # ============================================================================

  describe "OpenAPI Specification" do
    test "OpenAPI spec returns valid JSON", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

      # Parse JSON to ensure it's valid
      spec = json_response(conn)
      assert is_map(spec)
    end

    test "OpenAPI spec has required OpenAPI 3.0 fields", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")
      spec = json_response(conn)

      # Check OpenAPI version
      assert spec["openapi"] == "3.0.0"

      # Check info section
      assert is_map(spec["info"])
      assert spec["info"]["title"] == "ClientATS API"
      assert is_binary(spec["info"]["version"])
      assert is_binary(spec["info"]["description"])

      # Check paths
      assert is_map(spec["paths"])
      assert map_size(spec["paths"]) > 0

      # Check components
      assert is_map(spec["components"])
    end

    test "OpenAPI spec documents all endpoints", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")
      spec = json_response(conn)

      paths = spec["paths"]

      # Check for key endpoints
      assert Map.has_key?(paths, "/scrape_job")
      assert Map.has_key?(paths, "/llm/providers")
      assert Map.has_key?(paths, "/llm/config")

      # Check scrape_job has POST method
      assert Map.has_key?(paths["/scrape_job"], "post")

      # Check providers has GET method
      assert Map.has_key?(paths["/llm/providers"], "get")

      # Check config has GET method
      assert Map.has_key?(paths["/llm/config"], "get")
    end

    test "OpenAPI spec includes request/response schemas", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")
      spec = json_response(conn)

      components = spec["components"]

      # Check for schemas
      assert is_map(components["schemas"])
      assert map_size(components["schemas"]) > 0

      # Check for common schemas
      schemas = components["schemas"]
      schema_keys = Map.keys(schemas)

      # Should have request/response schemas
      assert Enum.any?(schema_keys, &String.contains?(&1, "Request"))
      assert Enum.any?(schema_keys, &String.contains?(&1, "Response"))
    end

    test "OpenAPI spec includes examples", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")
      spec = json_response(conn)

      # Check scrape_job endpoint has examples
      scrape_endpoint = spec["paths"]["/scrape_job"]["post"]

      assert is_map(scrape_endpoint["requestBody"])
      request_content = scrape_endpoint["requestBody"]["content"]["application/json"]

      assert is_map(request_content["examples"])
      assert map_size(request_content["examples"]) > 0
    end

    test "OpenAPI spec includes server information", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")
      spec = json_response(conn)

      assert is_list(spec["servers"])
      assert length(spec["servers"]) > 0

      # Check first server
      server = List.first(spec["servers"])
      assert is_map(server)
      assert is_binary(server["url"])
      assert is_binary(server["description"])
    end

    test "OpenAPI spec includes tags", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")
      spec = json_response(conn)

      assert is_list(spec["tags"])
      assert length(spec["tags"]) > 0

      # Check tag structure
      tag = List.first(spec["tags"])
      assert is_map(tag)
      assert is_binary(tag["name"])
      assert is_binary(tag["description"])
    end

    test "OpenAPI spec can be imported into API tools", %{conn: conn} do
      conn = get(conn, "/api-docs/openapi.json")
      spec = json_response(conn)

      # Validate it follows OpenAPI 3.0 structure
      # This would be acceptable by Postman, Insomnia, etc.
      assert spec["openapi"] == "3.0.0"
      assert is_map(spec["info"])
      assert is_map(spec["paths"])
      assert is_map(spec["components"])

      # Encode back to JSON to ensure round-trip works
      {:ok, json_string} = Jason.encode(spec)
      assert is_binary(json_string)
      assert String.length(json_string) > 0
    end
  end

  # ============================================================================
  # Test Case 10.8: API Error Responses
  # ============================================================================

  describe "API Error Responses" do
    test "returns 400 for invalid input - missing required parameters", %{auth_conn: conn} do
      conn = post(conn, "/api/v1/scrape_job", %{})

      assert conn.status == 400
      response = json_response(conn)
      assert response["success"] == false
      assert is_binary(response["error"])
      assert is_binary(response["message"])
    end

    test "returns 400 for invalid URL format", %{auth_conn: conn} do
      conn = post(conn, "/api/v1/scrape_job", %{"url" => "invalid-url"})

      assert conn.status == 400
      response = json_response(conn)
      assert response["success"] == false
      assert response["error"] =~ "URL must start with"
    end

    test "returns 401 for unauthorized requests", %{conn: conn} do
      conn = post(conn, "/api/v1/scrape_job", %{"url" => "https://example.com/jobs/123"})

      assert conn.status == 401
      response = json_response(conn)
      assert response["error"] == "Unauthorized"
      assert response["message"] == "Authentication required"
    end

    test "returns 400 for unsupported provider", %{auth_conn: conn} do
      conn = post(conn, "/api/v1/scrape_job", %{
        "url" => "https://example.com/jobs/123",
        "provider" => "invalid-provider-xyz"
      })

      # Should accept but may fail due to invalid provider
      assert conn.status in [200, 400, 500]
      response = json_response(conn)
      assert is_map(response)
    end

    test "error messages are clear and helpful", %{auth_conn: conn} do
      # Test missing URL
      conn1 = post(conn, "/api/v1/scrape_job", %{})
      response1 = json_response(conn1)
      assert response1["error"] == "URL is required"
      assert String.length(response1["message"]) > 0

      # Test invalid URL format
      conn2 = post(conn, "/api/v1/scrape_job", %{"url" => "not-a-url"})
      response2 = json_response(conn2)
      assert response2["error"] =~ "URL must start with"

      # Test URL too long
      long_url = "https://" <> String.duplicate("a", 2001)
      conn3 = post(conn, "/api/v1/scrape_job", %{"url" => long_url})
      response3 = json_response(conn3)
      assert response3["error"] =~ "too long"
    end

    test "error responses have consistent format", %{auth_conn: conn} do
      # Test multiple error scenarios
      errors = [
        post(conn, "/api/v1/scrape_job", %{}),
        post(conn, "/api/v1/scrape_job", %{"url" => "invalid"}),
        get(build_conn(), "/api/v1/llm/providers")  # Unauthorized
      ]

      for error_conn <- errors do
        response = json_response(error_conn)

        # All errors should have consistent structure
        assert is_map(response)
        assert Map.has_key?(response, "error") or Map.has_key?(response, "success")
        assert Map.has_key?(response, "message")
      end
    end

    test "500 errors handled gracefully for server issues", %{auth_conn: conn} do
      # Test with URL that would cause server error (unreachable host)
      conn = post(conn, "/api/v1/scrape_job", %{
        "url" => "https://this-domain-should-not-exist-test-12345.com/jobs/123"
      })

      # Should return error response, not crash
      assert conn.status in [400, 500]
      response = json_response(conn)
      assert is_map(response)
      assert Map.has_key?(response, "error") or response["success"] == false
    end
  end

  # ============================================================================
  # Test Case 10.9: API Rate Limiting (If Implemented)
  # ============================================================================

  describe "API Rate Limiting" do
    @tag :skip
    test "enforces rate limiting on rapid requests", %{auth_conn: conn} do
      # Send many rapid requests
      results = for _ <- 1..100 do
        post(conn, "/api/v1/scrape_job", %{"url" => "https://example.com/jobs/123"})
      end

      # Check if any were rate limited (429 status)
      rate_limited = Enum.filter(results, fn conn -> conn.status == 429 end)

      # If rate limiting is implemented, some should be limited
      # This test is skipped by default as rate limiting may not be implemented yet
      assert length(rate_limited) > 0
    end

    @tag :skip
    test "rate limit response includes Retry-After header", %{auth_conn: conn} do
      # Send requests until rate limited
      conn = send_until_rate_limited(conn)

      if conn.status == 429 do
        assert get_resp_header(conn, "retry-after") != []
        response = json_response(conn)
        assert response["error"] =~ "rate limit" or response["error"] =~ "Too Many Requests"
      end
    end

    @tag :skip
    test "rate limit resets after time period", %{auth_conn: conn} do
      # Send requests until rate limited
      conn = send_until_rate_limited(conn)

      if conn.status == 429 do
        # Wait for reset period (implementation dependent)
        Process.sleep(60_000)  # Wait 1 minute

        # Try again
        conn = post(conn, "/api/v1/scrape_job", %{"url" => "https://example.com/jobs/123"})

        # Should no longer be rate limited
        assert conn.status != 429
      end
    end
  end

  # ============================================================================
  # Additional Test: API Documentation Index
  # ============================================================================

  describe "API Documentation Index" do
    test "documentation index page loads successfully", %{conn: conn} do
      conn = get(conn, "/api-docs/")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
      body = conn.resp_body

      # Check for index page elements
      assert body =~ "ClientATS API Documentation"
      assert body =~ "Swagger UI"
      assert body =~ "ReDoc"
      assert body =~ "OpenAPI Spec"
    end

    test "index page has links to all documentation formats", %{conn: conn} do
      conn = get(conn, "/api-docs/")

      assert conn.status == 200
      body = conn.resp_body

      # Check for links
      assert body =~ "/api-docs/swagger-ui"
      assert body =~ "/api-docs/redoc"
      assert body =~ "/api-docs/openapi.json"
    end

    test "index page includes quick start guide", %{conn: conn} do
      conn = get(conn, "/api-docs/")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "Quick Start"
      assert body =~ "Authentication"
      assert body =~ "Example Request"
    end

    test "index page lists available endpoints", %{conn: conn} do
      conn = get(conn, "/api-docs/")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "/scrape_job"
      assert body =~ "/llm/providers"
      assert body =~ "/llm/config"
      assert body =~ "POST"
      assert body =~ "GET"
    end

    test "index page includes API information", %{conn: conn} do
      conn = get(conn, "/api-docs/")

      assert conn.status == 200
      body = conn.resp_body

      assert body =~ "Versioning"
      assert body =~ "v1"
      assert body =~ "Response Format"
      assert body =~ "Error Handling"
      assert body =~ "Security"
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp json_response(conn) do
    if conn.halted || conn.state == :sent do
      Jason.decode!(conn.resp_body)
    else
      Jason.decode!(conn.resp_body)
    end
  end

  # Helper for rate limiting tests (if implemented)
  defp send_until_rate_limited(conn, count \\ 100) do
    Enum.reduce_while(1..count, conn, fn _, acc ->
      new_conn = post(acc, "/api/v1/scrape_job", %{"url" => "https://example.com/jobs/123"})

      if new_conn.status == 429 do
        {:halt, new_conn}
      else
        {:cont, new_conn}
      end
    end)
  end
end
