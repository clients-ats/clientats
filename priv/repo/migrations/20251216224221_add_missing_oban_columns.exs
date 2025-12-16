defmodule Clientats.Repo.Migrations.AddMissingObanColumns do
  use Ecto.Migration

  def change do
    alter table(:oban_jobs) do
      add :attempted_by, {:array, :string}, default: []
      add :cancelled_at, :utc_datetime_usec
      add :discarded_at, :utc_datetime_usec
    end
  end
end
