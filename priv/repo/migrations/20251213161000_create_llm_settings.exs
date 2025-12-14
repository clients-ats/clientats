defmodule Clientats.Repo.Migrations.CreateLlmSettings do
  use Ecto.Migration

  def change do
    create table(:llm_settings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :api_key, :binary
      add :base_url, :string
      add :default_model, :string
      add :vision_model, :string
      add :text_model, :string
      add :enabled, :boolean, default: false
      add :provider_status, :string

      timestamps()
    end

    create unique_index(:llm_settings, [:user_id, :provider])
  end
end
