defmodule Clientats.Repo.Migrations.CreateHelpInteractions do
  use Ecto.Migration

  def change do
    create table(:help_interactions) do
      add :user_id, :string, null: false
      add :interaction_type, :string, null: false
      add :feature, :string
      add :element, :string
      add :context, :jsonb
      add :feedback, :text
      add :helpful, :boolean

      timestamps(type: :utc_datetime)
    end

    create index(:help_interactions, [:user_id, :inserted_at])
    create index(:help_interactions, [:interaction_type])
    create index(:help_interactions, [:feature])
  end
end
