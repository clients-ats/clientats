defmodule Clientats.Repo.Migrations.CreateApplicationEvents do
  use Ecto.Migration

  def change do
    create table(:application_events) do
      add :job_application_id, references(:job_applications, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :event_date, :date, null: false
      add :contact_person, :string
      add :contact_email, :string
      add :contact_phone, :string
      add :notes, :text
      add :follow_up_date, :date

      timestamps()
    end

    create index(:application_events, [:job_application_id])
    create index(:application_events, [:event_type])
    create index(:application_events, [:event_date])
  end
end
