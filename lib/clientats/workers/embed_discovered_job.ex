defmodule Clientats.Workers.EmbedDiscoveredJob do
  @moduledoc """
  Oban worker that generates embeddings for a discovered job and stores them
  in the sqlite-vec vector index for discovered jobs.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Clientats.{DiscoveredJobs, Embedding, VectorStore}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"discovered_job_id" => discovered_job_id}}) do
    job = DiscoveredJobs.get_discovered_job!(discovered_job_id)

    title_text = job.title || ""
    desc_text = String.slice(job.description || "", 0, 2000)

    if title_text == "" do
      Logger.warning("[EmbedDiscoveredJob] Skipping job #{discovered_job_id}: no title")
      :ok
    else
      with {:ok, title_vec} <- Embedding.embed(title_text, task_type: "RETRIEVAL_DOCUMENT"),
           {:ok, desc_vec} <- Embedding.embed(desc_text, task_type: "RETRIEVAL_DOCUMENT") do
        VectorStore.upsert_discovered_embedding(discovered_job_id, title_vec, desc_vec)
        Logger.info("[EmbedDiscoveredJob] Embedded discovered job #{discovered_job_id}")
        :ok
      else
        {:error, reason} ->
          Logger.error(
            "[EmbedDiscoveredJob] Failed for discovered job #{discovered_job_id}: #{inspect(reason)}"
          )

          {:error, reason}
      end
    end
  rescue
    Ecto.NoResultsError ->
      Logger.warning("[EmbedDiscoveredJob] Discovered job #{discovered_job_id} not found, cancelling")
      {:cancel, :not_found}
  end
end
