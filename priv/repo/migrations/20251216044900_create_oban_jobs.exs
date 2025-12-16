defmodule Clientats.Repo.Migrations.CreateObanJobs do
  use Ecto.Migration

  def up do
    create table(:oban_jobs, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :state, :string, null: false, default: "available"
      add :queue, :string, null: false, default: "default"
      add :worker, :string, null: false
      add :args, :jsonb, null: false, default: "{}"
      add :meta, :jsonb, null: false, default: "{}"
      add :errors, {:array, :jsonb}, null: false, default: []
      add :attempt, :integer, null: false, default: 0
      add :max_attempts, :integer, null: false, default: 20
      add :priority, :integer, null: false, default: 0
      add :tags, {:array, :string}, null: false, default: []
      add :scheduled_at, :utc_datetime_usec
      add :attempted_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:oban_jobs, [:state, :queue, :priority, :scheduled_at])
    create index(:oban_jobs, [:queue, :state])
    create index(:oban_jobs, [:state])
    create index(:oban_jobs, [:completed_at])
  end

  def down do
    drop table(:oban_jobs)
  end
end
