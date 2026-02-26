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
  Multi-vector search: query both title and description, combine with weights.

  Returns `{job_interest_id, combined_distance}` tuples sorted by combined distance.
  Lower distance = more similar.

  ## Options
    * `:title_weight` - Weight for title distance (default: 0.4)
    * `:desc_weight` - Weight for description distance (default: 0.6)
  """
  def search_multi_vector(title_query_vec, desc_query_vec, k \\ 20, opts \\ []) do
    title_w = opts[:title_weight] || 0.4
    desc_w = opts[:desc_weight] || 0.6
    # Fetch more candidates from each vector to ensure good coverage after merging
    fetch_k = k * 3

    title_json = Jason.encode!(title_query_vec)
    desc_json = Jason.encode!(desc_query_vec)

    title_results =
      SQL.query!(
        Repo,
        "SELECT job_interest_id, distance FROM vec_job_embeddings WHERE title_embedding MATCH ? AND k = ?",
        [title_json, fetch_k]
      )

    desc_results =
      SQL.query!(
        Repo,
        "SELECT job_interest_id, distance FROM vec_job_embeddings WHERE description_embedding MATCH ? AND k = ?",
        [desc_json, fetch_k]
      )

    # Build distance maps
    title_map = Map.new(title_results.rows, fn [id, dist] -> {id, dist} end)
    desc_map = Map.new(desc_results.rows, fn [id, dist] -> {id, dist} end)

    # Get all candidate IDs from both searches
    all_ids = MapSet.union(MapSet.new(Map.keys(title_map)), MapSet.new(Map.keys(desc_map)))

    # Combine distances with weights (use max distance as penalty for missing)
    max_dist = 2.0

    results =
      all_ids
      |> Enum.map(fn id ->
        title_dist = Map.get(title_map, id, max_dist)
        desc_dist = Map.get(desc_map, id, max_dist)
        combined = title_w * title_dist + desc_w * desc_dist
        {id, combined, title_dist, desc_dist}
      end)
      |> Enum.sort_by(fn {_, combined, _, _} -> combined end)
      |> Enum.take(k)

    results
  end

  @doc """
  Filtered vector search: apply hard filters on job_interests first,
  then rank by vector similarity.

  Filters are applied via SQL WHERE clauses on the job_interests table.
  Since vec0 doesn't support WHERE clauses beyond MATCH, we do:
  1. KNN search to get top candidates (larger k)
  2. JOIN + filter to narrow down
  """
  def search_filtered(query_vec, k \\ 10, filters \\ %{}) do
    query_json = Jason.encode!(query_vec)
    # Over-fetch to account for filtered-out results
    fetch_k = k * 10

    {where_clauses, filter_params, next_idx} = build_filter_clauses(filters)

    query = """
    SELECT j.id, j.position_title, j.company_name, j.location, j.work_model,
           j.salary_min, j.salary_max, v.distance
    FROM vec_job_embeddings v
    INNER JOIN job_interests j ON j.id = v.job_interest_id
    WHERE v.title_embedding MATCH ?1
    AND k = ?2
    #{where_clauses}
    ORDER BY v.distance
    LIMIT ?#{next_idx}
    """

    all_params = [query_json, fetch_k] ++ filter_params ++ [k]

    SQL.query!(Repo, query, all_params)
  end

  defp build_filter_clauses(filters) when map_size(filters) == 0, do: {"", [], 3}

  defp build_filter_clauses(filters) do
    {clauses, params, idx} =
      Enum.reduce(filters, {[], [], 3}, fn
        {:work_model, value}, {clauses, params, idx} when is_binary(value) ->
          {["AND j.work_model = ?#{idx}" | clauses], params ++ [value], idx + 1}

        {:location, value}, {clauses, params, idx} when is_binary(value) ->
          {["AND j.location LIKE ?#{idx}" | clauses], params ++ ["%#{value}%"], idx + 1}

        {:salary_min, value}, {clauses, params, idx} when is_integer(value) ->
          {["AND (j.salary_max IS NULL OR j.salary_max >= ?#{idx})" | clauses], params ++ [value],
           idx + 1}

        {:exclude_companies, companies}, {clauses, params, idx} when is_list(companies) ->
          placeholders =
            Enum.map_join(0..(length(companies) - 1), ", ", fn i -> "?#{idx + i}" end)

          {["AND j.company_name NOT IN (#{placeholders})" | clauses], params ++ companies,
           idx + length(companies)}

        _, acc ->
          acc
      end)

    {Enum.join(Enum.reverse(clauses), "\n"), params, idx}
  end

  # --- Discovered Job Embeddings ---

  @doc """
  Insert or replace an embedding for a discovered job.
  Vectors should be lists of floats.
  """
  def upsert_discovered_embedding(discovered_job_id, title_vec, description_vec)
      when is_integer(discovered_job_id) do
    title_json = Jason.encode!(title_vec)
    desc_json = Jason.encode!(description_vec)

    SQL.query!(
      Repo,
      "DELETE FROM vec_discovered_job_embeddings WHERE discovered_job_id = ?",
      [discovered_job_id]
    )

    SQL.query!(
      Repo,
      """
      INSERT INTO vec_discovered_job_embeddings(discovered_job_id, title_embedding, description_embedding)
      VALUES (?, ?, ?)
      """,
      [discovered_job_id, title_json, desc_json]
    )
  end

  @doc """
  Multi-vector search on discovered job embeddings.

  Same weighted algorithm as `search_multi_vector/4` but queries the
  `vec_discovered_job_embeddings` table.

  ## Options
    * `:title_weight` - Weight for title distance (default: 0.4)
    * `:desc_weight` - Weight for description distance (default: 0.6)
  """
  def search_discovered_multi_vector(title_query_vec, desc_query_vec, k \\ 20, opts \\ []) do
    title_w = opts[:title_weight] || 0.4
    desc_w = opts[:desc_weight] || 0.6
    fetch_k = k * 3

    title_json = Jason.encode!(title_query_vec)
    desc_json = Jason.encode!(desc_query_vec)

    title_results =
      SQL.query!(
        Repo,
        "SELECT discovered_job_id, distance FROM vec_discovered_job_embeddings WHERE title_embedding MATCH ? AND k = ?",
        [title_json, fetch_k]
      )

    desc_results =
      SQL.query!(
        Repo,
        "SELECT discovered_job_id, distance FROM vec_discovered_job_embeddings WHERE description_embedding MATCH ? AND k = ?",
        [desc_json, fetch_k]
      )

    title_map = Map.new(title_results.rows, fn [id, dist] -> {id, dist} end)
    desc_map = Map.new(desc_results.rows, fn [id, dist] -> {id, dist} end)

    all_ids = MapSet.union(MapSet.new(Map.keys(title_map)), MapSet.new(Map.keys(desc_map)))

    max_dist = 2.0

    all_ids
    |> Enum.map(fn id ->
      title_dist = Map.get(title_map, id, max_dist)
      desc_dist = Map.get(desc_map, id, max_dist)
      combined = title_w * title_dist + desc_w * desc_dist
      {id, combined, title_dist, desc_dist}
    end)
    |> Enum.sort_by(fn {_, combined, _, _} -> combined end)
    |> Enum.take(k)
  end

  @doc """
  Delete embedding for a discovered job.
  """
  def delete_discovered_embedding(discovered_job_id) do
    SQL.query!(
      Repo,
      "DELETE FROM vec_discovered_job_embeddings WHERE discovered_job_id = ?",
      [discovered_job_id]
    )
  end

  @doc """
  Check that sqlite-vec is loaded and return version.
  """
  def vec_version do
    %{rows: [[version]]} = SQL.query!(Repo, "SELECT vec_version()", [])
    version
  end
end
