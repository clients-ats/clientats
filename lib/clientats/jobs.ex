defmodule Clientats.Jobs do
  import Ecto.Query, warn: false
  alias Clientats.Repo

  alias Clientats.Jobs.{JobInterest, JobApplication, ApplicationEvent}

  # Job Interests

  def list_job_interests(user_id) do
    JobInterest
    |> where(user_id: ^user_id)
    |> order_by([j], desc: j.inserted_at)
    |> Repo.all()
  end

  def get_job_interest!(id), do: Repo.get!(JobInterest, id)

  def create_job_interest(attrs \\ %{}) do
    %JobInterest{}
    |> JobInterest.changeset(attrs)
    |> Repo.insert()
  end

  def update_job_interest(%JobInterest{} = job_interest, attrs) do
    job_interest
    |> JobInterest.changeset(attrs)
    |> Repo.update()
  end

  def delete_job_interest(%JobInterest{} = job_interest) do
    Repo.delete(job_interest)
  end

  def change_job_interest(%JobInterest{} = job_interest, attrs \\ %{}) do
    JobInterest.changeset(job_interest, attrs)
  end

  # Job Applications

  def list_job_applications(user_id) do
    JobApplication
    |> where(user_id: ^user_id)
    |> order_by([j], desc: j.application_date)
    |> preload(:job_interest)
    |> Repo.all()
  end

  def get_job_application!(id) do
    JobApplication
    |> preload([:job_interest, :events, :resume])
    |> Repo.get!(id)
  end

  def create_job_application(attrs \\ %{}) do
    %JobApplication{}
    |> JobApplication.changeset(attrs)
    |> Repo.insert()
  end

  def update_job_application(%JobApplication{} = job_application, attrs) do
    job_application
    |> JobApplication.changeset(attrs)
    |> Repo.update()
  end

  def delete_job_application(%JobApplication{} = job_application) do
    Repo.delete(job_application)
  end

  def change_job_application(%JobApplication{} = job_application, attrs \\ %{}) do
    JobApplication.changeset(job_application, attrs)
  end

  # Application Events

  def list_application_events(job_application_id) do
    ApplicationEvent
    |> where(job_application_id: ^job_application_id)
    |> order_by([e], desc: e.event_date)
    |> Repo.all()
  end

  def get_application_event!(id), do: Repo.get!(ApplicationEvent, id)

  def create_application_event(attrs \\ %{}) do
    %ApplicationEvent{}
    |> ApplicationEvent.changeset(attrs)
    |> Repo.insert()
  end

  def update_application_event(%ApplicationEvent{} = event, attrs) do
    event
    |> ApplicationEvent.changeset(attrs)
    |> Repo.update()
  end

  def delete_application_event(%ApplicationEvent{} = event) do
    Repo.delete(event)
  end

  def change_application_event(%ApplicationEvent{} = event, attrs \\ %{}) do
    ApplicationEvent.changeset(event, attrs)
  end
end
