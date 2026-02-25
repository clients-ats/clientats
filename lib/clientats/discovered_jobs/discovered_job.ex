defmodule Clientats.DiscoveredJobs.DiscoveredJob do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(new reviewed dismissed promoted)
  @sources ~w(linkedin)

  schema "discovered_jobs" do
    field :company, :string
    field :title, :string
    field :description, :string
    field :url, :string
    field :location, :string
    field :work_model, :string
    field :salary, :string
    field :source, :string, default: "linkedin"
    field :source_id, :string
    field :status, :string, default: "new"
    field :extracted_data, :map, default: %{}
    field :score, :float
    field :fingerprint, :string

    belongs_to :user, Clientats.Accounts.User
    belongs_to :promoted_job_interest, Clientats.Jobs.JobInterest

    timestamps()
  end

  def changeset(discovered_job, attrs) do
    discovered_job
    |> cast(attrs, [
      :user_id,
      :company,
      :title,
      :description,
      :url,
      :location,
      :work_model,
      :salary,
      :source,
      :source_id,
      :status,
      :extracted_data,
      :score,
      :fingerprint,
      :promoted_job_interest_id
    ])
    |> validate_required([:user_id, :company, :title, :source, :fingerprint])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:source, @sources)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:promoted_job_interest_id)
    |> unique_constraint([:user_id, :fingerprint])
    |> maybe_generate_fingerprint()
  end

  defp maybe_generate_fingerprint(changeset) do
    case get_field(changeset, :fingerprint) do
      nil ->
        company = get_field(changeset, :company)
        title = get_field(changeset, :title)
        location = get_field(changeset, :location)

        if company && title do
          put_change(changeset, :fingerprint, Clientats.LinkedIn.dedup_fingerprint(company, title, location))
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  def statuses, do: @statuses
  def sources, do: @sources
end
