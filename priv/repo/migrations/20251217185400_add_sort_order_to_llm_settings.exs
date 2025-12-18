defmodule Clientats.Repo.Migrations.AddSortOrderToLlmSettings do
  use Ecto.Migration

  def change do
    alter table(:llm_settings) do
      add :sort_order, :integer, default: 0
    end
  end
end
