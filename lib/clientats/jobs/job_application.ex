defmodule Clientats.Jobs.JobApplication do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(applied phone_screen interview_scheduled interviewed offer_received offer_accepted rejected withdrawn)
  @work_models ~w(remote hybrid on_site)

  schema "job_applications" do
    field :company_name, :string
    field :position_title, :string
    field :job_description, :string
    field :job_url, :string
    field :location, :string
    field :work_model, :string
    field :salary_min, :integer
    field :salary_max, :integer
    field :application_date, :date
    field :status, :string, default: "applied"
    field :cover_letter_path, :string
    field :cover_letter_content, :string
    field :cover_letter_pdf_path, :string
    field :resume_path, :string
    field :resume_pdf_path, :string
    field :notes, :string

    belongs_to :user, Clientats.Accounts.User
    belongs_to :job_interest, Clientats.Jobs.JobInterest
    has_many :events, Clientats.Jobs.ApplicationEvent

    timestamps()
  end

  def changeset(job_application, attrs) do
    job_application
    |> cast(attrs, [
      :user_id,
      :job_interest_id,
      :company_name,
      :position_title,
      :job_description,
      :job_url,
      :location,
      :work_model,
      :salary_min,
      :salary_max,
      :application_date,
      :status,
      :cover_letter_path,
      :cover_letter_content,
      :cover_letter_pdf_path,
      :resume_path,
      :resume_pdf_path,
      :notes
    ])
    |> validate_required([:user_id, :company_name, :position_title, :application_date])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:work_model, @work_models, allow_nil: true)
    |> validate_number(:salary_min, greater_than_or_equal_to: 0)
    |> validate_number(:salary_max, greater_than_or_equal_to: 0)
    |> validate_salary_range()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:job_interest_id)
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
  def work_models, do: @work_models
end
