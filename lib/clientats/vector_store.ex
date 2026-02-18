defmodule Clientats.VectorStore do
  @moduledoc """
  Thin wrapper around sqlite-vec for vector storage and KNN search.

  Uses vec0 virtual tables loaded via the sqlite-vec extension.
  All vectors are passed as JSON arrays to SQL queries.
  """

  alias Clientats.Repo
  alias Ecto.Adapters.SQL

  @doc """
  Insert or replace an embedding for a job interest.
  Vectors should be lists of floats.
  """
  def upsert_embedding(job_interest_id, title_vec, description_vec)
      when is_integer(job_interest_id) do
    title_json = Jason.encode!(title_vec)
    desc_json = Jason.encode!(description_vec)

    # vec0 virtual tables don't support INSERT OR REPLACE,
    # so we delete first then insert
    SQL.query!(
      Repo,
      "DELETE FROM vec_job_embeddings WHERE job_interest_id = ?",
      [job_interest_id]
    )

    SQL.query!(
      Repo,
      """
      INSERT INTO vec_job_embeddings(job_interest_id, title_embedding, description_embedding)
      VALUES (?, ?, ?)
      """,
      [job_interest_id, title_json, desc_json]
    )
  end

  @doc """
  Search for similar jobs by title embedding. Returns top-k results.
  """
  def search_by_title(query_vec, k \\ 10) do
    query_json = Jason.encode!(query_vec)

    SQL.query!(
      Repo,
      """
      SELECT job_interest_id, distance
      FROM vec_job_embeddings
      WHERE title_embedding MATCH ?
      AND k = ?
      """,
      [query_json, k]
    )
  end

  @doc """
  Search for similar jobs by description embedding. Returns top-k results.
  """
  def search_by_description(query_vec, k \\ 10) do
    query_json = Jason.encode!(query_vec)

    SQL.query!(
      Repo,
      """
      SELECT job_interest_id, distance
      FROM vec_job_embeddings
      WHERE description_embedding MATCH ?
      AND k = ?
      """,
      [query_json, k]
    )
  end

  @doc """
  Search by title and join back to job_interests table for full details.
  """
  def search_jobs_by_title(query_vec, k \\ 10) do
    query_json = Jason.encode!(query_vec)

    SQL.query!(
      Repo,
      """
      SELECT j.id, j.position_title, j.company_name, j.location, v.distance
      FROM vec_job_embeddings v
      INNER JOIN job_interests j ON j.id = v.job_interest_id
      WHERE v.title_embedding MATCH ?
      AND k = ?
      ORDER BY v.distance
      """,
      [query_json, k]
    )
  end

  @doc """
  Delete embedding for a job interest.
  """
  def delete_embedding(job_interest_id) do
    SQL.query!(
      Repo,
      "DELETE FROM vec_job_embeddings WHERE job_interest_id = ?",
      [job_interest_id]
    )
  end

  @doc """
  Count total embeddings stored.
  """
  def count do
    %{rows: [[count]]} =
      SQL.query!(Repo, "SELECT count(*) FROM vec_job_embeddings", [])

    count
  end

  @doc """
  Check that sqlite-vec is loaded and return version.
  """
  def vec_version do
    %{rows: [[version]]} = SQL.query!(Repo, "SELECT vec_version()", [])
    version
  end
end
