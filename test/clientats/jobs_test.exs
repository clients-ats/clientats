defmodule Clientats.JobsTest do
  use Clientats.DataCase

  alias Clientats.Jobs

  describe "job_interests" do
    test "list_job_interests/1 returns all job interests for a user" do
      user = user_fixture()
      interest1 = job_interest_fixture(user_id: user.id)
      interest2 = job_interest_fixture(user_id: user.id)
      other_user = user_fixture()
      _other_interest = job_interest_fixture(user_id: other_user.id)

      interests = Jobs.list_job_interests(user.id)
      interest_ids = Enum.map(interests, & &1.id)

      assert length(interests) == 2
      assert interest1.id in interest_ids
      assert interest2.id in interest_ids
    end

    test "get_job_interest!/1 returns the job interest with given id" do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      assert Jobs.get_job_interest!(interest.id).id == interest.id
    end

    test "create_job_interest/1 with valid data creates a job interest" do
      user = user_fixture()

      valid_attrs = %{
        user_id: user.id,
        company_name: "Tech Corp",
        position_title: "Software Engineer",
        job_description: "Great job",
        job_url: "https://example.com/job",
        location: "Remote",
        work_model: "remote",
        salary_min: 80000,
        salary_max: 120000,
        status: "interested",
        priority: "high"
      }

      assert {:ok, interest} = Jobs.create_job_interest(valid_attrs)
      assert interest.company_name == "Tech Corp"
      assert interest.position_title == "Software Engineer"
      assert interest.status == "interested"
      assert interest.priority == "high"
    end

    test "create_job_interest/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Jobs.create_job_interest(%{})
    end

    test "create_job_interest/1 requires company_name" do
      user = user_fixture()

      invalid_attrs = %{
        user_id: user.id,
        position_title: "Engineer"
      }

      assert {:error, changeset} = Jobs.create_job_interest(invalid_attrs)
      assert %{company_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_job_interest/1 requires position_title" do
      user = user_fixture()

      invalid_attrs = %{
        user_id: user.id,
        company_name: "Tech Corp"
      }

      assert {:error, changeset} = Jobs.create_job_interest(invalid_attrs)
      assert %{position_title: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_job_interest/1 validates salary range" do
      user = user_fixture()

      invalid_attrs = %{
        user_id: user.id,
        company_name: "Tech Corp",
        position_title: "Engineer",
        salary_min: 120000,
        salary_max: 80000
      }

      assert {:error, changeset} = Jobs.create_job_interest(invalid_attrs)
      assert %{salary_max: ["must be greater than or equal to minimum salary"]} = errors_on(changeset)
    end

    test "update_job_interest/2 with valid data updates the job interest" do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      update_attrs = %{company_name: "New Company", status: "ready_to_apply"}

      assert {:ok, updated} = Jobs.update_job_interest(interest, update_attrs)
      assert updated.company_name == "New Company"
      assert updated.status == "ready_to_apply"
    end

    test "delete_job_interest/1 deletes the job interest" do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      assert {:ok, _} = Jobs.delete_job_interest(interest)
      assert_raise Ecto.NoResultsError, fn -> Jobs.get_job_interest!(interest.id) end
    end

    test "change_job_interest/1 returns a job interest changeset" do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      assert %Ecto.Changeset{} = Jobs.change_job_interest(interest)
    end
  end

  describe "job_applications" do
    test "list_job_applications/1 returns all job applications for a user" do
      user = user_fixture()
      app1 = job_application_fixture(user_id: user.id)
      app2 = job_application_fixture(user_id: user.id)
      other_user = user_fixture()
      _other_app = job_application_fixture(user_id: other_user.id)

      apps = Jobs.list_job_applications(user.id)
      app_ids = Enum.map(apps, & &1.id)

      assert length(apps) == 2
      assert app1.id in app_ids
      assert app2.id in app_ids
    end

    test "get_job_application!/1 returns the job application with given id" do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      assert Jobs.get_job_application!(app.id).id == app.id
    end

    test "create_job_application/1 with valid data creates a job application" do
      user = user_fixture()

      valid_attrs = %{
        user_id: user.id,
        company_name: "Tech Corp",
        position_title: "Software Engineer",
        application_date: ~D[2024-01-15],
        status: "applied"
      }

      assert {:ok, app} = Jobs.create_job_application(valid_attrs)
      assert app.company_name == "Tech Corp"
      assert app.position_title == "Software Engineer"
      assert app.application_date == ~D[2024-01-15]
      assert app.status == "applied"
    end

    test "create_job_application/1 links to job_interest if provided" do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)

      valid_attrs = %{
        user_id: user.id,
        job_interest_id: interest.id,
        company_name: "Tech Corp",
        position_title: "Software Engineer",
        application_date: ~D[2024-01-15]
      }

      assert {:ok, app} = Jobs.create_job_application(valid_attrs)
      assert app.job_interest_id == interest.id
    end

    test "create_job_application/1 requires application_date" do
      user = user_fixture()

      invalid_attrs = %{
        user_id: user.id,
        company_name: "Tech Corp",
        position_title: "Engineer"
      }

      assert {:error, changeset} = Jobs.create_job_application(invalid_attrs)
      assert %{application_date: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_job_application/2 with valid data updates the job application" do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      update_attrs = %{status: "interviewed"}

      assert {:ok, updated} = Jobs.update_job_application(app, update_attrs)
      assert updated.status == "interviewed"
    end

    test "delete_job_application/1 deletes the job application" do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      assert {:ok, _} = Jobs.delete_job_application(app)
      assert_raise Ecto.NoResultsError, fn -> Jobs.get_job_application!(app.id) end
    end
  end

  describe "application_events" do
    test "list_application_events/1 returns all events for an application" do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      event1 = application_event_fixture(job_application_id: app.id)
      event2 = application_event_fixture(job_application_id: app.id)

      events = Jobs.list_application_events(app.id)
      event_ids = Enum.map(events, & &1.id)

      assert length(events) == 2
      assert event1.id in event_ids
      assert event2.id in event_ids
    end

    test "create_application_event/1 with valid data creates an event" do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      valid_attrs = %{
        job_application_id: app.id,
        event_type: "phone_screen",
        event_date: ~D[2024-01-20],
        contact_person: "Jane Recruiter",
        contact_email: "jane@techcorp.com",
        notes: "Great conversation"
      }

      assert {:ok, event} = Jobs.create_application_event(valid_attrs)
      assert event.event_type == "phone_screen"
      assert event.contact_person == "Jane Recruiter"
    end

    test "create_application_event/1 validates email format" do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      invalid_attrs = %{
        job_application_id: app.id,
        event_type: "contact",
        event_date: ~D[2024-01-20],
        contact_email: "invalid-email"
      }

      assert {:error, changeset} = Jobs.create_application_event(invalid_attrs)
      assert %{contact_email: ["must be a valid email"]} = errors_on(changeset)
    end

    test "delete_application_event/1 deletes the event" do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      event = application_event_fixture(job_application_id: app.id)

      assert {:ok, _} = Jobs.delete_application_event(event)
      assert_raise Ecto.NoResultsError, fn -> Jobs.get_application_event!(event.id) end
    end
  end

  defp user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "user#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, user} = Clientats.Accounts.register_user(attrs)
    user
  end

  defp job_interest_fixture(attrs \\ %{}) do
    default_attrs = %{
      company_name: "Default Corp",
      position_title: "Software Engineer",
      status: "interested",
      priority: "medium"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, interest} = Jobs.create_job_interest(attrs)
    interest
  end

  defp job_application_fixture(attrs \\ %{}) do
    default_attrs = %{
      company_name: "Default Corp",
      position_title: "Software Engineer",
      application_date: Date.utc_today(),
      status: "applied"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, app} = Jobs.create_job_application(attrs)
    app
  end

  defp application_event_fixture(attrs \\ %{}) do
    default_attrs = %{
      event_type: "applied",
      event_date: Date.utc_today()
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, event} = Jobs.create_application_event(attrs)
    event
  end
end
