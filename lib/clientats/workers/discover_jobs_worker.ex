defmodule Clientats.Workers.DiscoverJobsWorker do
  @moduledoc """
  Oban worker for nightly background job discovery.

  Runs saved searches for each user, scrapes LinkedIn, extracts structured data,
  stores results in the discovered_jobs staging table, and enqueues embedding jobs.
  """
  use Oban.Worker, queue: :scrape, max_attempts: 1

  require Logger

  alias Clientats.{DiscoveredJobs, Feedback, LinkedIn, JobExtractor}
  alias Clientats.Ranker
  alias Clientats.Ranker.FeatureExtractor
  alias Clientats.Feedback.UserPreference
  alias Clientats.Workers.EmbedDiscoveredJob

  @rate_limit_ms 3_000

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    users_with_searches = load_users_with_searches()

    if users_with_searches == [] do
      Logger.info("[DiscoverJobsWorker] No users with saved searches, skipping")
      :ok
    else
      Logger.info("[DiscoverJobsWorker] Processing #{length(users_with_searches)} user(s)")

      Enum.each(users_with_searches, fn {user_id, searches} ->
        process_user(user_id, searches)
      end)

      :ok
    end
  end

  defp load_users_with_searches do
    # Get all users who have saved_searches preferences with at least one enabled search
    import Ecto.Query

    Clientats.Repo.all(
      from(p in Clientats.Feedback.UserPreference,
        where: p.preference_type == "saved_searches",
        select: {p.user_id, p.value}
      )
    )
    |> Enum.flat_map(fn {user_id, value} ->
      searches =
        (value["searches"] || [])
        |> Enum.filter(& &1["enabled"])

      if searches != [], do: [{user_id, searches}], else: []
    end)
  end

  defp process_user(user_id, searches) do
    Logger.info("[DiscoverJobsWorker] User #{user_id}: #{length(searches)} enabled search(es)")

    # Load user context for scoring
    preferences = Feedback.get_all_preferences(user_id)
    user_prefs = UserPreference.to_feature_prefs(preferences)
    blocked = Feedback.blocked_companies(user_id) |> Enum.map(& &1.company_name)

    booster =
      case Feedback.get_ranking_model(user_id) do
        {:ok, booster, _} -> booster
        _ -> nil
      end

    Enum.each(searches, fn search ->
      process_search(user_id, search, user_prefs, blocked, booster)
    end)
  end

  defp process_search(user_id, search, user_prefs, blocked, booster) do
    keywords = search["keywords"]
    Logger.info("[DiscoverJobsWorker] Searching: #{keywords}")

    opts =
      [max_jobs: 25, time_posted: :week]
      |> maybe_add_location(search["location"])
      |> maybe_add_remote(search["remote"])
      |> maybe_add_experience(search["experience"])

    case LinkedIn.search_jobs(keywords, opts) do
      {:ok, jobs} ->
        Logger.info("[DiscoverJobsWorker] Found #{length(jobs)} results for '#{keywords}'")

        Enum.each(jobs, fn job ->
          process_job(user_id, job, user_prefs, blocked, booster)
          Process.sleep(@rate_limit_ms)
        end)

      {:error, reason} ->
        Logger.error("[DiscoverJobsWorker] Search failed for '#{keywords}': #{inspect(reason)}")
    end
  end

  defp process_job(user_id, job, user_prefs, blocked, booster) do
    company = job[:company] || ""

    # Skip blocked companies
    if String.downcase(company) in Enum.map(blocked, &String.downcase/1) do
      Logger.debug("[DiscoverJobsWorker] Skipping blocked company: #{company}")
      :skip
    else
      # Check if already exists
      fingerprint = LinkedIn.dedup_fingerprint(company, job[:title], job[:location])

      if DiscoveredJobs.find_by_fingerprint(user_id, fingerprint) do
        Logger.debug("[DiscoverJobsWorker] Skipping duplicate: #{job[:title]} at #{company}")
        :skip
      else
        process_new_job(user_id, job, user_prefs, booster)
      end
    end
  end

  defp process_new_job(user_id, job, user_prefs, booster) do
    job_id = job[:linkedin_job_id]

    # Get detail
    detail =
      case LinkedIn.job_detail(to_string(job_id)) do
        {:ok, d} -> d
        _ -> %{}
      end

    description_text = detail[:description_text] || ""

    # Try public page if detail had no description
    {description_text, detail} =
      if String.length(String.trim(description_text)) < 50 do
        case LinkedIn.public_job_data(to_string(job_id)) do
          {:ok, public} ->
            pub_desc = public[:description_text] || public[:description_html] || ""

            merged =
              Map.merge(
                detail,
                Map.take(public, [
                  :description_text,
                  :description_html,
                  :salary_min,
                  :salary_max,
                  :employment_type
                ])
              )

            {pub_desc, merged}

          _ ->
            {description_text, detail}
        end
      else
        {description_text, detail}
      end

    # Extract structured data
    extracted =
      if String.length(String.trim(description_text)) > 50 do
        case JobExtractor.extract(description_text, user_id: user_id) do
          {:ok, raw} ->
            case JobExtractor.validate(raw) do
              {:ok, validated} -> validated
              _ -> %{}
            end

          _ ->
            %{}
        end
      else
        %{}
      end

    extracted =
      extracted
      |> Map.put_new(:title_clean, job[:title])
      |> Map.put_new(:company_name, job[:company])
      |> Map.put_new(:location, detail[:location] || job[:location])
      |> Map.put(:description, if(String.trim(description_text) != "", do: description_text))

    # Score
    similarities = %{title: 0.5, description: 0.5, composite: 0.5, skills: 0.0, requirements: 0.0}
    features = FeatureExtractor.extract(extracted, similarities, user_prefs)

    score =
      case booster do
        nil -> similarities.composite
        b -> Ranker.predict(b, [features]) |> List.first()
      end

    # Convert detail/job to string-keyed maps for upsert
    raw_job = Map.new(job, fn {k, v} -> {to_string(k), v} end)
    detail_map = Map.new(detail, fn {k, v} -> {to_string(k), v} end)
    extracted_map = Map.new(extracted, fn {k, v} -> {to_string(k), v} end)

    case DiscoveredJobs.upsert_from_linkedin(user_id, raw_job, detail_map, extracted_map) do
      {:ok, discovered_job} ->
        # Update score
        DiscoveredJobs.update_score(discovered_job.id, score)

        # Enqueue embedding
        %{"discovered_job_id" => discovered_job.id}
        |> EmbedDiscoveredJob.new()
        |> Oban.insert()

        Logger.info(
          "[DiscoverJobsWorker] Saved: #{job[:title]} at #{job[:company]} (score: #{Float.round(score, 2)})"
        )

      {:error, reason} ->
        Logger.error("[DiscoverJobsWorker] Failed to save #{job[:title]}: #{inspect(reason)}")
    end
  end

  defp maybe_add_location(opts, nil), do: opts
  defp maybe_add_location(opts, ""), do: opts
  defp maybe_add_location(opts, location), do: Keyword.put(opts, :location, location)

  defp maybe_add_remote(opts, true), do: Keyword.put(opts, :remote, true)
  defp maybe_add_remote(opts, _), do: opts

  defp maybe_add_experience(opts, nil), do: opts
  defp maybe_add_experience(opts, ""), do: opts

  defp maybe_add_experience(opts, level),
    do: Keyword.put(opts, :experience, [String.to_existing_atom(level)])
end
