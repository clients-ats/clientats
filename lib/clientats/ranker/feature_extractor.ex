defmodule Clientats.Ranker.FeatureExtractor do
  @moduledoc """
  Extracts the 18-feature vector used by the ranking model.

  ## Feature Vector Layout (18 features)

  | # | Name | Type | Range | Source |
  |---|------|------|-------|--------|
  | 0 | title_similarity | float | 0..1 | vec search |
  | 1 | description_similarity | float | 0..1 | vec search |
  | 2 | skills_similarity | float | 0..1 | vec search |
  | 3 | requirements_similarity | float | 0..1 | vec search |
  | 4 | composite_similarity | float | 0..1 | weighted combo |
  | 5 | reranker_score | float | 0..1 | reranker |
  | 6 | salary_delta | float | -1..1 | job vs pref |
  | 7 | has_salary | binary | 0/1 | metadata |
  | 8 | work_model_match | binary | 0/1 | job vs pref |
  | 9 | is_remote | binary | 0/1 | metadata |
  | 10 | location_match | float | 0..1 | string match |
  | 11 | job_freshness | float | 0..1 | posting date |
  | 12 | description_length | float | 0..1 | normalized |
  | 13 | company_familiarity | float | 0..1 | user history |
  | 14 | similar_title_rate | float | 0..1 | historical |
  | 15 | skill_overlap | float | 0..1 | resume vs job |
  | 16 | seniority_match | float | 0..1 | user vs job |
  | 17 | industry_match | binary | 0/1 | user vs job |
  """

  @feature_count 18

  @doc "Number of features in the feature vector"
  def feature_count, do: @feature_count

  @doc "Feature names in order"
  def feature_names do
    [
      :title_similarity, :description_similarity, :skills_similarity,
      :requirements_similarity, :composite_similarity, :reranker_score,
      :salary_delta, :has_salary, :work_model_match, :is_remote,
      :location_match, :job_freshness, :description_length,
      :company_familiarity, :similar_title_rate, :skill_overlap,
      :seniority_match, :industry_match
    ]
  end

  @doc """
  Extract feature vector from a job and user preferences.

  ## Parameters
    * `job` - Map with job fields (from JobExtractor output)
    * `similarities` - Map with vector similarity scores
    * `user_prefs` - Map with user preferences
    * `opts` - Additional context (history, reranker score, etc.)

  ## Returns
    A list of 18 floats.
  """
  def extract(job, similarities \\ %{}, user_prefs \\ %{}, opts \\ []) do
    [
      # 0-4: Vector similarity scores
      Map.get(similarities, :title, 0.0),
      Map.get(similarities, :description, 0.0),
      Map.get(similarities, :skills, 0.0),
      Map.get(similarities, :requirements, 0.0),
      Map.get(similarities, :composite, 0.0),

      # 5: Reranker score
      opts[:reranker_score] || 0.0,

      # 6: Salary delta (normalized to -1..1)
      salary_delta(job, user_prefs),

      # 7: Has salary info
      if(job[:salary_min] || job[:salary_max], do: 1.0, else: 0.0),

      # 8: Work model matches preference
      work_model_match(job, user_prefs),

      # 9: Is remote
      if(job[:remote_policy] in ["full_remote", "flexible"] or job[:work_model] == "remote",
        do: 1.0, else: 0.0),

      # 10: Location match
      location_match(job[:location], user_prefs[:preferred_location]),

      # 11: Job freshness (days since posting, normalized)
      job_freshness(job[:date_posted] || job[:posted_at]),

      # 12: Description length (normalized, longer = more info)
      description_length(job[:description_text] || job[:job_description]),

      # 13: Company familiarity (from history)
      opts[:company_familiarity] || 0.0,

      # 14: Similar title accept rate (from history)
      opts[:similar_title_rate] || 0.0,

      # 15: Skill overlap ratio
      skill_overlap(job[:required_skills] || [], user_prefs[:skills] || []),

      # 16: Seniority match
      seniority_match(job[:seniority_level], user_prefs[:seniority_level]),

      # 17: Industry match
      if(job[:industry] && job[:industry] == user_prefs[:industry], do: 1.0, else: 0.0)
    ]
  end

  @doc """
  Generate synthetic training data for testing.

  Creates `n` examples with realistic feature distributions and labels
  that correlate with good feature values (high similarity, matching
  preferences = more likely positive).
  """
  def generate_synthetic_data(n, opts \\ []) do
    positive_ratio = opts[:positive_ratio] || 0.4

    for _ <- 1..n do
      # Decide label first, then generate features that correlate
      label = if :rand.uniform() < positive_ratio, do: 1.0, else: 0.0

      # Positive examples have higher similarity scores
      bias = if label == 1.0, do: 0.3, else: -0.1

      features = [
        clamp(:rand.normal(0.5 + bias, 0.2)),     # title_sim
        clamp(:rand.normal(0.4 + bias, 0.25)),     # desc_sim
        clamp(:rand.normal(0.45 + bias, 0.2)),     # skills_sim
        clamp(:rand.normal(0.4 + bias, 0.25)),     # req_sim
        clamp(:rand.normal(0.45 + bias, 0.2)),     # composite_sim
        clamp(:rand.normal(0.5 + bias, 0.2)),      # reranker_score
        clamp(:rand.normal(bias * 0.5, 0.3), -1.0, 1.0), # salary_delta
        if(:rand.uniform() > 0.3, do: 1.0, else: 0.0), # has_salary
        if(:rand.uniform() < 0.5 + bias, do: 1.0, else: 0.0), # work_model_match
        if(:rand.uniform() < 0.6, do: 1.0, else: 0.0), # is_remote
        clamp(:rand.normal(0.5 + bias * 0.5, 0.3)), # location_match
        clamp(:rand.normal(0.6, 0.3)),              # freshness
        clamp(:rand.normal(0.5, 0.2)),              # desc_length
        clamp(:rand.normal(0.3 + bias * 0.3, 0.2)), # company_familiarity
        clamp(:rand.normal(0.4 + bias * 0.3, 0.2)), # similar_title_rate
        clamp(:rand.normal(0.4 + bias, 0.25)),      # skill_overlap
        clamp(:rand.normal(0.5 + bias * 0.5, 0.3)), # seniority_match
        if(:rand.uniform() < 0.4 + bias, do: 1.0, else: 0.0) # industry_match
      ]

      {features, label}
    end
  end

  # --- Private Helpers ---

  defp salary_delta(job, prefs) do
    job_mid = salary_midpoint(job[:salary_min], job[:salary_max])
    pref_mid = salary_midpoint(prefs[:salary_min], prefs[:salary_max])

    cond do
      is_nil(job_mid) or is_nil(pref_mid) -> 0.0
      pref_mid == 0 -> 0.0
      true -> clamp((job_mid - pref_mid) / pref_mid, -1.0, 1.0)
    end
  end

  defp salary_midpoint(nil, nil), do: nil
  defp salary_midpoint(min, nil), do: min
  defp salary_midpoint(nil, max), do: max
  defp salary_midpoint(min, max), do: (min + max) / 2

  defp work_model_match(job, prefs) do
    job_model = job[:work_model] || job[:remote_policy]
    pref_model = prefs[:work_model]

    cond do
      is_nil(job_model) or is_nil(pref_model) -> 0.5
      normalize_work_model(job_model) == normalize_work_model(pref_model) -> 1.0
      true -> 0.0
    end
  end

  defp normalize_work_model(model) when is_binary(model) do
    model = String.downcase(model)
    cond do
      model in ["remote", "full_remote", "flexible"] -> "remote"
      model in ["hybrid", "hybrid_2d", "hybrid_3d"] -> "hybrid"
      model in ["onsite", "on_site", "office"] -> "onsite"
      true -> model
    end
  end
  defp normalize_work_model(_), do: nil

  defp location_match(nil, _), do: 0.5
  defp location_match(_, nil), do: 0.5
  defp location_match(job_loc, pref_loc) do
    job_lower = String.downcase(job_loc)
    pref_lower = String.downcase(pref_loc)

    cond do
      job_lower == pref_lower -> 1.0
      String.contains?(job_lower, pref_lower) or String.contains?(pref_lower, job_lower) -> 0.8
      String.contains?(job_lower, "remote") -> 0.7
      true -> 0.2
    end
  end

  defp job_freshness(nil), do: 0.5
  defp job_freshness(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        days_ago = Date.diff(Date.utc_today(), date)
        # Fresher = higher score. 0 days = 1.0, 30 days = ~0.0
        clamp(1.0 - days_ago / 30.0)

      _ ->
        0.5
    end
  end
  defp job_freshness(_), do: 0.5

  defp description_length(nil), do: 0.0
  defp description_length(text) when is_binary(text) do
    len = String.length(text)
    # Normalize: 0-500 chars = 0..0.5, 500-2000 = 0.5..1.0, 2000+ = 1.0
    clamp(len / 2000.0)
  end

  defp skill_overlap([], _), do: 0.0
  defp skill_overlap(_, []), do: 0.0
  defp skill_overlap(job_skills, user_skills) do
    job_set = MapSet.new(Enum.map(job_skills, &String.downcase/1))
    user_set = MapSet.new(Enum.map(user_skills, &String.downcase/1))

    overlap = MapSet.intersection(job_set, user_set) |> MapSet.size()
    total = MapSet.union(job_set, user_set) |> MapSet.size()

    if total == 0, do: 0.0, else: overlap / total
  end

  @seniority_levels %{
    "intern" => 0, "junior" => 1, "mid" => 2, "senior" => 3,
    "staff" => 4, "principal" => 5, "director" => 6, "vp" => 7, "c_level" => 8
  }

  defp seniority_match(nil, _), do: 0.5
  defp seniority_match(_, nil), do: 0.5
  defp seniority_match(job_level, user_level) do
    job_idx = Map.get(@seniority_levels, job_level, 2)
    user_idx = Map.get(@seniority_levels, user_level, 2)
    diff = abs(job_idx - user_idx)

    cond do
      diff == 0 -> 1.0
      diff == 1 -> 0.7
      diff == 2 -> 0.3
      true -> 0.0
    end
  end

  defp clamp(val, min \\ 0.0, max \\ 1.0) do
    val
    |> max(min)
    |> min(max)
  end
end
