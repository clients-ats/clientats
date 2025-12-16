defmodule Clientats.DatabaseHealth do
  @moduledoc """
  Database health check and monitoring utilities.

  Provides functions to check database connectivity and pool health status.
  """

  alias Clientats.Repo

  @doc """
  Checks if the database is healthy and accessible.

  Returns a tuple with status and details about the connection pool.

  ## Examples

      iex> check_health()
      {:ok, %{status: "healthy", latency_ms: 2, pool_available: 8}}

      iex> check_health()
      {:error, %{status: "down", reason: "connection refused"}}
  """
  def check_health do
    start_time = System.monotonic_time(:millisecond)

    case Repo.query("SELECT 1", []) do
      {:ok, _result} ->
        latency = System.monotonic_time(:millisecond) - start_time
        {:ok, %{status: "healthy", latency_ms: latency}}

      {:error, reason} ->
        {:error, %{status: "down", reason: inspect(reason)}}
    end
  end

  @doc """
  Gets detailed database and connection pool statistics.

  Returns information about the current state of the database connection pool.

  ## Examples

      iex> get_pool_stats()
      %{
        pool_size: 10,
        pool_count: 1,
        max_overflow: 0,
        timeout_ms: 5000,
        database_version: "PostgreSQL 15.1",
        active_connections: 2
      }
  """
  def get_pool_stats do
    config = Repo.config()

    # Get PostgreSQL version
    version =
      case Repo.query("SELECT version()", []) do
        {:ok, %{rows: [[version_string | _] | _]}} ->
          version_string
            |> String.split(",")
            |> List.first()

        _ ->
          "Unknown"
      end

    %{
      pool_size: Keyword.get(config, :pool_size, "unknown"),
      pool_count: Keyword.get(config, :pool_count, 1),
      max_overflow: Keyword.get(config, :max_overflow, 0),
      timeout_ms: Keyword.get(config, :timeout, 5000),
      database_version: version,
      hostname: Keyword.get(config, :hostname, "unknown"),
      database: Keyword.get(config, :database, "unknown")
    }
  end

  @doc """
  Gets current database activity statistics.

  Returns information about active connections and queries.

  ## Examples

      iex> get_database_activity()
      %{
        active_connections: 5,
        idle_connections: 3,
        active_queries: 2,
        longest_query_ms: 1234
      }
  """
  def get_database_activity do
    case Repo.query(
      """
      SELECT
        count(*) as total_connections,
        count(CASE WHEN state = 'active' THEN 1 END) as active,
        count(CASE WHEN state = 'idle' THEN 1 END) as idle,
        max(EXTRACT(EPOCH FROM (now() - query_start)) * 1000) as longest_query_ms
      FROM pg_stat_activity
      WHERE datname = current_database()
      """,
      []
    ) do
      {:ok, %{rows: rows}} when is_list(rows) and length(rows) > 0 ->
        [total, active, idle, longest] = List.first(rows)
        %{
          total_connections: total,
          active_connections: active,
          idle_connections: idle,
          longest_query_ms: longest || 0
        }

      _ ->
        %{
          total_connections: 0,
          active_connections: 0,
          idle_connections: 0,
          longest_query_ms: 0
        }
    end
  end

  @doc """
  Identifies potentially slow queries or missing indexes.

  Returns a list of observations about database performance.

  ## Examples

      iex> get_performance_insights()
      [
        %{type: "missing_index", table: "users", column: "email", reason: "Frequently used in WHERE clause"},
        %{type: "slow_query", query: "SELECT * FROM jobs", duration_ms: 5234, count: 42}
      ]
  """
  def get_performance_insights do
    case Repo.query(
      """
      SELECT
        schemaname,
        tablename,
        indexname
      FROM pg_stat_user_indexes
      WHERE idx_scan = 0
        AND indexname NOT LIKE '%_pkey'
      LIMIT 10
      """,
      []
    ) do
      {:ok, result} ->
        Enum.map(result.rows, fn [schema, table, index] ->
          %{
            type: "unused_index",
            schema: schema,
            table: table,
            index: index,
            suggestion: "Consider dropping unused indexes to improve write performance"
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Gets connection pool configuration documentation as markdown.

  Useful for displaying in UI or logging.
  """
  def get_configuration_docs do
    """
    # Database Connection Pool Configuration

    ## Environment Variables

    - `POOL_SIZE`: Number of connections in each pool (default: 10)
    - `POOL_COUNT`: Number of independent pools (default: 1)
    - `MAX_OVERFLOW`: Maximum overflow connections allowed (default: 0)
    - `POOL_TIMEOUT`: Connection acquisition timeout in ms (default: 5000)
    - `DATABASE_SSL`: Enable SSL for database connection (default: false)
    - `DATABASE_URL`: PostgreSQL connection string (required in production)

    ## Recommended Settings

    ### Small Deployments (1-5 users)
    - POOL_SIZE=10
    - POOL_COUNT=1
    - MAX_OVERFLOW=2

    ### Medium Deployments (5-100 users)
    - POOL_SIZE=20
    - POOL_COUNT=2
    - MAX_OVERFLOW=10

    ### Large Deployments (100+ users)
    - POOL_SIZE=30
    - POOL_COUNT=4
    - MAX_OVERFLOW=20

    ## Performance Tuning

    1. Monitor `pool_timeout` errors - if frequent, increase `POOL_SIZE`
    2. Watch `query_queue_time` metrics - indicates pool contention
    3. Use `POOL_COUNT` to distribute connections across multiple pools
    4. Enable `DATABASE_SSL` in production for security
    5. Separate Oban job queue connections if heavy background processing

    ## Health Checks

    - Endpoint: GET /health
    - Returns database connectivity status
    - Use for load balancer health checks
    """
  end
end
