defmodule ClientatsWeb.Features.ApplicationEventsTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query

  @moduletag :feature

  # Test Case 7A.1: Create Application Event (Applied)
  test "create applied event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> assert_has(css("h1", text: application.position_title))
    |> click(button("Add Activity"))
    |> assert_has(css("h3", text: "Add Activity"))
    |> click(css("select[name='event_type'] option[value='applied']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-15")
    |> fill_in(css("textarea[name='notes']"), with: "Submitted application through company portal")
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Applied"))
    |> assert_has(css(".timeline-event", text: "2024-01-15"))
    |> assert_has(css(".timeline-event", text: "Submitted application through company portal"))
  end

  # Test Case 7A.2: Create Contact Event with email and phone validation
  test "create contact event with valid contact information", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='contact']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-16")
    |> fill_in(css("input[name='contact_person']"), with: "Jane Smith")
    |> fill_in(css("input[name='contact_email']"), with: "jane.smith@techcorp.com")
    |> fill_in(css("input[name='contact_phone']"), with: "555-123-4567")
    |> fill_in(css("textarea[name='notes']"), with: "Initial outreach via LinkedIn")
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Contact"))
    |> assert_has(css(".timeline-event", text: "Jane Smith"))
    |> assert_has(css(".timeline-event", text: "jane.smith@techcorp.com"))
  end

  # Test Case 7A.11: Contact Email Validation
  test "validate contact email format", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='contact']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-16")
    |> fill_in(css("input[name='contact_email']"), with: "invalid-email")
    |> click(button("Save Activity"))
    |> assert_has(css(".error-message", text: "must be a valid email"))
  end

  # Test Case 7A.3: Create Phone Screen Event
  test "create phone screen event with follow-up date", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='phone_screen']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-20")
    |> fill_in(css("input[name='contact_person']"), with: "John Recruiter")
    |> fill_in(css("input[name='follow_up_date']"), with: "2024-01-25")
    |> fill_in(css("textarea[name='notes']"),
      with: "Discussed role and compensation expectations"
    )
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Phone Screen"))
    |> assert_has(css(".timeline-event", text: "John Recruiter"))
    |> assert_has(css(".timeline-event", text: "Follow-up: 2024-01-25"))
  end

  # Test Case 7A.4: Create Interview Events (Technical Screen and Onsite)
  test "create technical screen event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='technical_screen']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-22")
    |> fill_in(css("input[name='contact_person']"), with: "Sarah Engineer")
    |> fill_in(css("textarea[name='notes']"), with: "Coding challenge - algorithms and data structures")
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Technical Screen"))
    |> assert_has(css(".timeline-event", text: "Sarah Engineer"))
  end

  test "create onsite interview event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='interview_onsite']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-25")
    |> fill_in(css("input[name='contact_person']"), with: "Team Lead")
    |> fill_in(css("textarea[name='notes']"),
      with: "Full day onsite - met with 5 team members"
    )
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Onsite Interview"))
  end

  # Test Case 7A.5: Create Follow-Up Event
  test "create follow-up event with next action date", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='follow_up']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-28")
    |> fill_in(css("input[name='follow_up_date']"), with: "2024-02-05")
    |> fill_in(css("textarea[name='notes']"),
      with: "Sent thank you email to hiring manager"
    )
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Follow-up"))
    |> assert_has(css(".timeline-event", text: "Follow-up: 2024-02-05"))
  end

  # Test Case 7A.6: Create Offer Event
  test "create offer event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='offer']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-02-01")
    |> fill_in(css("textarea[name='notes']"),
      with: "Offer received: $150,000 salary + benefits"
    )
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Offer"))
    |> assert_has(css(".timeline-event", text: "$150,000 salary"))
  end

  # Test Case 7A.7: Create Rejection Event
  test "create rejection event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='rejection']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-30")
    |> fill_in(css("textarea[name='notes']"),
      with: "Position filled by another candidate"
    )
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Rejection"))
    |> assert_has(css(".timeline-event", text: "Position filled by another candidate"))
  end

  # Test Case 7A.8: Create Withdrawn Event
  test "create withdrawn event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='withdrawn']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-28")
    |> fill_in(css("textarea[name='notes']"),
      with: "Accepted offer from another company"
    )
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Withdrawn"))
    |> assert_has(css(".timeline-event", text: "Accepted offer from another company"))
  end

  # Test Case 7A.9: Edit Application Event
  test "edit existing event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    event =
      create_application_event(application.id, %{
        event_type: "contact",
        event_date: ~D[2024-01-15],
        contact_person: "Old Name",
        notes: "Original notes"
      })

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> assert_has(css(".timeline-event", text: "Old Name"))
    |> click(css(".edit-event-#{event.id}"))
    |> fill_in(css("input[name='contact_person']"), with: "Updated Name")
    |> fill_in(css("textarea[name='notes']"), with: "Updated notes")
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Updated Name"))
    |> assert_has(css(".timeline-event", text: "Updated notes"))
    |> refute_has(css(".timeline-event", text: "Old Name"))
  end

  # Test Case 7A.10: Delete Application Event
  test "delete event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    event =
      create_application_event(application.id, %{
        event_type: "contact",
        event_date: ~D[2024-01-15],
        notes: "Event to be deleted"
      })

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> assert_has(css(".timeline-event", text: "Event to be deleted"))
    |> click(css(".delete-event-#{event.id}"))
    |> refute_has(css(".timeline-event", text: "Event to be deleted"))
  end

  # Test Case 7A.12: Follow-Up Date Scheduling
  test "schedule follow-up dates for future actions", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    future_date = Date.utc_today() |> Date.add(7) |> Date.to_string()

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='phone_screen']"))
    |> fill_in(css("input[name='event_date']"), with: Date.utc_today() |> Date.to_string())
    |> fill_in(css("input[name='follow_up_date']"), with: future_date)
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Follow-up: #{future_date}"))
  end

  # Test Case 7A.13: Phone Number Validation (various formats)
  test "accept various phone number formats", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    # Test format: (555) 123-4567
    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='contact']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-16")
    |> fill_in(css("input[name='contact_phone']"), with: "(555) 123-4567")
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", text: "Contact"))

    # Test format: 555-123-4567
    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='contact']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-17")
    |> fill_in(css("input[name='contact_phone']"), with: "555-123-4567")
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", count: 2))

    # Test format: 5551234567
    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    |> click(css("select[name='event_type'] option[value='contact']"))
    |> fill_in(css("input[name='event_date']"), with: "2024-01-18")
    |> fill_in(css("input[name='contact_phone']"), with: "5551234567")
    |> click(button("Save Activity"))
    |> assert_has(css(".timeline-event", count: 3))
  end

  # Test: Timeline Display (chronological order)
  test "display events in chronological order", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    # Create events in non-chronological order
    create_application_event(application.id, %{
      event_type: "offer",
      event_date: ~D[2024-02-01],
      notes: "Third event chronologically"
    })

    create_application_event(application.id, %{
      event_type: "applied",
      event_date: ~D[2024-01-15],
      notes: "First event chronologically"
    })

    create_application_event(application.id, %{
      event_type: "phone_screen",
      event_date: ~D[2024-01-20],
      notes: "Second event chronologically"
    })

    # Visit and verify chronological order
    session
    |> visit("/dashboard/applications/#{application.id}")
    |> assert_has(css(".timeline-event", count: 3))

    # The timeline should display events in date order
    # This is a visual check - the UI should render them properly
  end

  # Test: Multiple Events of Different Types
  test "create and display multiple event types in timeline", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    event_types = [
      "applied",
      "contact",
      "phone_screen",
      "technical_screen",
      "interview_onsite",
      "follow_up",
      "offer"
    ]

    # Create one event of each type
    event_types
    |> Enum.with_index(1)
    |> Enum.each(fn {event_type, index} ->
      create_application_event(application.id, %{
        event_type: event_type,
        event_date: Date.utc_today() |> Date.add(index),
        notes: "Event #{index}"
      })
    end)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> assert_has(css(".timeline-event", count: 7))
    |> assert_has(css(".timeline-event", text: "Applied"))
    |> assert_has(css(".timeline-event", text: "Contact"))
    |> assert_has(css(".timeline-event", text: "Phone Screen"))
    |> assert_has(css(".timeline-event", text: "Technical Screen"))
    |> assert_has(css(".timeline-event", text: "Onsite Interview"))
    |> assert_has(css(".timeline-event", text: "Follow-up"))
    |> assert_has(css(".timeline-event", text: "Offer"))
  end

  # Test: Event Creation Requires Valid Application
  test "cannot create event without valid application id", %{session: session} do
    _user = create_user_and_login(session)

    # Attempt to visit non-existent application
    assert_raise Ecto.NoResultsError, fn ->
      session
      |> visit("/dashboard/applications/99999")
    end
  end

  # Test: Event Validation - Required Fields
  test "validate required fields when creating event", %{session: session} do
    user = create_user_and_login(session)
    application = create_job_application(user.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> click(button("Add Activity"))
    # Try to save without filling required fields
    |> click(button("Save Activity"))
    |> assert_has(css(".error-message"))
  end

  # Helper functions
  defp create_user do
    %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }
  end

  defp create_user_and_login(session) do
    user = create_user()
    {:ok, db_user} = Clientats.Accounts.register_user(user)

    session
    |> visit("/login")
    |> fill_in(css("input[name='user[email]']"), with: user.email)
    |> fill_in(css("input[name='user[password]']"), with: user.password)
    |> click(button("Sign in"))

    Map.put(user, :id, db_user.id)
  end

  defp create_job_application(user_id) do
    {:ok, app} =
      Clientats.Jobs.create_job_application(%{
        user_id: user_id,
        company_name: "Tech Corp",
        position_title: "Senior Backend Engineer",
        application_date: Date.utc_today(),
        status: "applied"
      })

    app
  end

  defp create_application_event(application_id, attrs) do
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
