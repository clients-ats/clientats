defmodule Clientats.Repo.Migrations.AddVecJobEmbeddings do
  use Ecto.Migration

  def up do
    # vec0 virtual table for job interest embeddings
    # 768 dimensions matches nomic-embed-text (Ollama) and gemini-embedding-001 default
    # distance_metric=cosine for semantic similarity
    execute("""
    CREATE VIRTUAL TABLE vec_job_embeddings USING vec0(
      job_interest_id INTEGER PRIMARY KEY,
      title_embedding float[768] distance_metric=cosine,
      description_embedding float[768] distance_metric=cosine
    )
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS vec_job_embeddings")
  end
end
