defmodule Clientats.Repo.Migrations.CreateObanPeersTable do
  use Ecto.Migration

  def change do
    create table(:oban_peers, primary_key: false) do
      add :node, :string, null: false, primary_key: true
      add :name, :string, null: false
      add :leader, :boolean, null: false, default: false
      add :paused, :boolean, null: false, default: false
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:oban_peers, [:name])
  end
end
