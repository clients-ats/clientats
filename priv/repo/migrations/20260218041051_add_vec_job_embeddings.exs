defmodule Clientats.Repo.Migrations.AddVecJobEmbeddings do
  use Ecto.Migration

  def up do
    # vec0 virtual table for job interest embeddings
    # Using 384 dimensions (all-minilm) as baseline; can adjust later
    # distance_metric=cosine is the default for semantic similarity
    execute("""
    CREATE VIRTUAL TABLE vec_job_embeddings USING vec0(
      job_interest_id INTEGER PRIMARY KEY,
      title_embedding float[384] distance_metric=cosine,
      description_embedding float[384] distance_metric=cosine
    )
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS vec_job_embeddings")
  end
end
