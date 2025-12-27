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
        timeout_ms: 5000,
        database_version: "SQLite 3.45.0",
        database: "clientats_dev.db"
      }
  """
  def get_pool_stats do
    config = Repo.config()

    # Get SQLite version
    version =
      case Repo.query("SELECT sqlite_version()", []) do
        {:ok, %{rows: [[version_string | _] | _]}} ->
          "SQLite #{version_string}"

        _ ->
          "Unknown"
      end

    %{
      pool_size: Keyword.get(config, :pool_size, "unknown"),
      timeout_ms: Keyword.get(config, :timeout, 5000),
      database_version: version,
      database: Keyword.get(config, :database, "unknown")
    }
  end

  @doc """
  Gets current database activity statistics.

  Returns information about the database file and basic statistics.
  Note: SQLite is file-based and doesn't track connections like PostgreSQL.

  ## Examples

      iex> get_database_activity()
      %{
        page_count: 100,
        page_size: 4096,
        database_size_bytes: 409600,
        wal_mode: "wal"
      }
  """
  def get_database_activity do
    page_count =
      case Repo.query("PRAGMA page_count", []) do
        {:ok, %{rows: [[count | _] | _]}} -> count
        _ -> 0
      end

    page_size =
      case Repo.query("PRAGMA page_size", []) do
        {:ok, %{rows: [[size | _] | _]}} -> size
        _ -> 4096
      end

    journal_mode =
      case Repo.query("PRAGMA journal_mode", []) do
        {:ok, %{rows: [[mode | _] | _]}} -> mode
        _ -> "unknown"
      end

    %{
      page_count: page_count,
      page_size: page_size,
      database_size_bytes: page_count * page_size,
      journal_mode: journal_mode
    }
  end

  @doc """
  Identifies potentially slow queries or missing indexes.

  Returns a list of observations about database performance.
  Uses SQLite's index_list pragma to inspect indexes.

  ## Examples

      iex> get_performance_insights()
      [
        %{type: "index_info", table: "users", indexes: ["users_email_index"]}
      ]
  """
  def get_performance_insights do
    # Get list of tables
    case Repo.query(
           "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'schema_%'",
           []
         ) do
      {:ok, %{rows: table_rows}} ->
        table_rows
        |> Enum.flat_map(fn [table_name] ->
          case Repo.query("PRAGMA index_list('#{table_name}')", []) do
            {:ok, %{rows: index_rows}} when index_rows != [] ->
              indexes = Enum.map(index_rows, fn [_seq, name | _rest] -> name end)

              [
                %{
                  type: "index_info",
                  table: table_name,
                  indexes: indexes,
                  suggestion: "Review indexes for optimization opportunities"
                }
              ]

            _ ->
              []
          end
        end)
        |> Enum.take(10)

      _ ->
        []
    end
  end

  @doc """
  Gets database configuration documentation as markdown.

  Useful for displaying in UI or logging.
  """
  def get_configuration_docs do
    """
    # SQLite Database Configuration

    ## Environment Variables

    - `DATABASE_PATH`: Path to SQLite database file (default: platform-specific)
      - Linux: ~/.config/clientats/db/clientats.db
      - macOS: ~/Library/Application Support/clientats/db/clientats.db
      - Windows: %APPDATA%/clientats/db/clientats.db
    - `POOL_SIZE`: Number of connections in the pool (default: 5)
    - `POOL_TIMEOUT`: Connection acquisition timeout in ms (default: 5000)

    ## SQLite Advantages

    - No separate database server required
    - Simple file-based storage
    - Easy backup (just copy the file)
    - Perfect for single-user or small team deployments

    ## Recommended Settings

    ### Development
    - POOL_SIZE=5 (default)

    ### Production (single instance)
    - POOL_SIZE=10
    - Enable WAL mode for better concurrency

    ## Performance Tuning

    1. WAL mode is enabled by default for better concurrent read/write
    2. Run `PRAGMA optimize` periodically for query planning
    3. Run `VACUUM` occasionally to reclaim space
    4. Monitor database file size

    ## Health Checks

    - Endpoint: GET /health
    - Returns database connectivity status
    - Use for load balancer health checks
    """
  end
end
