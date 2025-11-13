defmodule Clientats.Repo.Migrations.CreateResumes do
  use Ecto.Migration

  def change do
    create table(:resumes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :file_path, :string, null: false
      add :original_filename, :string, null: false
      add :file_size, :integer
      add :is_default, :boolean, default: false

      timestamps()
    end

    create index(:resumes, [:user_id])
    create index(:resumes, [:is_default])
  end
end
