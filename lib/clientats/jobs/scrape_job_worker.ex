defmodule Clientats.Jobs.ScrapeJobWorker do
  @moduledoc """
  Background worker for asynchronous job scraping.

  Handles long-running LLM API calls without blocking the web request.
  Supports retries and dead-letter queue for failed jobs.
  """

  use Oban.Worker, queue: :scrape, max_attempts: 3

  require Logger

  alias Clientats.LLM.Service
  alias Clientats.Jobs
  alias Clientats.Audit

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    url = args["url"]
    user_id = args["user_id"]
    mode = args["mode"] || "generic"
    provider = args["provider"]
    save = args["save"] || false

    Logger.info("Scraping job from #{url} for user #{user_id}")

    case Service.extract_job_data(url, mode, provider, user_id: user_id) do
      {:ok, data} ->
        handle_success(data, user_id, save)
        :ok

      {:error, reason} ->
        handle_error(reason, user_id, url)
        {:error, reason}
    end
  rescue
    e ->
      url = args["url"]
      user_id = args["user_id"]
      Logger.error("Error scraping job: #{inspect(e)}")
      Audit.log_action(%{
        user_id: user_id,
        action: "job_scraping_error",
        resource_type: "job_scraping",
        status: "failure",
        error_message: Exception.message(e),
        metadata: %{"url" => url}
      })
      {:error, Exception.message(e)}
  end

  defp handle_success(data, user_id, save) do
    Logger.info("Successfully scraped job data for user #{user_id}")

    Audit.log_action(%{
      user_id: user_id,
      action: "job_scraping_success",
      resource_type: "job_scraping",
      status: "success",
      metadata: %{
        "company" => data["company_name"],
        "position" => data["position_title"]
      }
    })

    if save do
      case Jobs.create_job_interest(%{
        user_id: user_id,
        company_name: data["company_name"],
        position_title: data["position_title"],
        location: data["location"],
        job_description: data["job_description"],
        work_model: data["work_model"],
        salary_min: data["salary_min"],
        salary_max: data["salary_max"],
        job_url: data["job_url"],
        status: "interested"
      }) do
        {:ok, _interest} ->
          Logger.info("Saved job interest for user #{user_id}")
          Audit.log_action(%{
            user_id: user_id,
            action: "create",
            resource_type: "job_interest",
            status: "success",
            metadata: %{"source" => "scraping_worker"}
          })

        {:error, changeset} ->
          Logger.error("Failed to save job interest: #{inspect(changeset)}")
          Audit.log_action(%{
            user_id: user_id,
            action: "create",
            resource_type: "job_interest",
            status: "failure",
            error_message: "Failed to save job interest",
            metadata: %{"errors" => inspect(changeset)}
          })
      end
    end
  end

  defp handle_error(reason, user_id, url) do
    Logger.error("Failed to scrape job from #{url}: #{inspect(reason)}")

    Audit.log_action(%{
      user_id: user_id,
      action: "job_scraping_error",
      resource_type: "job_scraping",
      status: "failure",
      error_message: to_string(reason),
      metadata: %{"url" => url}
    })
  end
end
