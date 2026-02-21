defmodule Clientats.Workers.EmbedJobInterest do
  @moduledoc """
  Oban worker that generates embeddings for a job interest and stores them
  in the sqlite-vec vector index.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Clientats.{Embedding, Jobs, VectorStore}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"job_interest_id" => job_interest_id}}) do
    job = Jobs.get_job_interest!(job_interest_id)

    title_text = job.position_title || ""
    desc_text = String.slice(job.job_description || "", 0, 2000)

    if title_text == "" do
      Logger.warning("[EmbedJobInterest] Skipping job #{job_interest_id}: no title")
      :ok
    else
      with {:ok, title_vec} <- Embedding.embed(title_text, task_type: "RETRIEVAL_DOCUMENT"),
           {:ok, desc_vec} <- Embedding.embed(desc_text, task_type: "RETRIEVAL_DOCUMENT") do
        VectorStore.upsert_embedding(job_interest_id, title_vec, desc_vec)
        Logger.info("[EmbedJobInterest] Embedded job #{job_interest_id}")
        :ok
      else
        {:error, reason} ->
          Logger.error("[EmbedJobInterest] Failed for job #{job_interest_id}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  rescue
    Ecto.NoResultsError ->
      Logger.warning("[EmbedJobInterest] Job #{job_interest_id} not found, skipping")
      :ok
  end
end
