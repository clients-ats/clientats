defmodule Clientats.Jobs.ApplicationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @event_types ~w(applied contact phone_screen technical_screen interview_onsite follow_up offer rejection withdrawn)

  schema "application_events" do
    field :event_type, :string
    field :event_date, :date
    field :contact_person, :string
    field :contact_email, :string
    field :contact_phone, :string
    field :notes, :string
    field :follow_up_date, :date

    belongs_to :job_application, Clientats.Jobs.JobApplication

    timestamps()
  end

  def changeset(application_event, attrs) do
    application_event
    |> cast(attrs, [
      :job_application_id,
      :event_type,
      :event_date,
      :contact_person,
      :contact_email,
      :contact_phone,
      :notes,
      :follow_up_date
    ])
    |> validate_required([:job_application_id, :event_type, :event_date])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_format(:contact_email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> foreign_key_constraint(:job_application_id)
  end

  def event_types, do: @event_types
end
