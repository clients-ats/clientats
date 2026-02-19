defmodule Clientats.Feedback.RankingModel do
  use Ecto.Schema
  import Ecto.Changeset

  @phases ~w(llm_proxy simple_model full_model)

  schema "ranking_models" do
    field :model_data, :binary
    field :training_examples, :integer, default: 0
    field :metrics, :map, default: %{}
    field :phase, :string, default: "llm_proxy"

    belongs_to :user, Clientats.Accounts.User

    timestamps()
  end

  def changeset(model, attrs) do
    model
    |> cast(attrs, [:user_id, :model_data, :training_examples, :metrics, :phase])
    |> validate_required([:user_id])
    |> validate_inclusion(:phase, @phases)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id])
  end

  @doc "Determine the training phase based on example count"
  def phase_for_count(n) when n < 30, do: "llm_proxy"
  def phase_for_count(n) when n < 100, do: "simple_model"
  def phase_for_count(_), do: "full_model"
end
