defmodule Clientats.LLM.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @providers ~w(ollama gemini)
  @statuses ~w(unconfigured configured connected error)

  schema "llm_settings" do
    field :provider, :string
    field :api_key, :binary
    field :base_url, :string
    field :default_model, :string
    field :vision_model, :string
    field :text_model, :string
    field :enabled, :boolean, default: false
    field :provider_status, :string, default: "unconfigured"
    field :last_tested_at, :naive_datetime
    field :last_error, :string

    belongs_to :user, Clientats.Accounts.User

    timestamps()
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [
      :user_id,
      :provider,
      :api_key,
      :base_url,
      :default_model,
      :vision_model,
      :text_model,
      :enabled,
      :provider_status,
      :last_tested_at,
      :last_error
    ])
    |> validate_required([:user_id, :provider])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:provider_status, @statuses, allow_nil: true)
    |> unique_constraint([:user_id, :provider])
    |> foreign_key_constraint(:user_id)
  end

  def providers, do: @providers
  def statuses, do: @statuses
end
