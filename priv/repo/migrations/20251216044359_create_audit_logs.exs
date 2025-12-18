defmodule Clientats.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary_id
      add :description, :string
      add :ip_address, :string
      add :user_agent, :string
      add :old_values, :map
      add :new_values, :map
      add :status, :string, default: "success"
      add :error_message, :string
      add :metadata, :map, default: "{}"

      timestamps(updated_at: false)
    end

    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:resource_type])
    create index(:audit_logs, [:resource_id])
    create index(:audit_logs, [:inserted_at])
    create index(:audit_logs, [:status])
  end
end
