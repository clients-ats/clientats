defmodule Clientats.Repo.Migrations.InstallObanLite do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 12, engine: :lite)
  end

  def down do
    Oban.Migrations.down(version: 1, engine: :lite)
  end
end
