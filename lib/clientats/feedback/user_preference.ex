defmodule Clientats.Feedback.UserPreference do
  use Ecto.Schema
  import Ecto.Changeset

  @preference_types ~w(skills roles industries location salary work_model seniority)

  schema "user_preferences" do
    field :preference_type, :string
    field :value, :map, default: %{}

    belongs_to :user, Clientats.Accounts.User

    timestamps()
  end

  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [:user_id, :preference_type, :value])
    |> validate_required([:user_id, :preference_type])
    |> validate_inclusion(:preference_type, @preference_types)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:user_id, :preference_type])
  end

  def preference_types, do: @preference_types

  @doc "Convert all user preferences into the flat map expected by FeatureExtractor"
  def to_feature_prefs(preferences) when is_list(preferences) do
    Enum.reduce(preferences, %{}, fn pref, acc ->
      case pref.preference_type do
        "skills" ->
          Map.put(acc, :skills, pref.value["list"] || [])

        "salary" ->
          acc
          |> Map.put(:salary_min, pref.value["min"])
          |> Map.put(:salary_max, pref.value["max"])

        "location" ->
          Map.put(acc, :preferred_location, pref.value["preferred"] || "")

        "work_model" ->
          Map.put(acc, :work_model, pref.value["preferred"] || "")

        "seniority" ->
          Map.put(acc, :seniority_level, pref.value["level"] || "")

        "industries" ->
          Map.put(acc, :industry, hd(pref.value["list"] || [""]))

        _ ->
          acc
      end
    end)
  end
end
