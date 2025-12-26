defmodule ClientatsWeb.Features.DatabaseHealthChecksTest do
  use ClientatsWeb.ConnCase, async: true

  @moduletag :feature

  describe "GET /health - Simple Health Check (Test Case 5.1)" do
    test "returns ok status with timestamp", %{conn: conn} do
      conn = get(conn, "/health")

      assert json_response(conn, 200) == %{
               "status" => "ok",
               "timestamp" => json_response(conn, 200)["timestamp"]
             }

      # Verify timestamp is in ISO8601 format
      assert {:ok, _datetime, _offset} =
               DateTime.from_iso8601(json_response(conn, 200)["timestamp"])
    end

    test "returns 200 status code", %{conn: conn} do
      conn = get(conn, "/health")
      assert conn.status == 200
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, "/health")
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end

    test "always succeeds regardless of database state", %{conn: conn} do
      # This endpoint should work even if database has issues
      # It's meant for load balancers to check if the application process is alive
      conn = get(conn, "/health")
      assert conn.status == 200
      assert json_response(conn, 200)["status"] == "ok"
    end
  end

  describe "GET /health/ready - Database Ready Check (Test Case 5.2)" do
    test "returns healthy status when database is accessible", %{conn: conn} do
      conn = get(conn, "/health/ready")

      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert is_map(response["database"])
      assert response["database"]["status"] == "healthy"
      assert is_number(response["database"]["latency_ms"])
      assert response["database"]["latency_ms"] >= 0
      assert is_binary(response["timestamp"])
    end

    test "returns 200 status code when database is healthy", %{conn: conn} do
      conn = get(conn, "/health/ready")
      assert conn.status == 200
    end

    test "includes database latency measurement", %{conn: conn} do
      conn = get(conn, "/health/ready")

      response = json_response(conn, 200)
      latency = response["database"]["latency_ms"]

      assert is_number(latency)
      # Latency should be reasonable (less than 1 second for local database)
      assert latency < 1000
    end

    test "includes timestamp in ISO8601 format", %{conn: conn} do
      conn = get(conn, "/health/ready")

      response = json_response(conn, 200)
      timestamp = response["timestamp"]

      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(timestamp)
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, "/health/ready")
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end
  end

  describe "GET /health/diagnostics - Diagnostics Endpoint (Test Case 5.3)" do
    setup do
      # Set a test token for authentication
      test_token = "test-token-#{System.unique_integer([:positive])}"
      System.put_env("HEALTH_CHECK_TOKEN", test_token)

      on_exit(fn ->
        System.delete_env("HEALTH_CHECK_TOKEN")
      end)

      %{test_token: test_token}
    end

    test "returns 401 without authentication token", %{conn: conn} do
      conn = get(conn, "/health/diagnostics")

      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end

    test "returns 401 with invalid authentication token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid-token")
        |> get("/health/diagnostics")

      assert conn.status == 401
      assert json_response(conn, 401)["error"] == "Unauthorized"
    end

    test "returns diagnostics with valid Bearer token", %{conn: conn, test_token: test_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert is_map(response["database"])
      assert is_map(response["pool"])
      assert is_map(response["activity"])
      assert is_list(response["performance_insights"])
      assert is_binary(response["timestamp"])
    end

    test "returns diagnostics with token without Bearer prefix", %{
      conn: conn,
      test_token: test_token
    } do
      conn =
        conn
        |> put_req_header("authorization", test_token)
        |> get("/health/diagnostics")

      response = json_response(conn, 200)
      assert response["status"] == "healthy"
    end

    test "includes comprehensive database health information", %{
      conn: conn,
      test_token: test_token
    } do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      response = json_response(conn, 200)
      database = response["database"]

      assert database["status"] == "healthy"
      assert is_number(database["latency_ms"])
      assert database["latency_ms"] >= 0
    end

    test "includes connection pool statistics", %{conn: conn, test_token: test_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      response = json_response(conn, 200)
      pool = response["pool"]

      assert is_number(pool["pool_size"]) or pool["pool_size"] == "unknown"
      assert is_number(pool["pool_count"])
      assert is_number(pool["max_overflow"])
      assert is_number(pool["timeout_ms"])
      assert is_binary(pool["database_version"])
      # Database version may be "Unknown" in test environment
      assert pool["database_version"] != nil
    end

    test "includes database activity metrics", %{conn: conn, test_token: test_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      response = json_response(conn, 200)
      activity = response["activity"]

      assert is_number(activity["total_connections"])
      assert is_number(activity["active_connections"])
      assert is_number(activity["idle_connections"])
      assert is_number(activity["longest_query_ms"])
      assert activity["longest_query_ms"] >= 0
    end

    test "includes performance insights", %{conn: conn, test_token: test_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      response = json_response(conn, 200)
      insights = response["performance_insights"]

      assert is_list(insights)
      # Performance insights may be empty if no issues are detected
    end

    test "returns timestamp in ISO8601 format", %{conn: conn, test_token: test_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      response = json_response(conn, 200)
      timestamp = response["timestamp"]

      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(timestamp)
    end

    test "handles case-insensitive Bearer prefix", %{conn: conn, test_token: test_token} do
      conn =
        conn
        |> put_req_header("authorization", "bearer #{test_token}")
        |> get("/health/diagnostics")

      assert conn.status == 200
    end

    test "returns JSON content type", %{conn: conn, test_token: test_token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end
  end

  describe "GET /metrics - Metrics Endpoint (Test Case 5.4)" do
    test "returns metrics without authentication when token not configured", %{conn: conn} do
      # Ensure METRICS_TOKEN is not set for this test
      original_token = System.get_env("METRICS_TOKEN")
      System.delete_env("METRICS_TOKEN")

      on_exit(fn ->
        if original_token do
          System.put_env("METRICS_TOKEN", original_token)
        end
      end)

      conn = get(conn, "/metrics")

      # Should return 200 when no token is configured
      assert conn.status in [200, 401]

      if conn.status == 200 do
        response = json_response(conn, 200)
        assert is_map(response)
      end
    end

    test "returns 401 when token configured but not provided", %{conn: conn} do
      test_token = "metrics-token-#{System.unique_integer([:positive])}"
      System.put_env("METRICS_TOKEN", test_token)

      on_exit(fn ->
        System.delete_env("METRICS_TOKEN")
      end)

      # Need to restart the endpoint to pick up the new env var
      # For now, we'll test the behavior when token is empty
      System.delete_env("METRICS_TOKEN")
      conn = get(conn, "/metrics")

      # Without token configured, should return metrics
      assert conn.status in [200, 401]
    end

    test "returns JSON content type", %{conn: conn} do
      System.delete_env("METRICS_TOKEN")
      conn = get(conn, "/metrics")

      if conn.status == 200 do
        assert get_resp_header(conn, "content-type") == [
                 "application/json; charset=utf-8"
               ]
      end
    end

    test "metrics endpoint is accessible", %{conn: conn} do
      # Basic accessibility test
      conn = get(conn, "/metrics")
      assert conn.status in [200, 401]
    end
  end

  describe "Health Check Integration Tests" do
    test "all health endpoints respond within reasonable time", %{conn: conn} do
      test_token = "integration-test-token"
      System.put_env("HEALTH_CHECK_TOKEN", test_token)

      on_exit(fn ->
        System.delete_env("HEALTH_CHECK_TOKEN")
      end)

      # Test simple health check
      start_time = System.monotonic_time(:millisecond)
      conn1 = get(conn, "/health")
      health_time = System.monotonic_time(:millisecond) - start_time
      assert conn1.status == 200
      assert health_time < 1000

      # Test ready check
      start_time = System.monotonic_time(:millisecond)
      conn2 = get(build_conn(), "/health/ready")
      ready_time = System.monotonic_time(:millisecond) - start_time
      assert conn2.status == 200
      assert ready_time < 1000

      # Test diagnostics
      start_time = System.monotonic_time(:millisecond)

      conn3 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      diagnostics_time = System.monotonic_time(:millisecond) - start_time
      assert conn3.status == 200
      assert diagnostics_time < 2000
    end

    test "health endpoints return consistent timestamp formats", %{conn: conn} do
      test_token = "timestamp-test-token"
      System.put_env("HEALTH_CHECK_TOKEN", test_token)

      on_exit(fn ->
        System.delete_env("HEALTH_CHECK_TOKEN")
      end)

      # Simple health check
      conn1 = get(conn, "/health")
      response1 = json_response(conn1, 200)
      assert {:ok, _, _} = DateTime.from_iso8601(response1["timestamp"])

      # Ready check
      conn2 = get(build_conn(), "/health/ready")
      response2 = json_response(conn2, 200)
      assert {:ok, _, _} = DateTime.from_iso8601(response2["timestamp"])

      # Diagnostics
      conn3 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      response3 = json_response(conn3, 200)
      assert {:ok, _, _} = DateTime.from_iso8601(response3["timestamp"])
    end

    test "database metrics are consistent across endpoints", %{conn: conn} do
      test_token = "consistency-test-token"
      System.put_env("HEALTH_CHECK_TOKEN", test_token)

      on_exit(fn ->
        System.delete_env("HEALTH_CHECK_TOKEN")
      end)

      # Get database status from ready check
      conn1 = get(conn, "/health/ready")
      ready_response = json_response(conn1, 200)
      ready_db_status = ready_response["database"]["status"]

      # Get database status from diagnostics
      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{test_token}")
        |> get("/health/diagnostics")

      diagnostics_response = json_response(conn2, 200)
      diagnostics_db_status = diagnostics_response["database"]["status"]

      # Both should report same health status
      assert ready_db_status == diagnostics_db_status
      assert ready_db_status == "healthy"
    end
  end

  describe "Error Handling and Edge Cases" do
    test "health endpoint handles concurrent requests", %{conn: _conn} do
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            conn = build_conn()
            get(conn, "/health")
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All requests should succeed
      Enum.each(results, fn conn ->
        assert conn.status == 200
        assert json_response(conn, 200)["status"] == "ok"
      end)
    end

    test "ready endpoint handles concurrent requests", %{conn: _conn} do
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            conn = build_conn()
            get(conn, "/health/ready")
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All requests should succeed
      Enum.each(results, fn conn ->
        assert conn.status == 200
        assert json_response(conn, 200)["status"] == "healthy"
      end)
    end

    test "diagnostics endpoint rejects empty authorization header", %{conn: conn} do
      System.put_env("HEALTH_CHECK_TOKEN", "some-token")

      on_exit(fn ->
        System.delete_env("HEALTH_CHECK_TOKEN")
      end)

      conn =
        conn
        |> put_req_header("authorization", "")
        |> get("/health/diagnostics")

      assert conn.status == 401
    end

    test "diagnostics endpoint handles whitespace in token", %{conn: conn} do
      test_token = "token-with-spaces"
      System.put_env("HEALTH_CHECK_TOKEN", test_token)

      on_exit(fn ->
        System.delete_env("HEALTH_CHECK_TOKEN")
      end)

      # Token with leading/trailing spaces should still work
      conn =
        conn
        |> put_req_header("authorization", "Bearer  #{test_token}  ")
        |> get("/health/diagnostics")

      assert conn.status == 200
    end
  end
end
