defmodule Clientats.Repo.Migrations.AddIsValidToResumes do
  use Ecto.Migration

  def change do
    alter table(:resumes) do
      add :is_valid, :boolean, default: true, null: false
    end
  end
end
