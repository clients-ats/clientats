defmodule Clientats.Repo.Migrations.AddPrimaryLlmProviderToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :primary_llm_provider, :string, default: "gemini"
    end
  end
end
