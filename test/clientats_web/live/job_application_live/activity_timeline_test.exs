defmodule ClientatsWeb.JobApplicationLive.ActivityTimelineTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Activity Timeline" do
    test "renders empty state when no activities exist", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Activity Timeline"
      assert html =~ "No activities yet"
      assert html =~ "Track emails, interviews, and other interactions"
    end

    test "displays existing events in chronological order (newest first)", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      _event1 = application_event_fixture(
        job_application_id: app.id,
        event_type: "contact",
        event_date: ~D[2024-01-10]
      )

      _event2 = application_event_fixture(
        job_application_id: app.id,
        event_type: "phone_screen",
        event_date: ~D[2024-01-15]
      )

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      # Newer event should appear first
      phone_screen_pos = html |> :binary.match("Phone Screen") |> elem(0)
      contact_pos = html |> :binary.match("Contact") |> elem(0)

      assert phone_screen_pos < contact_pos
    end

    test "shows add activity button", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Add Activity"
    end

    test "toggles activity form when add button is clicked", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      refute html =~ "Event Type"

      html =
        lv
        |> element("button", "Add Activity")
        |> render_click()

      assert html =~ "Event Type"
      assert html =~ "Select event type..."
    end

    test "creates new activity with required fields", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      lv |> element("button", "Add Activity") |> render_click()

      lv
      |> form("form[phx-submit='save_event']", %{
        "event_type" => "phone_screen",
        "event_date" => "2024-01-20"
      })
      |> render_submit()

      html = render(lv)

      assert html =~ "Activity added successfully"
      assert html =~ "Phone Screen"
      assert html =~ "January 20, 2024"
    end

    test "creates activity with all optional fields", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      lv |> element("button", "Add Activity") |> render_click()

      lv
      |> form("form[phx-submit='save_event']", %{
        "event_type" => "interview_onsite",
        "event_date" => "2024-01-25",
        "contact_person" => "Jane Smith",
        "contact_email" => "jane@company.com",
        "contact_phone" => "555-1234",
        "notes" => "Great interview, technical questions",
        "follow_up_date" => "2024-02-01"
      })
      |> render_submit()

      html = render(lv)

      assert html =~ "Activity added successfully"
      assert html =~ "Onsite Interview"
      assert html =~ "Jane Smith"
      assert html =~ "jane@company.com"
      assert html =~ "555-1234"
      assert html =~ "Great interview, technical questions"
      assert html =~ "Follow-up: Feb 01, 2024"
    end

    test "validates required fields", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      lv |> element("button", "Add Activity") |> render_click()

      result =
        lv
        |> form("form[phx-submit='save_event']", %{
          "event_type" => "",
          "event_date" => ""
        })
        |> render_submit()

      assert result =~ "Failed to save activity"
    end

    test "edits existing activity", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      event = application_event_fixture(
        job_application_id: app.id,
        event_type: "contact",
        event_date: ~D[2024-01-15],
        notes: "Initial email"
      )

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      # Click edit button
      lv
      |> element("button[phx-click='edit_event'][phx-value-id='#{event.id}']")
      |> render_click()

      html = render(lv)

      # Form should be populated
      assert html =~ "Update Activity"

      # Update the event
      lv
      |> form("form[phx-submit='save_event']", %{
        "event_type" => "phone_screen",
        "event_date" => "2024-01-16",
        "notes" => "Updated notes"
      })
      |> render_submit()

      html = render(lv)

      assert html =~ "Activity updated successfully"
      assert html =~ "Phone Screen"
      assert html =~ "Updated notes"
      refute html =~ "Initial email"
    end

    test "deletes activity", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      event = application_event_fixture(
        job_application_id: app.id,
        event_type: "follow_up",
        event_date: ~D[2024-01-20],
        notes: "Follow up call"
      )

      conn = log_in_user(conn, user)

      {:ok, lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Follow-up"
      assert html =~ "Follow up call"

      lv
      |> element("button[phx-click='delete_event'][phx-value-id='#{event.id}']")
      |> render_click()

      html = render(lv)

      assert html =~ "Activity deleted successfully"
      refute html =~ "Follow-up"
      refute html =~ "Follow up call"
    end

    test "displays different event types with correct formatting", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      application_event_fixture(job_application_id: app.id, event_type: "applied", event_date: ~D[2024-01-10])
      application_event_fixture(job_application_id: app.id, event_type: "contact", event_date: ~D[2024-01-11])
      application_event_fixture(job_application_id: app.id, event_type: "phone_screen", event_date: ~D[2024-01-12])
      application_event_fixture(job_application_id: app.id, event_type: "technical_screen", event_date: ~D[2024-01-13])
      application_event_fixture(job_application_id: app.id, event_type: "interview_onsite", event_date: ~D[2024-01-14])
      application_event_fixture(job_application_id: app.id, event_type: "offer", event_date: ~D[2024-01-15])

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Applied"
      assert html =~ "Contact"
      assert html =~ "Phone Screen"
      assert html =~ "Technical Screen"
      assert html =~ "Onsite Interview"
      assert html =~ "Offer"
    end

    test "shows updated timestamp when event is modified", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      event = application_event_fixture(
        job_application_id: app.id,
        event_type: "contact",
        event_date: ~D[2024-01-15]
      )

      # Update the event to change its updated_at
      :timer.sleep(1000)
      {:ok, _updated} = Clientats.Jobs.update_application_event(event, %{notes: "Updated"})

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Last updated"
    end

    test "cancels form when cancel button is clicked", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      # Open form
      html =
        lv
        |> element("button", "Add Activity")
        |> render_click()

      assert html =~ "Event Type"

      # Click cancel (button text changes to "Cancel" when form is open)
      html =
        lv
        |> element("button", "Cancel")
        |> render_click()

      refute html =~ "Event Type"
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

  defp job_application_fixture(attrs) do
    default_attrs = %{
      company_name: "Default Corp",
      position_title: "Software Engineer",
      application_date: Date.utc_today(),
      status: "applied"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, app} = Clientats.Jobs.create_job_application(attrs)
    app
  end

  defp application_event_fixture(attrs) do
    default_attrs = %{
      event_type: "contact",
      event_date: Date.utc_today()
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, event} = Clientats.Jobs.create_application_event(attrs)
    event
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
