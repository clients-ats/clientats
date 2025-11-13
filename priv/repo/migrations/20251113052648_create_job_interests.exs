defmodule Clientats.Repo.Migrations.CreateJobInterests do
  use Ecto.Migration

  def change do
    create table(:job_interests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :company_name, :string, null: false
      add :position_title, :string, null: false
      add :job_description, :text
      add :job_url, :string
      add :location, :string
      add :work_model, :string
      add :salary_min, :integer
      add :salary_max, :integer
      add :status, :string, null: false, default: "interested"
      add :priority, :string, default: "medium"
      add :notes, :text

      timestamps()
    end

    create index(:job_interests, [:user_id])
    create index(:job_interests, [:status])
    create index(:job_interests, [:priority])
  end
end
