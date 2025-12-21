defmodule Mix.Tasks.Db.MigrateFromJson do
  use Mix.Task

  @shortdoc "Migrates data from a JSON export into the SQLite database"

  @moduledoc """
  Migrates data from a JSON export into the SQLite database.
  
  Usage:
    mix db.migrate_from_json --input export.json
  """

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [input: :string])
    input_file = opts[:input] || "postgres_export.json"

    if !File.exists?(input_file) do
      Mix.raise("Input file not found: #{input_file}")
    end

    # Start the application and its dependencies
    Mix.Task.run("app.start")

    IO.puts("Reading data from #{input_file}...")
    json_data = File.read!(input_file) |> Jason.decode!()

    # Support both new versioned format and old raw format
    data = if Map.has_key?(json_data, "tables"), do: json_data["tables"], else: json_data

    repo = Clientats.Repo
    
    # Order matters for foreign keys
    tables = [
      "users",
      "llm_settings",
      "resumes",
      "cover_letter_templates",
      "job_interests",
      "job_applications",
      "application_events",
      "audit_logs",
      "help_interactions"
    ]

    repo.transaction(fn ->
      Enum.each(tables, fn table_name ->
        if Map.has_key?(data, table_name) do
          IO.puts("Importing table: #{table_name}...")
          import_table(repo, table_name, data[table_name])
        else
          IO.puts("Skipping table (not in export): #{table_name}")
        end
      end)
    end)

    IO.puts("Migration complete!")
  end

  defp import_table(repo, "users", rows) do
    Enum.each(rows, fn row ->
      # Remove timestamps if they are handled by Ecto or manually insert them
      # We insert them manually to preserve history
      repo.insert_all("users", [prepare_row(row)])
    end)
  end

  defp import_table(repo, table_name, rows) do
    # Batch insert for performance
    prepared_rows = Enum.map(rows, &prepare_row/1)
    
    # SQLite has limits on number of parameters (usually 999 or 32766)
    # We'll chunk it just in case
    Enum.chunk_every(prepared_rows, 50)
    |> Enum.each(fn chunk ->
      repo.insert_all(table_name, chunk)
    end)
  end

  defp prepare_row(row) do
    Enum.into(row, %{}, fn {k, v} ->
      {String.to_atom(k), parse_value(v)}
    end)
  end

  defp parse_value(nil), do: nil
  defp parse_value(v) when is_binary(v) do
    # Try parsing ISO 8601 timestamps
    case DateTime.from_iso8601(v) do
      {:ok, dt, _} -> DateTime.to_naive(dt)
      _ -> v
    end
  end
  defp parse_value(v), do: v
end
