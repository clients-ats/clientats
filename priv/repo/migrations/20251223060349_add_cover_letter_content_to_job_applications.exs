defmodule Clientats.Repo.Migrations.AddCoverLetterContentToJobApplications do
  use Ecto.Migration

  def change do
    alter table(:job_applications) do
      add :cover_letter_content, :text
    end
  end
end
