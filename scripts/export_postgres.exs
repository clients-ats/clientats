# scripts/export_postgres.exs
#
# This script exports data from a PostgreSQL database to a JSON file.
# It uses Postgrex directly to avoid dependency on the main application's Repo configuration.
#
# Usage:
#   mix run scripts/export_postgres.exs --database clientats_prod --output export.json
#
# Environment variables:
#   PGHOST, PGPORT, PGUSER, PGPASSWORD

Mix.install([
  {:postgrex, "~> 0.19"},
  {:jason, "~> 1.4"}
])

defmodule PostgresExporter do
  def export(opts) do
    database = opts[:database] || System.get_env("PGDATABASE") || "clientats_prod"
    output_file = opts[:output] || "postgres_export.json"
    
    IO.puts("Connecting to PostgreSQL database: #{database}...")
    
    {:ok, pid} = Postgrex.start_link(
      hostname: System.get_env("PGHOST") || "localhost",
      port: String.to_integer(System.get_env("PGPORT") || "5432"),
      username: System.get_env("PGUSER") || "postgres",
      password: System.get_env("PGPASSWORD") || "postgres",
      database: database
    )

    tables = [
      "users",
      "job_interests",
      "job_applications",
      "application_events",
      "resumes",
      "cover_letter_templates",
      "llm_settings",
      "audit_logs",
      "help_interactions"
    ]

    data = Enum.into(tables, %{}, fn table ->
      IO.puts("Exporting table: #{table}...")
      {table, fetch_table_data(pid, table)}
    end)

    IO.puts("Writing data to #{output_file}...")
    File.write!(output_file, Jason.encode!(data, pretty: true))
    IO.puts("Export complete!")
  end

  defp fetch_table_data(pid, table) do
    query = "SELECT * FROM #{table}"
    case Postgrex.query(pid, query, []) do
      {:ok, %Postgrex.Result{columns: columns, rows: rows}} ->
        Enum.map(rows, fn row ->
          Enum.zip(columns, row) |> Enum.into(%{})
        end)
      {:error, e} ->
        IO.puts("Error exporting #{table}: #{inspect(e)}")
        []
    end
  end
end

{opts, _, _} = OptionParser.parse(System.argv(),
  strict: [database: :string, output: :string]
)

PostgresExporter.export(opts)
