defmodule Clientats.Repo.Migrations.AddPdfPathsToJobApplications do
  use Ecto.Migration

  def change do
    alter table(:job_applications) do
      add :resume_pdf_path, :string
      add :cover_letter_pdf_path, :string
    end
  end
end
