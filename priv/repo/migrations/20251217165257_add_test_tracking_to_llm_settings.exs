defmodule Clientats.Repo.Migrations.AddTestTrackingToLlmSettings do
  use Ecto.Migration

  def change do
    alter table(:llm_settings) do
      add :last_tested_at, :naive_datetime
      add :last_error, :text
    end
  end
end
