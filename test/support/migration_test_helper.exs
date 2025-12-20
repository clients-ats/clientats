defmodule Clientats.MigrationTestHelper do
  @moduledoc """
  Helper functions for testing database migrations.

  Provides utilities for:
  - Running migrations up/down
  - Verifying table and column existence
  - Testing foreign key constraints
  - Testing indexes and uniqueness constraints
  """

  alias Ecto.Adapters.SQL
  alias Clientats.Repo

  # Determine database adapter
  defp is_sqlite? do
    Repo.__adapter__() == Ecto.Adapters.SQLite3
  end

  @doc """
  Execute a SQL query that works with both SQLite and PostgreSQL.

  For DELETE queries with parameters, uses $1 syntax for PostgreSQL and ? for SQLite.
  """
  def execute_query(query_template, params) when is_binary(query_template) and is_list(params) do
    if is_sqlite?() do
      # Convert $1, $2, etc. to ?
      sqlite_query = convert_postgres_to_sqlite_params(query_template)
      SQL.query(Repo, sqlite_query, params)
    else
      SQL.query(Repo, query_template, params)
    end
  end

  @doc """
  Convert PostgreSQL parameter syntax ($1, $2, etc.) to SQLite syntax (?)
  """
  def convert_postgres_to_sqlite_params(query) do
    # Replace $1, $2, $3, etc. with ?
    Regex.replace(~r/\$\d+/, query, "?")
  end

  @doc """
  Run a specific migration up.

  Returns {:ok, module} or {:error, reason}
  """
  def run_migration_up(migration_module) when is_atom(migration_module) do
    try do
      migration_module.up()
      {:ok, migration_module}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Run a specific migration down.

  Returns {:ok, module} or {:error, reason}
  """
  def run_migration_down(migration_module) when is_atom(migration_module) do
    try do
      migration_module.down()
      {:ok, migration_module}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Check if a table exists in the database.
  """
  def table_exists?(table_name) when is_atom(table_name) do
    table_exists?(Atom.to_string(table_name))
  end

  def table_exists?(table_name) when is_binary(table_name) do
    if is_sqlite?() do
      # SQLite: use sqlite_master
      {:ok, result} =
        SQL.query(
          Repo,
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",
          [table_name]
        )

      result.rows != []
    else
      # PostgreSQL: use information_schema
      {:ok, result} =
        SQL.query(
          Repo,
          """
          SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = $1
          )
          """,
          [table_name]
        )

      [[exists]] = result.rows
      exists
    end
  end

  @doc """
  Get all columns for a table.

  Returns list of column names.
  """
  def get_table_columns(table_name) when is_atom(table_name) do
    get_table_columns(Atom.to_string(table_name))
  end

  def get_table_columns(table_name) when is_binary(table_name) do
    if is_sqlite?() do
      # SQLite: use PRAGMA table_info
      {:ok, result} = SQL.query(Repo, "PRAGMA table_info(#{table_name})", [])
      # Returns: [cid, name, type, notnull, dflt_value, pk]
      Enum.map(result.rows, fn row -> Enum.at(row, 1) end)
    else
      # PostgreSQL: use information_schema
      {:ok, result} =
        SQL.query(
          Repo,
          """
          SELECT column_name
          FROM information_schema.columns
          WHERE table_schema = 'public'
          AND table_name = $1
          ORDER BY ordinal_position
          """,
          [table_name]
        )

      Enum.map(result.rows, fn [col_name] -> col_name end)
    end
  end

  @doc """
  Check if a column exists in a table.
  """
  def column_exists?(table_name, column_name) do
    columns = get_table_columns(table_name)
    column_name_str = if is_atom(column_name), do: Atom.to_string(column_name), else: column_name
    column_name_str in columns
  end

  @doc """
  Get column info including type and constraints.
  """
  def get_column_info(table_name, column_name)
      when is_binary(table_name) and is_binary(column_name) do
    if is_sqlite?() do
      # SQLite: use PRAGMA table_info
      {:ok, result} = SQL.query(Repo, "PRAGMA table_info(#{table_name})", [])
      # Returns: [cid, name, type, notnull, dflt_value, pk]
      col_info = Enum.find(result.rows, fn row -> Enum.at(row, 1) == column_name end)

      case col_info do
        [_cid, _name, type, notnull, default, _pk] ->
          {:ok,
           %{
             data_type: type,
             nullable: notnull == 0,
             default: default
           }}

        nil ->
          {:error, :column_not_found}
      end
    else
      # PostgreSQL: use information_schema
      {:ok, result} =
        SQL.query(
          Repo,
          """
          SELECT
            data_type,
            is_nullable,
            column_default
          FROM information_schema.columns
          WHERE table_schema = 'public'
          AND table_name = $1
          AND column_name = $2
          """,
          [table_name, column_name]
        )

      case result.rows do
        [[data_type, is_nullable, column_default]] ->
          {:ok,
           %{
             data_type: data_type,
             nullable: is_nullable == "YES",
             default: column_default
           }}

        [] ->
          {:error, :column_not_found}
      end
    end
  end

  @doc """
  Check if an index exists on a table.
  """
  def index_exists?(table_name, index_name)
      when is_binary(table_name) and is_binary(index_name) do
    if is_sqlite?() do
      # SQLite: use sqlite_master
      {:ok, result} =
        SQL.query(
          Repo,
          "SELECT 1 FROM sqlite_master WHERE type='index' AND name=?",
          [index_name]
        )

      result.rows != []
    else
      # PostgreSQL: use pg_indexes
      {:ok, result} =
        SQL.query(
          Repo,
          """
          SELECT EXISTS (
            SELECT FROM pg_indexes
            WHERE schemaname = 'public'
            AND tablename = $1
            AND indexname = $2
          )
          """,
          [table_name, index_name]
        )

      [[exists]] = result.rows
      exists
    end
  end

  @doc """
  Get all indexes for a table.
  """
  def get_table_indexes(table_name) when is_binary(table_name) do
    if is_sqlite?() do
      # SQLite: use sqlite_master for index information
      {:ok, result} =
        SQL.query(
          Repo,
          "SELECT name, sql FROM sqlite_master WHERE type='index' AND tbl_name=?",
          [table_name]
        )

      Enum.map(result.rows, fn [name, definition] ->
        %{name: name, definition: definition}
      end)
    else
      # PostgreSQL: use pg_indexes
      {:ok, result} =
        SQL.query(
          Repo,
          """
          SELECT indexname, indexdef
          FROM pg_indexes
          WHERE schemaname = 'public'
          AND tablename = $1
          """,
          [table_name]
        )

      Enum.map(result.rows, fn [name, definition] ->
        %{name: name, definition: definition}
      end)
    end
  end

  @doc """
  Check if a foreign key exists.
  """
  def foreign_key_exists?(from_table, to_table)
      when is_binary(from_table) and is_binary(to_table) do
    if is_sqlite?() do
      # SQLite: use PRAGMA foreign_key_list
      {:ok, result} = SQL.query(Repo, "PRAGMA foreign_key_list(#{from_table})", [])
      # Returns: [id, seq, table, from, to, on_delete, on_update, match]
      result.rows != []
    else
      # PostgreSQL: use information_schema
      {:ok, result} =
        SQL.query(
          Repo,
          """
          SELECT EXISTS (
            SELECT FROM information_schema.table_constraints
            WHERE constraint_type = 'FOREIGN KEY'
            AND table_name = $1
          )
          """,
          [from_table]
        )

      [[exists]] = result.rows
      exists
    end
  end

  @doc """
  Count rows in a table.
  """
  def count_rows(table_name) when is_binary(table_name) do
    {:ok, result} = SQL.query(Repo, "SELECT COUNT(*) FROM #{table_name}", [])
    [[count]] = result.rows
    count
  end

  @doc """
  Get unique constraint names for a table.
  """
  def get_unique_constraints(table_name) when is_binary(table_name) do
    if is_sqlite?() do
      # SQLite: use sqlite_master to find UNIQUE indexes
      {:ok, result} =
        SQL.query(
          Repo,
          "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name=? AND unique=1",
          [table_name]
        )

      Enum.map(result.rows, fn [name] -> name end)
    else
      # PostgreSQL: use information_schema
      {:ok, result} =
        SQL.query(
          Repo,
          """
          SELECT constraint_name
          FROM information_schema.table_constraints
          WHERE constraint_type = 'UNIQUE'
          AND table_name = $1
          """,
          [table_name]
        )

      Enum.map(result.rows, fn [name] -> name end)
    end
  end

  @doc """
  Insert test data into a table.

  Automatically adds timestamps if not provided.
  Returns {:ok, result} or {:error, reason}
  """
  def insert_data(table_name, data) when is_binary(table_name) and is_map(data) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Add timestamps if not already provided
    data_with_timestamps =
      data
      |> Map.put_new("inserted_at", now)
      |> Map.put_new("updated_at", now)

    columns = Map.keys(data_with_timestamps)
    values = Map.values(data_with_timestamps)

    column_list = Enum.join(columns, ", ")

    if is_sqlite?() do
      # SQLite uses ? for placeholders
      placeholders = columns |> Enum.map(fn _ -> "?" end) |> Enum.join(", ")
      insert_query = "INSERT INTO #{table_name} (#{column_list}) VALUES (#{placeholders})"

      case SQL.query(Repo, insert_query, values) do
        {:ok, _insert_result} ->
          # SQLite doesn't have RETURNING, so we need to query back the inserted row
          # Get the last inserted rowid and select that row
          {:ok, result} = SQL.query(Repo, "SELECT last_insert_rowid()", [])
          [[rowid]] = result.rows

          select_query = "SELECT * FROM #{table_name} WHERE rowid = ?"
          SQL.query(Repo, select_query, [rowid])

        {:error, reason} ->
          {:error, reason}
      end
    else
      # PostgreSQL uses $1, $2, etc. and RETURNING for result
      placeholders =
        columns |> Enum.with_index(1) |> Enum.map(fn {_, i} -> "$#{i}" end) |> Enum.join(", ")

      query = "INSERT INTO #{table_name} (#{column_list}) VALUES (#{placeholders}) RETURNING *"
      SQL.query(Repo, query, values)
    end
  end

  @doc """
  Verify referential integrity - check if a foreign key value exists in parent table.
  """
  def fk_value_exists?(parent_table, parent_id_col, child_value) when is_binary(parent_table) do
    {:ok, result} =
      SQL.query(
        Repo,
        "SELECT EXISTS (SELECT 1 FROM #{parent_table} WHERE #{parent_id_col} = $1)",
        [child_value]
      )

    [[exists]] = result.rows
    exists
  end
end
