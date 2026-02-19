defmodule Clientats.Feedback.UserFeedback do
  use Ecto.Schema
  import Ecto.Changeset

  @feedback_types ~w(thumbs_up thumbs_down click dwell bookmark company_block why_prompt)

  schema "user_feedback" do
    field :feedback_type, :string
    field :value, :float
    field :metadata, :map, default: %{}

    belongs_to :user, Clientats.Accounts.User
    belongs_to :job_interest, Clientats.Jobs.JobInterest

    timestamps(updated_at: false)
  end

  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:user_id, :job_interest_id, :feedback_type, :value, :metadata])
    |> validate_required([:user_id, :feedback_type])
    |> validate_inclusion(:feedback_type, @feedback_types)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:job_interest_id)
    |> unique_constraint([:user_id, :job_interest_id, :feedback_type],
      name: :user_feedback_unique_signal
    )
  end

  def feedback_types, do: @feedback_types

  @doc "Returns the label for XGBoost training (1.0 positive, 0.0 negative, nil = skip)"
  def training_label(%__MODULE__{feedback_type: "thumbs_up"}), do: 1.0
  def training_label(%__MODULE__{feedback_type: "bookmark"}), do: 1.0
  def training_label(%__MODULE__{feedback_type: "thumbs_down"}), do: 0.0
  def training_label(%__MODULE__{feedback_type: "company_block"}), do: 0.0
  def training_label(%__MODULE__{feedback_type: "click"}), do: nil
  def training_label(%__MODULE__{feedback_type: "dwell", value: v}) when v >= 30.0, do: 1.0
  def training_label(%__MODULE__{feedback_type: "dwell", value: v}) when v < 5.0, do: 0.0
  def training_label(%__MODULE__{feedback_type: _}), do: nil
end
