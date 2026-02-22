defmodule Clientats.LinkedIn do
  @moduledoc """
  LinkedIn job search crawling via Playwright CDP connection.

  Connects to the user's Chrome browser (launched with --remote-debugging-port=9222)
  to scrape LinkedIn job listings using the user's authenticated session.

  Uses a Node.js sidecar script (`scripts/linkedin_scrape.js`) following the same
  pattern as `Browser.capture_screenshot/2`.

  ## Usage

      # Ensure Chrome is running with debug port:
      # google-chrome --remote-debugging-port=9222

      # Search for jobs
      {:ok, jobs} = LinkedIn.search_jobs("Elixir developer", location: "United States", remote: true)

      # Get full details for a specific job
      {:ok, detail} = LinkedIn.job_detail("4366674463")

      # Get structured data from public page (JSON-LD)
      {:ok, data} = LinkedIn.public_job_data("4366674463")
  """

  require Logger

  @default_timeout 60_000
  @script_name "linkedin_scrape.js"

  @doc """
  Search LinkedIn for job listings matching the given query.

  ## Options
    * `:location` - Location filter (default: "United States")
    * `:remote` - Filter for remote jobs (default: false)
    * `:time_posted` - Time filter: `:day`, `:week`, `:month` (default: `:month`)
    * `:max_jobs` - Maximum jobs to extract (default: 25)
    * `:experience` - Experience levels list, e.g. `[:mid_senior, :director]`
    * `:job_type` - Job types list, e.g. `[:full_time, :contract]`
    * `:sort_by` - Sort: `:date` or `:relevance` (default: `:relevance`)

  ## Returns
    * `{:ok, [%{linkedin_job_id, title, company, location, posted_at, url}]}`
    * `{:error, reason}`
  """
  def search_jobs(query, opts \\ []) do
    url = build_search_url(query, opts)
    max_jobs = opts[:max_jobs] || 25

    case run_script(["search", url, "--max-jobs=#{max_jobs}"]) do
      {:ok, %{"success" => true, "jobs" => jobs}} ->
        {:ok, Enum.map(jobs, &normalize_search_result/1)}

      {:ok, %{"success" => false, "error" => reason}} ->
        {:error, reason}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Get full job details from the logged-in view.

  Returns title, company, location, description (HTML + text), salary,
  work type, and other metadata extracted from the SPA detail panel.
  """
  def job_detail(job_id) when is_binary(job_id) do
    case run_script(["detail", job_id]) do
      {:ok, %{"success" => true} = data} ->
        {:ok, normalize_detail(data)}

      {:ok, %{"success" => false, "error" => reason}} ->
        {:error, reason}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Fetch structured data from a public (guest) LinkedIn job page.

  Uses an incognito browser context to get the server-rendered page
  which includes JSON-LD schema.org JobPosting data.
  """
  def public_job_data(job_id) when is_binary(job_id) do
    case run_script(["public", job_id]) do
      {:ok, %{"success" => true} = data} ->
        {:ok, normalize_public_data(data)}

      {:ok, %{"success" => false, "error" => reason}} ->
        {:error, reason}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Build a LinkedIn job search URL from query and options.
  """
  def build_search_url(query, opts \\ []) do
    location = opts[:location] || "United States"

    params =
      [
        {"keywords", query},
        {"location", location}
      ]
      |> maybe_add_param(opts[:remote], "f_WT", "2")
      |> maybe_add_param(opts[:time_posted], "f_TPR", time_posted_value(opts[:time_posted]))
      |> maybe_add_experience(opts[:experience])
      |> maybe_add_job_type(opts[:job_type])
      |> maybe_add_param(opts[:sort_by] == :date, "sortBy", "DD")

    query_string = URI.encode_query(params)
    "https://www.linkedin.com/jobs/search/?#{query_string}"
  end

  @doc """
  Generate a deduplication fingerprint for a job listing.

  Normalizes company name, title, and location into a consistent hash
  to detect reposts (same job, new LinkedIn ID).
  """
  def dedup_fingerprint(company, title, location) do
    normalized =
      [company, title, location]
      |> Enum.map(fn
        nil -> ""
        s -> s |> String.downcase() |> String.replace(~r/[^a-z0-9\s]/, "") |> String.trim()
      end)
      |> Enum.join("|")

    :crypto.hash(:sha256, normalized) |> Base.encode16(case: :lower) |> binary_part(0, 16)
  end

  # --- Private ---

  defp run_script(args) do
    script_path = resolve_script_path()

    unless File.exists?(script_path) do
      Logger.error("[LinkedIn] Script not found: #{script_path}")
      {:error, :script_not_found}
    else
      Logger.info("[LinkedIn] Running: node #{script_path} #{Enum.join(args, " ")}")

      try do
        task =
          Task.async(fn ->
            System.cmd("node", [script_path | args], stderr_to_stdout: false)
          end)

        case Task.yield(task, @default_timeout) || Task.shutdown(task, :brutal_kill) do
          {:ok, {output, 0}} ->
            case Jason.decode(output) do
              {:ok, data} -> {:ok, data}
              {:error, _} -> {:error, {:json_parse_error, String.slice(output, 0, 200)}}
            end

          {:ok, {output, exit_code}} ->
            Logger.warning("[LinkedIn] Script exited #{exit_code}: #{String.slice(output, 0, 500)}")
            {:error, {:script_error, exit_code, output}}

          nil ->
            Logger.warning("[LinkedIn] Script timed out after #{@default_timeout}ms")
            {:error, :timeout}
        end
      rescue
        e -> {:error, {:exception, Exception.message(e)}}
      end
    end
  end

  defp resolve_script_path do
    # Try priv-relative path first (works in releases)
    priv_path =
      :code.priv_dir(:clientats)
      |> to_string()
      |> Path.join("../../../scripts/#{@script_name}")

    if File.exists?(priv_path) do
      priv_path
    else
      # Fall back to project root scripts dir
      "scripts/#{@script_name}"
    end
  end

  defp normalize_search_result(job) do
    %{
      linkedin_job_id: job["linkedin_job_id"],
      title: job["title"],
      company: job["company"],
      location: job["location"],
      posted_at: job["posted_at"],
      url: job["url"],
      source: :linkedin
    }
  end

  defp normalize_detail(data) do
    %{
      linkedin_job_id: data["linkedin_job_id"],
      title: data["title"],
      company: data["company"],
      location: data["location"],
      description_html: data["description_html"],
      description_text: data["description_text"],
      salary_text: data["salary_text"],
      work_type: data["work_type"],
      employment_type: data["employment_type"],
      posted_at: data["posted_at"],
      applicant_count: data["applicant_count"],
      source: :linkedin
    }
  end

  defp normalize_public_data(data) do
    structured = data["structured"] || %{}
    page = data["page_data"] || %{}

    %{
      linkedin_job_id: data["linkedin_job_id"],
      title: structured["title"] || page["title"],
      company: structured["company"] || page["company"],
      location: structured["location"] || page["location"],
      region: structured["region"],
      country: structured["country"],
      description_html: structured["description"] || page["description_html"],
      description_text: page["description_text"],
      date_posted: structured["date_posted"],
      valid_through: structured["valid_through"],
      employment_type: structured["employment_type"],
      salary_min: structured["salary_min"],
      salary_max: structured["salary_max"],
      salary_currency: structured["salary_currency"],
      salary_unit: structured["salary_unit"],
      company_url: structured["company_url"],
      criteria: page["criteria"] || [],
      has_json_ld: data["json_ld"] != nil,
      source: :linkedin
    }
  end

  defp time_posted_value(:day), do: "r86400"
  defp time_posted_value(:week), do: "r604800"
  defp time_posted_value(:month), do: "r2592000"
  defp time_posted_value(_), do: nil

  defp maybe_add_param(params, truthy, key, value) when truthy in [true, :day, :week, :month] and not is_nil(value) do
    params ++ [{key, value}]
  end
  defp maybe_add_param(params, _, _, _), do: params

  defp maybe_add_experience(params, nil), do: params
  defp maybe_add_experience(params, levels) when is_list(levels) do
    values = Enum.map_join(levels, ",", fn
      :intern -> "1"
      :entry -> "2"
      :associate -> "3"
      :mid_senior -> "4"
      :director -> "5"
      :executive -> "6"
    end)
    params ++ [{"f_E", values}]
  end

  defp maybe_add_job_type(params, nil), do: params
  defp maybe_add_job_type(params, types) when is_list(types) do
    values = Enum.map_join(types, ",", fn
      :full_time -> "F"
      :part_time -> "P"
      :contract -> "C"
      :temporary -> "T"
      :internship -> "I"
    end)
    params ++ [{"f_JT", values}]
  end
end
