defmodule ClientatsWeb.HealthController do
  use ClientatsWeb, :controller

  alias Clientats.DatabaseHealth

  @moduledoc """
  Health check endpoints for monitoring and load balancers.

  Provides simple endpoints to verify application and database health.
  """

  @doc """
  Simple health check endpoint.

  Returns 200 OK if the application is running, regardless of database status.

  Used by load balancers to verify the application process is alive.
  """
  def simple(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
  end

  @doc """
  Detailed health check endpoint.

  Returns database connectivity status and connection pool information.

  Returns 200 if database is healthy, 503 if database is down.
  """
  def detailed(conn, _params) do
    case DatabaseHealth.check_health() do
      {:ok, health_status} ->
        json(conn, %{
          status: "healthy",
          database: health_status,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, error} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          error: error,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
    end
  end

  @doc """
  Comprehensive system health and diagnostics.

  Returns detailed information about database, connection pool, and performance.

  Requires authentication token via HEALTH_CHECK_TOKEN environment variable.
  """
  def diagnostics(conn, _params) do
    with token <- get_req_header(conn, "authorization"),
         expected_token <- System.get_env("HEALTH_CHECK_TOKEN"),
         true <- verify_token(token, expected_token) do
      case DatabaseHealth.check_health() do
        {:ok, health_status} ->
          json(conn, %{
            status: "healthy",
            database: health_status,
            pool: DatabaseHealth.get_pool_stats(),
            activity: DatabaseHealth.get_database_activity(),
            performance_insights: DatabaseHealth.get_performance_insights(),
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          })

        {:error, error} ->
          conn
          |> put_status(:service_unavailable)
          |> json(%{
            status: "unhealthy",
            error: error,
            pool: DatabaseHealth.get_pool_stats(),
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          })
      end
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
    end
  end

  defp verify_token([], _expected), do: false

  defp verify_token([token | _], expected_token) do
    # Handle both "Bearer TOKEN" and "TOKEN" formats
    normalized_token =
      token
      |> String.replace(~r/^Bearer\s+/i, "")
      |> String.trim()

    expected = expected_token && String.trim(expected_token)
    Plug.Crypto.secure_compare(normalized_token, expected || "")
  end
end
