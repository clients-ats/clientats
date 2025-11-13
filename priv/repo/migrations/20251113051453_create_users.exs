defmodule Clientats.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :hashed_password, :string, null: false
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :resume_path, :string

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
