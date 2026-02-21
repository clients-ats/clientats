defmodule Mix.Tasks.Clientats.EmbedAll do
  @moduledoc """
  Enqueue embedding jobs for all existing job interests.

      mix clientats.embed_all
  """
  use Mix.Task

  @shortdoc "Backfill embeddings for all job interests"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    alias Clientats.Repo
    alias Clientats.Jobs.JobInterest
    alias Clientats.Workers.EmbedJobInterest
    import Ecto.Query

    job_ids =
      from(j in JobInterest, select: j.id)
      |> Repo.all()

    count = length(job_ids)
    Mix.shell().info("Enqueuing embedding jobs for #{count} job interests...")

    Enum.each(job_ids, fn id ->
      %{"job_interest_id" => id}
      |> EmbedJobInterest.new()
      |> Oban.insert!()
    end)

    Mix.shell().info("Done. #{count} jobs enqueued.")
  end
end
