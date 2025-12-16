defmodule Clientats.Help.HelpInteraction do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Tracks user interactions with help system for analytics and personalization.

  Records:
  - Help text views
  - Tutorial completions
  - Tutorial dismissals
  - Error recovery suggestions used
  """

  schema "help_interactions" do
    field :user_id, :string
    field :interaction_type, :string  # :help_view, :tutorial_start, :tutorial_complete, :tutorial_dismiss, :recovery_used
    field :feature, :string           # :job_interests, :applications, :documents, :dashboard
    field :element, :string           # :search_bar, :priority_filter, etc.
    field :context, :map              # Additional context data
    field :feedback, :string          # Optional user feedback
    field :helpful, :boolean          # Was this helpful? true/false/nil

    timestamps(type: :utc_datetime)
  end

  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [
      :user_id,
      :interaction_type,
      :feature,
      :element,
      :context,
      :feedback,
      :helpful
    ])
    |> validate_required([:user_id, :interaction_type])
    |> validate_inclusion(:interaction_type, [
      "help_view",
      "tutorial_start",
      "tutorial_complete",
      "tutorial_dismiss",
      "recovery_used"
    ])
  end

  def log_help_view(user_id, feature, element, context \\ %{}) do
    %__MODULE__{}
    |> changeset(%{
      user_id: user_id,
      interaction_type: "help_view",
      feature: feature,
      element: element,
      context: context
    })
  end

  def log_tutorial_start(user_id, feature) do
    %__MODULE__{}
    |> changeset(%{
      user_id: user_id,
      interaction_type: "tutorial_start",
      feature: feature
    })
  end

  def log_tutorial_complete(user_id, feature) do
    %__MODULE__{}
    |> changeset(%{
      user_id: user_id,
      interaction_type: "tutorial_complete",
      feature: feature
    })
  end

  def log_tutorial_dismiss(user_id, feature, reason \\ nil) do
    %__MODULE__{}
    |> changeset(%{
      user_id: user_id,
      interaction_type: "tutorial_dismiss",
      feature: feature,
      feedback: reason
    })
  end

  def log_recovery_used(user_id, error_type, action) do
    %__MODULE__{}
    |> changeset(%{
      user_id: user_id,
      interaction_type: "recovery_used",
      context: %{error_type: error_type, action: action}
    })
  end
end
