defmodule Clientats.Repo.Migrations.AddDataToResumes do
  use Ecto.Migration

  def change do
    alter table(:resumes) do
      add :data, :binary
    end
  end
end