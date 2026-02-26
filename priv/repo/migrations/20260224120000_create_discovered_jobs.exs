defmodule Clientats.Repo.Migrations.CreateDiscoveredJobs do
  use Ecto.Migration

  def up do
    create table(:discovered_jobs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :company, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :url, :string
      add :location, :string
      add :work_model, :string
      add :salary, :string
      add :source, :string, null: false, default: "linkedin"
      add :source_id, :string
      add :status, :string, null: false, default: "new"
      add :extracted_data, :map, default: %{}
      add :score, :float
      add :fingerprint, :string, null: false
      add :promoted_job_interest_id, references(:job_interests, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:discovered_jobs, [:user_id, :fingerprint])
    create index(:discovered_jobs, [:user_id, :status])

    # vec0 virtual table for discovered job embeddings
    # 768 dimensions matches nomic-embed-text (Ollama) and gemini-embedding-001
    execute("""
    CREATE VIRTUAL TABLE vec_discovered_job_embeddings USING vec0(
      discovered_job_id INTEGER PRIMARY KEY,
      title_embedding float[768] distance_metric=cosine,
      description_embedding float[768] distance_metric=cosine
    )
    """)

    create table(:discovered_job_feedback) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :discovered_job_id, references(:discovered_jobs, on_delete: :delete_all), null: false
      add :feedback_type, :string, null: false
      add :value, :float
      add :metadata, :map, default: %{}

      timestamps(updated_at: false)
    end

    create index(:discovered_job_feedback, [:user_id])
    create index(:discovered_job_feedback, [:discovered_job_id])

    create unique_index(:discovered_job_feedback, [:user_id, :discovered_job_id, :feedback_type],
             name: :discovered_job_feedback_unique_signal
           )
  end

  def down do
    drop table(:discovered_job_feedback)
    execute("DROP TABLE IF EXISTS vec_discovered_job_embeddings")
    drop table(:discovered_jobs)
  end
end
