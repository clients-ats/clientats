defmodule ClientatsWeb.E2E.JobFixtures do
  @moduledoc """
  Shared job-related fixtures for E2E tests.
  """

  @doc """
  Create a job interest in the database.
  """
  def create_job_interest(user_id, attrs \\ %{}) do
    base_attrs = %{
      user_id: user_id,
      company_name: "Tech Corp",
      position_title: "Senior Engineer",
      status: "interested",
      priority: "high"
    }

    {:ok, interest} =
      base_attrs
      |> Map.merge(attrs)
      |> Clientats.Jobs.create_job_interest()

    interest
  end

  @doc """
  Create a job application in the database.
  """
  def create_job_application(user_id, attrs \\ %{}) do
    base_attrs = %{
      user_id: user_id,
      company_name: "Tech Corp",
      position_title: "Senior Backend Engineer",
      application_date: Date.utc_today(),
      status: "applied"
    }

    {:ok, app} =
      base_attrs
      |> Map.merge(attrs)
      |> Clientats.Jobs.create_job_application()

    app
  end

  @doc """
  Create a job application from an existing job interest.
  Deletes the interest after creating the application.
  """
  def create_job_application_from_interest(user_id, interest_id) do
    interest = Clientats.Jobs.get_job_interest!(interest_id)

    {:ok, app} =
      Clientats.Jobs.create_job_application(%{
        user_id: user_id,
        job_interest_id: interest_id,
        company_name: interest.company_name,
        position_title: interest.position_title,
        application_date: Date.utc_today()
      })

    Clientats.Jobs.delete_job_interest(interest)
    app
  end

  @doc """
  Create an application event (activity) for a job application.
  """
  def create_application_event(application_id, attrs \\ %{}) do
    base_attrs = %{
      job_application_id: application_id,
      event_type: "applied",
      event_date: Date.utc_today()
    }

    {:ok, event} =
      base_attrs
      |> Map.merge(attrs)
      |> Clientats.Jobs.create_application_event()

    event
  end
end
