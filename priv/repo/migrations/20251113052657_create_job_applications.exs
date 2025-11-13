defmodule Clientats.Repo.Migrations.CreateJobApplications do
  use Ecto.Migration

  def change do
    create table(:job_applications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :job_interest_id, references(:job_interests, on_delete: :nilify_all)
      add :company_name, :string, null: false
      add :position_title, :string, null: false
      add :job_description, :text
      add :job_url, :string
      add :location, :string
      add :work_model, :string
      add :salary_min, :integer
      add :salary_max, :integer
      add :application_date, :date, null: false
      add :status, :string, null: false, default: "applied"
      add :cover_letter_path, :string
      add :resume_path, :string
      add :notes, :text

      timestamps()
    end

    create index(:job_applications, [:user_id])
    create index(:job_applications, [:job_interest_id])
    create index(:job_applications, [:status])
    create index(:job_applications, [:application_date])
  end
end
