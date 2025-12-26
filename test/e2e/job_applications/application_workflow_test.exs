defmodule ClientatsWeb.E2E.ApplicationWorkflowTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query
  import ClientatsWeb.E2E.UserFixtures
  import ClientatsWeb.E2E.JobFixtures

  @moduletag :feature

  describe "interest to application conversion" do
    test "converts job interest to application successfully", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        company_name: "Conversion Corp",
        position_title: "Conversion Engineer"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> assert_has(css("h1", text: "Conversion Engineer"))
      |> click(link("Apply for Job"))
      |> assert_has(css("h2", text: "New Job Application"))
      |> assert_has(css("p", text: "Converting job interest to application"))
      |> assert_has(css("input[value='Conversion Corp']"))
      |> assert_has(css("input[value='Conversion Engineer']"))
      |> fill_in(css("input[name='job_application[application_date]']"), with: "2024-01-15")
      |> click(button("Create Application"))
      |> assert_has(css("h1", text: "Conversion Engineer"))
      |> assert_has(css("h2", text: "Conversion Corp"))
    end

    test "interest is deleted after conversion to application", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        company_name: "Delete Corp",
        position_title: "Delete Test"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> click(link("Apply for Job"))
      |> fill_in(css("input[name='job_application[application_date]']"), with: "2024-01-15")
      |> click(button("Create Application"))
      |> visit("/dashboard")
      |> refute_has(css("h3", text: "Delete Test"))
    end

    test "can convert application back to interest", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{position_title: "Revert Test"})
      application = create_job_application_from_interest(user.id, interest.id)

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Convert to Interest"))
      |> assert_has(css("h1", text: "Clientats Dashboard"))
      |> assert_has(css("h3", text: "Revert Test"))
      |> visit("/dashboard/applications")
      |> refute_has(css("h3", text: "Revert Test"))
    end

    test "conversion wizard pre-fills data from interest", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        company_name: "PreFill Corp",
        position_title: "PreFill Engineer",
        job_url: "https://prefill.com/jobs"
      })

      session
      |> visit("/dashboard/applications/convert/#{interest.id}")
      |> assert_has(css("input[value='PreFill Corp']"))
      |> assert_has(css("input[value='PreFill Engineer']"))
      |> assert_has(css("input[value='https://prefill.com/jobs']"))
    end
  end

  describe "direct application creation" do
    test "creates application directly without interest", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> click(link("Applications"))
      |> click(link("Add Application"))
      |> fill_in(css("input[name='job_application[company_name]']"), with: "Direct Corp")
      |> fill_in(css("input[name='job_application[position_title]']"), with: "Direct Engineer")
      |> fill_in(css("input[name='job_application[application_date]']"), with: "2024-01-20")
      |> click(button("Create Application"))
      |> assert_has(css("h1", text: "Direct Engineer"))
      |> assert_has(css("h2", text: "Direct Corp"))
    end

    test "validates required fields when creating application", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/applications/new")
      |> click(button("Create Application"))
      |> assert_has(css(".phx-form-error", text: "can't be blank"))
    end
  end

  describe "application status workflow" do
    test "application starts with applied status", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{status: "applied"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css("span.status-badge", text: "applied"))
    end

    test "can change status from applied to interviewing", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{status: "applied"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "interviewing")
      |> click(button("Save"))
      |> assert_has(css("span.status-badge", text: "interviewing"))
    end

    test "can change status from interviewing to offered", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{status: "interviewing"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "offered")
      |> click(button("Save"))
      |> assert_has(css("span.status-badge", text: "offered"))
    end

    test "can change status from offered to accepted", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{status: "offered"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "accepted")
      |> click(button("Save"))
      |> assert_has(css("span.status-badge", text: "accepted"))
    end

    test "can mark application as rejected", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{status: "applied"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "rejected")
      |> click(button("Save"))
      |> assert_has(css("span.status-badge", text: "rejected"))
    end

    test "can withdraw application", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{status: "applied"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "withdrawn")
      |> click(button("Save"))
      |> assert_has(css("span.status-badge", text: "withdrawn"))
    end

    test "status changes are reflected in the timeline", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{status: "applied"})

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css(".timeline-event", text: "Status changed to applied"))
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "interviewing")
      |> click(button("Save"))
      |> assert_has(css(".timeline-event", text: "Status changed to interviewing"))
    end
  end

  describe "timeline tracking" do
    test "displays chronological timeline of events", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id)

      create_application_event(application.id, %{
        event_type: "applied",
        event_date: ~D[2024-01-15],
        notes: "First event"
      })

      create_application_event(application.id, %{
        event_type: "phone_screen",
        event_date: ~D[2024-01-20],
        notes: "Second event"
      })

      create_application_event(application.id, %{
        event_type: "interview_onsite",
        event_date: ~D[2024-01-25],
        notes: "Third event"
      })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css(".timeline"))
      |> assert_has(css(".timeline-event", text: "First event"))
      |> assert_has(css(".timeline-event", text: "Second event"))
      |> assert_has(css(".timeline-event", text: "Third event"))
    end

    test "timeline shows event dates in correct order", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id)

      # Create events out of order
      create_application_event(application.id, %{
        event_type: "interview_onsite",
        event_date: ~D[2024-01-25]
      })

      create_application_event(application.id, %{
        event_type: "applied",
        event_date: ~D[2024-01-15]
      })

      create_application_event(application.id, %{
        event_type: "phone_screen",
        event_date: ~D[2024-01-20]
      })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css(".timeline-event:nth-child(1)", text: "2024-01-15"))
      |> assert_has(css(".timeline-event:nth-child(2)", text: "2024-01-20"))
      |> assert_has(css(".timeline-event:nth-child(3)", text: "2024-01-25"))
    end

    test "empty timeline shows helpful message", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id)

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css("p", text: "No activities yet"))
    end

    test "timeline displays contact information for events", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id)

      create_application_event(application.id, %{
        event_type: "contact",
        event_date: ~D[2024-01-16],
        contact_person: "Jane Recruiter",
        contact_email: "jane@company.com"
      })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css(".timeline-event", text: "Jane Recruiter"))
      |> assert_has(css(".timeline-event", text: "jane@company.com"))
    end

    test "timeline shows follow-up dates", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id)

      create_application_event(application.id, %{
        event_type: "phone_screen",
        event_date: ~D[2024-01-20],
        follow_up_date: ~D[2024-01-25]
      })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css(".timeline-event", text: "Follow-up: 2024-01-25"))
    end
  end

  describe "application management" do
    test "can view application details", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{
        company_name: "View Corp",
        position_title: "View Engineer",
        application_date: ~D[2024-01-15]
      })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> assert_has(css("h1", text: "View Engineer"))
      |> assert_has(css("h2", text: "View Corp"))
      |> assert_has(css("p", text: "2024-01-15"))
    end

    test "can edit application details", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{
        company_name: "Original Corp",
        position_title: "Original Title"
      })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(link("Edit"))
      |> fill_in(css("input[name='job_application[company_name]']"), with: "Updated Corp")
      |> fill_in(css("input[name='job_application[position_title]']"), with: "Updated Title")
      |> click(button("Save Application"))
      |> assert_has(css("h1", text: "Updated Title"))
      |> assert_has(css("h2", text: "Updated Corp"))
    end

    test "can delete application", %{session: session} do
      user = create_user_and_login(session)
      application = create_job_application(user.id, %{
        position_title: "Delete Me"
      })

      session
      |> visit("/dashboard/applications/#{application.id}")
      |> click(button("Delete Application"))
      |> accept_confirm()
      |> assert_has(css("h1", text: "Applications"))
      |> refute_has(css("h3", text: "Delete Me"))
    end

    test "can navigate from list to detail view", %{session: session} do
      user = create_user_and_login(session)
      create_job_application(user.id, %{
        company_name: "Nav Corp",
        position_title: "Nav Engineer"
      })

      session
      |> visit("/dashboard/applications")
      |> assert_has(css("h3", text: "Nav Engineer"))
      |> click(css("div[phx-click='select_application']"))
      |> assert_has(css("h1", text: "Nav Engineer"))
      |> assert_has(css("h2", text: "Nav Corp"))
    end
  end

  describe "application list and filtering" do
    test "shows all applications in list view", %{session: session} do
      user = create_user_and_login(session)
      create_job_application(user.id, %{position_title: "App 1"})
      create_job_application(user.id, %{position_title: "App 2"})
      create_job_application(user.id, %{position_title: "App 3"})

      session
      |> visit("/dashboard/applications")
      |> assert_has(css("h3", text: "App 1"))
      |> assert_has(css("h3", text: "App 2"))
      |> assert_has(css("h3", text: "App 3"))
    end

    test "can filter by status", %{session: session} do
      user = create_user_and_login(session)
      create_job_application(user.id, %{status: "applied", position_title: "Applied Job"})
      create_job_application(user.id, %{status: "interviewing", position_title: "Interview Job"})
      create_job_application(user.id, %{status: "offered", position_title: "Offered Job"})

      session
      |> visit("/dashboard/applications")
      |> select(css("select[name='status_filter']"), option: "interviewing")
      |> assert_has(css("h3", text: "Interview Job"))
      |> refute_has(css("h3", text: "Applied Job"))
      |> refute_has(css("h3", text: "Offered Job"))
    end

    test "can search applications by company name", %{session: session} do
      user = create_user_and_login(session)
      create_job_application(user.id, %{company_name: "Apple", position_title: "iOS Dev"})
      create_job_application(user.id, %{company_name: "Google", position_title: "Android Dev"})

      session
      |> visit("/dashboard/applications")
      |> fill_in(css("input[name='search']"), with: "Apple")
      |> assert_has(css("h3", text: "iOS Dev"))
      |> refute_has(css("h3", text: "Android Dev"))
    end

    test "can search applications by position title", %{session: session} do
      user = create_user_and_login(session)
      create_job_application(user.id, %{position_title: "Frontend Engineer"})
      create_job_application(user.id, %{position_title: "Backend Engineer"})

      session
      |> visit("/dashboard/applications")
      |> fill_in(css("input[name='search']"), with: "Frontend")
      |> assert_has(css("h3", text: "Frontend Engineer"))
      |> refute_has(css("h3", text: "Backend Engineer"))
    end

    test "shows no applications message when list is empty", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/applications")
      |> assert_has(css("p", text: "No applications found"))
    end
  end

  describe "complete application workflow" do
    test "full lifecycle: interest -> apply -> interview -> offer -> accept", %{session: session} do
      user = create_user_and_login(session)

      # Create interest
      interest = create_job_interest(user.id, %{
        company_name: "Dream Corp",
        position_title: "Dream Job"
      })

      # Convert to application
      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> click(link("Apply for Job"))
      |> fill_in(css("input[name='job_application[application_date]']"), with: "2024-01-15")
      |> click(button("Create Application"))

      # Add phone screen event
      session
      |> click(button("Add Activity"))
      |> select(css("select[name='event_type']"), option: "phone_screen")
      |> fill_in(css("input[name='event_date']"), with: "2024-01-20")
      |> click(button("Save Activity"))

      # Update to interviewing
      session
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "interviewing")
      |> click(button("Save"))

      # Add interview event
      session
      |> click(button("Add Activity"))
      |> select(css("select[name='event_type']"), option: "interview_onsite")
      |> fill_in(css("input[name='event_date']"), with: "2024-01-25")
      |> click(button("Save Activity"))

      # Update to offered
      session
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "offered")
      |> click(button("Save"))

      # Add offer event
      session
      |> click(button("Add Activity"))
      |> select(css("select[name='event_type']"), option: "offer")
      |> fill_in(css("input[name='event_date']"), with: "2024-02-01")
      |> click(button("Save Activity"))

      # Accept offer
      session
      |> click(button("Update Status"))
      |> select(css("select[name='status']"), option: "accepted")
      |> click(button("Save"))
      |> assert_has(css("span.status-badge", text: "accepted"))
      |> assert_has(css(".timeline-event", text: "Phone Screen"))
      |> assert_has(css(".timeline-event", text: "Onsite Interview"))
      |> assert_has(css(".timeline-event", text: "Offer"))
    end
  end
end
