defmodule Clientats.Repo.Migrations.AddResumeIdToJobApplications do
  use Ecto.Migration

  def change do
    alter table(:job_applications) do
      add :resume_id, references(:resumes, on_delete: :nilify_all)
    end

    create index(:job_applications, [:resume_id])
  end
end
