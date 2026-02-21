defmodule Clientats.Feedback do
  @moduledoc """
  Context for user feedback, preferences, and the training pipeline.

  Manages the feedback loop: user signals → training data → model updates.
  Supports explicit (thumbs up/down, bookmark, block) and implicit (click, dwell)
  feedback types that feed into the XGBoost learning-to-rank model.
  """

  import Ecto.Query
  alias Clientats.Repo
  alias Clientats.Feedback.{UserFeedback, UserPreference, CompanyBlock, RankingModel}

  # --- User Feedback ---

  @doc "Record a feedback signal for a job"
  def record_feedback(attrs) do
    %UserFeedback{}
    |> UserFeedback.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:value, :metadata]},
      conflict_target: [:user_id, :job_interest_id, :feedback_type]
    )
  end

  @doc "Record a thumbs up on a job"
  def thumbs_up(user_id, job_interest_id) do
    record_feedback(%{
      user_id: user_id,
      job_interest_id: job_interest_id,
      feedback_type: "thumbs_up",
      value: 1.0
    })
  end

  @doc "Record a thumbs down on a job"
  def thumbs_down(user_id, job_interest_id) do
    record_feedback(%{
      user_id: user_id,
      job_interest_id: job_interest_id,
      feedback_type: "thumbs_down",
      value: 0.0
    })
  end

  @doc "Record a bookmark on a job"
  def bookmark(user_id, job_interest_id) do
    record_feedback(%{
      user_id: user_id,
      job_interest_id: job_interest_id,
      feedback_type: "bookmark",
      value: 1.0
    })
  end

  @doc "Remove a bookmark from a job"
  def unbookmark(user_id, job_interest_id) do
    from(f in UserFeedback,
      where:
        f.user_id == ^user_id and
          f.job_interest_id == ^job_interest_id and
          f.feedback_type == "bookmark"
    )
    |> Repo.delete_all()
  end

  @doc "Check if a job is bookmarked"
  def bookmarked?(user_id, job_interest_id) do
    from(f in UserFeedback,
      where:
        f.user_id == ^user_id and
          f.job_interest_id == ^job_interest_id and
          f.feedback_type == "bookmark",
      select: count()
    )
    |> Repo.one() > 0
  end

  @doc """
  Load feedback states for multiple job interests at once.
  Returns a map of %{job_interest_id => %{thumbs: nil | :up | :down, bookmarked: boolean}}.
  """
  def get_feedback_states(user_id, job_interest_ids) when is_list(job_interest_ids) do
    feedbacks =
      from(f in UserFeedback,
        where:
          f.user_id == ^user_id and
            f.job_interest_id in ^job_interest_ids and
            f.feedback_type in ["thumbs_up", "thumbs_down", "bookmark"],
        select: {f.job_interest_id, f.feedback_type, f.inserted_at}
      )
      |> Repo.all()

    # Build the states map
    Enum.reduce(feedbacks, %{}, fn {job_id, type, inserted_at}, acc ->
      state = Map.get(acc, job_id, %{thumbs: nil, thumbs_at: nil, bookmarked: false})

      state =
        case type do
          "bookmark" ->
            %{state | bookmarked: true}

          thumbs_type when thumbs_type in ["thumbs_up", "thumbs_down"] ->
            if state.thumbs_at == nil or NaiveDateTime.compare(inserted_at, state.thumbs_at) == :gt do
              thumbs = if thumbs_type == "thumbs_up", do: :up, else: :down
              %{state | thumbs: thumbs, thumbs_at: inserted_at}
            else
              state
            end
        end

      Map.put(acc, job_id, state)
    end)
    |> Map.new(fn {job_id, state} ->
      {job_id, Map.take(state, [:thumbs, :bookmarked])}
    end)
  end

  @doc "Record a click-through to job detail"
  def record_click(user_id, job_interest_id) do
    record_feedback(%{
      user_id: user_id,
      job_interest_id: job_interest_id,
      feedback_type: "click",
      value: 1.0
    })
  end

  @doc "Record dwell time (seconds) on a job detail page"
  def record_dwell(user_id, job_interest_id, seconds) when is_number(seconds) do
    record_feedback(%{
      user_id: user_id,
      job_interest_id: job_interest_id,
      feedback_type: "dwell",
      value: seconds / 1.0
    })
  end

  @doc "Record a 'why' prompt response"
  def record_why(user_id, job_interest_id, reason) when is_binary(reason) do
    record_feedback(%{
      user_id: user_id,
      job_interest_id: job_interest_id,
      feedback_type: "why_prompt",
      value: 1.0,
      metadata: %{"reason" => reason}
    })
  end

  @doc "List all feedback for a user, with optional type filter, preloads job_interest"
  def list_feedback_history(user_id, opts \\ []) do
    type_filter = opts[:type]

    query =
      from(f in UserFeedback,
        where: f.user_id == ^user_id,
        order_by: [desc: f.inserted_at],
        preload: [:job_interest],
        limit: 200
      )

    query =
      case type_filter do
        :positive ->
          from(f in query, where: f.feedback_type in ["thumbs_up", "bookmark"])

        :negative ->
          from(f in query, where: f.feedback_type in ["thumbs_down", "company_block"])

        :implicit ->
          from(f in query, where: f.feedback_type in ["click", "dwell"])

        _ ->
          query
      end

    Repo.all(query)
  end

  @doc "Delete a feedback record by ID"
  def delete_feedback(feedback_id) do
    case Repo.get(UserFeedback, feedback_id) do
      nil -> {:error, :not_found}
      fb -> Repo.delete(fb)
    end
  end

  @doc "Get a user's feedback for a specific job"
  def get_feedback(user_id, job_interest_id) do
    from(f in UserFeedback,
      where: f.user_id == ^user_id and f.job_interest_id == ^job_interest_id
    )
    |> Repo.all()
  end

  @doc "Get the current thumbs signal for a job (nil, :up, or :down)"
  def get_thumbs(user_id, job_interest_id) do
    from(f in UserFeedback,
      where:
        f.user_id == ^user_id and
          f.job_interest_id == ^job_interest_id and
          f.feedback_type in ["thumbs_up", "thumbs_down"],
      order_by: [desc: f.inserted_at],
      limit: 1,
      select: f.feedback_type
    )
    |> Repo.one()
    |> case do
      "thumbs_up" -> :up
      "thumbs_down" -> :down
      nil -> nil
    end
  end

  @doc "Count total explicit feedback signals for a user"
  def feedback_count(user_id) do
    from(f in UserFeedback,
      where:
        f.user_id == ^user_id and
          f.feedback_type in ["thumbs_up", "thumbs_down", "bookmark"],
      select: count()
    )
    |> Repo.one()
  end

  @doc "Check if it's time to show a 'why' prompt (every ~20 ratings)"
  def should_prompt_why?(user_id, interval \\ 20) do
    count = feedback_count(user_id)
    count > 0 and rem(count, interval) == 0
  end

  # --- Training Data Pipeline ---

  @doc """
  Build training data from user feedback.

  Returns a list of `{feature_vector, label}` tuples suitable for
  `Ranker.train/2`. Only includes feedback with clear training signals.
  """
  def training_data(user_id) do
    feedbacks =
      from(f in UserFeedback,
        where: f.user_id == ^user_id,
        join: j in assoc(f, :job_interest),
        preload: [job_interest: j]
      )
      |> Repo.all()

    preferences = get_all_preferences(user_id)
    prefs_map = UserPreference.to_feature_prefs(preferences)

    feedbacks
    |> Enum.map(fn fb ->
      label = UserFeedback.training_label(fb)

      if label do
        job = Map.from_struct(fb.job_interest)
        features = Clientats.Ranker.FeatureExtractor.extract(job, %{}, prefs_map)
        {features, label}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc "Train or update the user's ranking model from their feedback"
  def train_model(user_id) do
    data = training_data(user_id)
    n = length(data)

    phase = RankingModel.phase_for_count(n)

    case Clientats.Ranker.train(data) do
      {:ok, booster} ->
        metrics = Clientats.Ranker.evaluate(booster, data)
        model_binary = Clientats.Ranker.dump_model(booster)

        attrs = %{
          user_id: user_id,
          model_data: model_binary,
          training_examples: n,
          metrics: metrics,
          phase: phase
        }

        case Repo.get_by(RankingModel, user_id: user_id) do
          nil ->
            %RankingModel{}
            |> RankingModel.changeset(attrs)
            |> Repo.insert()

          existing ->
            existing
            |> RankingModel.changeset(attrs)
            |> Repo.update()
        end

      {:error, _} = error ->
        error
    end
  end

  @doc "Load the user's trained ranking model"
  def get_ranking_model(user_id) do
    case Repo.get_by(RankingModel, user_id: user_id) do
      nil ->
        {:error, :no_model}

      %RankingModel{model_data: nil} ->
        {:error, :no_model}

      %RankingModel{model_data: binary} = rm ->
        case Clientats.Ranker.load_model(binary) do
          {:ok, booster} -> {:ok, booster, rm}
          error -> error
        end
    end
  end

  # --- User Preferences ---

  @doc "Set a user preference (upserts)"
  def set_preference(user_id, preference_type, value) when is_map(value) do
    attrs = %{user_id: user_id, preference_type: preference_type, value: value}

    %UserPreference{}
    |> UserPreference.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: [:user_id, :preference_type]
    )
  end

  @doc "Get a specific preference for a user"
  def get_preference(user_id, preference_type) do
    Repo.get_by(UserPreference, user_id: user_id, preference_type: preference_type)
  end

  @doc "Get all preferences for a user"
  def get_all_preferences(user_id) do
    from(p in UserPreference, where: p.user_id == ^user_id)
    |> Repo.all()
  end

  # --- Company Blocks ---

  @doc "Block a company for a user"
  def block_company(user_id, company_name, reason \\ nil) do
    %CompanyBlock{}
    |> CompanyBlock.changeset(%{user_id: user_id, company_name: company_name, reason: reason})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :company_name])
  end

  @doc "Unblock a company"
  def unblock_company(user_id, company_name) do
    from(b in CompanyBlock,
      where: b.user_id == ^user_id and b.company_name == ^company_name
    )
    |> Repo.delete_all()
  end

  @doc "Check if a company is blocked"
  def company_blocked?(user_id, company_name) do
    from(b in CompanyBlock,
      where: b.user_id == ^user_id and b.company_name == ^company_name,
      select: count()
    )
    |> Repo.one() > 0
  end

  @doc "List all blocked companies for a user"
  def blocked_companies(user_id) do
    from(b in CompanyBlock,
      where: b.user_id == ^user_id,
      order_by: [desc: b.inserted_at]
    )
    |> Repo.all()
  end
end
