defmodule Clientats.Repo.Migrations.CreateUserFeedbackAndPreferences do
  use Ecto.Migration

  def change do
    create table(:user_feedback) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :job_interest_id, references(:job_interests, on_delete: :delete_all)
      add :feedback_type, :string, null: false
      add :value, :float
      add :metadata, :map, default: %{}

      timestamps(updated_at: false)
    end

    create index(:user_feedback, [:user_id])
    create index(:user_feedback, [:user_id, :feedback_type])
    create index(:user_feedback, [:job_interest_id])

    create unique_index(:user_feedback, [:user_id, :job_interest_id, :feedback_type],
             name: :user_feedback_unique_signal
           )

    create table(:user_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :preference_type, :string, null: false
      add :value, :map, default: %{}

      timestamps()
    end

    create unique_index(:user_preferences, [:user_id, :preference_type])

    create table(:company_blocks) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :company_name, :string, null: false
      add :reason, :string

      timestamps(updated_at: false)
    end

    create unique_index(:company_blocks, [:user_id, :company_name])

    create table(:ranking_models) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :model_data, :binary
      add :training_examples, :integer, default: 0
      add :metrics, :map, default: %{}
      add :phase, :string, default: "llm_proxy"

      timestamps()
    end

    create unique_index(:ranking_models, [:user_id])
  end
end
