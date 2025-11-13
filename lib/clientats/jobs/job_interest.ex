defmodule Clientats.Jobs.JobInterest do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(interested researching not_a_fit ready_to_apply applied)
  @priorities ~w(low medium high)
  @work_models ~w(remote hybrid on_site)

  schema "job_interests" do
    field :company_name, :string
    field :position_title, :string
    field :job_description, :string
    field :job_url, :string
    field :location, :string
    field :work_model, :string
    field :salary_min, :integer
    field :salary_max, :integer
    field :status, :string, default: "interested"
    field :priority, :string, default: "medium"
    field :notes, :string

    belongs_to :user, Clientats.Accounts.User

    timestamps()
  end

  def changeset(job_interest, attrs) do
    job_interest
    |> cast(attrs, [
      :user_id,
      :company_name,
      :position_title,
      :job_description,
      :job_url,
      :location,
      :work_model,
      :salary_min,
      :salary_max,
      :status,
      :priority,
      :notes
    ])
    |> validate_required([:user_id, :company_name, :position_title])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:priority, @priorities)
    |> validate_inclusion(:work_model, @work_models, allow_nil: true)
    |> validate_number(:salary_min, greater_than_or_equal_to: 0)
    |> validate_number(:salary_max, greater_than_or_equal_to: 0)
    |> validate_salary_range()
    |> foreign_key_constraint(:user_id)
  end

  defp validate_salary_range(changeset) do
    min = get_field(changeset, :salary_min)
    max = get_field(changeset, :salary_max)

    if min && max && min > max do
      add_error(changeset, :salary_max, "must be greater than or equal to minimum salary")
    else
      changeset
    end
  end

  def statuses, do: @statuses
  def priorities, do: @priorities
  def work_models, do: @work_models
end
