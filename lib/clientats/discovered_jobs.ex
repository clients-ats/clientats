defmodule Clientats.DiscoveredJobs do
  @moduledoc """
  Context for discovered jobs - the staging area for jobs found by
  nightly scraping or manual LinkedIn searches before promotion to JobInterest.
  """

  import Ecto.Query
  alias Clientats.Repo
  alias Clientats.DiscoveredJobs.DiscoveredJob
  alias Clientats.Jobs
  alias Clientats.LinkedIn

  @doc """
  Upsert a discovered job from LinkedIn search results.

  Creates or updates by fingerprint. Stores extracted_data as a map.
  Returns `{:ok, discovered_job}` or `{:error, changeset}`.
  """
  def upsert_from_linkedin(user_id, raw_job, detail, extracted) do
    company = raw_job["company"] || detail["company"] || ""
    title = raw_job["title"] || detail["title"] || ""
    location = raw_job["location"] || detail["location"]
    fingerprint = LinkedIn.dedup_fingerprint(company, title, location)

    attrs = %{
      user_id: user_id,
      company: company,
      title: title,
      description: detail["description"] || raw_job["description"],
      url: raw_job["url"] || detail["url"],
      location: location,
      work_model: detail["work_model"] || raw_job["work_model"],
      salary: detail["salary"] || raw_job["salary"],
      source: "linkedin",
      source_id: raw_job["job_id"] || raw_job["id"],
      extracted_data: extracted || %{},
      fingerprint: fingerprint
    }

    case find_by_fingerprint(user_id, fingerprint) do
      nil ->
        %DiscoveredJob{}
        |> DiscoveredJob.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> DiscoveredJob.changeset(Map.drop(attrs, [:user_id, :fingerprint, :status]))
        |> Repo.update()
    end
  end

  @doc """
  List discovered jobs for a user, optionally filtered by status.

  ## Options
    * `:status` - filter by status atom/string (e.g., :new, "new")
    * `:limit` - max results (default: 100)
    * `:offset` - pagination offset (default: 0)
  """
  def list_for_user(user_id, opts \\ []) do
    status = opts[:status] && to_string(opts[:status])
    limit = opts[:limit] || 100
    offset = opts[:offset] || 0

    query =
      from(d in DiscoveredJob,
        where: d.user_id == ^user_id,
        order_by: [desc: d.score, desc: d.inserted_at],
        limit: ^limit,
        offset: ^offset
      )

    query =
      if status do
        from(d in query, where: d.status == ^status)
      else
        query
      end

    Repo.all(query)
  end

  @doc "Count discovered jobs with status 'new' for badge display."
  def get_new_count(user_id) do
    from(d in DiscoveredJob,
      where: d.user_id == ^user_id and d.status == "new",
      select: count()
    )
    |> Repo.one()
  end

  @doc "Set a discovered job's status to 'dismissed'."
  def dismiss(id) do
    case Repo.get(DiscoveredJob, id) do
      nil -> {:error, :not_found}
      job -> job |> DiscoveredJob.changeset(%{status: "dismissed"}) |> Repo.update()
    end
  end

  @doc """
  Promote a discovered job to a JobInterest.

  Creates a new JobInterest from the discovered job's data, sets the
  promoted_job_interest_id link, copies any feedback, and returns the new interest.
  """
  def promote_to_interest(%DiscoveredJob{} = discovered_job) do
    interest_attrs = %{
      user_id: discovered_job.user_id,
      company_name: discovered_job.company,
      position_title: discovered_job.title,
      job_description: discovered_job.description,
      job_url: discovered_job.url,
      location: discovered_job.location,
      work_model: discovered_job.work_model,
      status: "interested"
    }

    Repo.transaction(fn ->
      with {:ok, interest} <- Jobs.create_job_interest(interest_attrs),
           {:ok, _} <-
             discovered_job
             |> DiscoveredJob.changeset(%{
               status: "promoted",
               promoted_job_interest_id: interest.id
             })
             |> Repo.update() do
        interest
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc "Find a discovered job by fingerprint for a given user."
  def find_by_fingerprint(user_id, fingerprint) do
    Repo.get_by(DiscoveredJob, user_id: user_id, fingerprint: fingerprint)
  end

  @doc "Prune old dismissed records older than the given number of days."
  def cleanup_old(user_id, days \\ 30) do
    cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-days * 86400, :second)

    from(d in DiscoveredJob,
      where:
        d.user_id == ^user_id and
          d.status == "dismissed" and
          d.updated_at < ^cutoff
    )
    |> Repo.delete_all()
  end

  @doc "Get a discovered job by ID."
  def get_discovered_job(id), do: Repo.get(DiscoveredJob, id)

  @doc "Get a discovered job by ID, raises if not found."
  def get_discovered_job!(id), do: Repo.get!(DiscoveredJob, id)

  @doc "Update the score on a discovered job."
  def update_score(id, score) when is_number(score) do
    case Repo.get(DiscoveredJob, id) do
      nil -> {:error, :not_found}
      job -> job |> DiscoveredJob.changeset(%{score: score}) |> Repo.update()
    end
  end
end
