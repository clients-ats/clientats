defmodule Clientats.Repo.Migrations.CreateCoverLetterTemplates do
  use Ecto.Migration

  def change do
    create table(:cover_letter_templates) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :content, :text, null: false
      add :is_default, :boolean, default: false

      timestamps()
    end

    create index(:cover_letter_templates, [:user_id])
    create index(:cover_letter_templates, [:is_default])
  end
end
