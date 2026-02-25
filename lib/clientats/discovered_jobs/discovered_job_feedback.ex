defmodule Clientats.DiscoveredJobs.DiscoveredJobFeedback do
  use Ecto.Schema
  import Ecto.Changeset

  schema "discovered_job_feedback" do
    field :feedback_type, :string
    field :value, :float
    field :metadata, :map, default: %{}

    belongs_to :user, Clientats.Accounts.User
    belongs_to :discovered_job, Clientats.DiscoveredJobs.DiscoveredJob

    timestamps(updated_at: false)
  end

  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:user_id, :discovered_job_id, :feedback_type, :value, :metadata])
    |> validate_required([:user_id, :discovered_job_id, :feedback_type])
    |> validate_inclusion(:feedback_type, ~w(thumbs_up thumbs_down))
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:discovered_job_id)
    |> unique_constraint([:user_id, :discovered_job_id, :feedback_type],
      name: :discovered_job_feedback_unique_signal
    )
  end
end
