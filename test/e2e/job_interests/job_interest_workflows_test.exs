defmodule ClientatsWeb.E2E.JobInterestWorkflowsTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query
  import ClientatsWeb.E2E.UserFixtures
  import ClientatsWeb.E2E.JobFixtures

  @moduletag :feature

  describe "create job interest" do
    test "successfully creates a new job interest", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> click(link("Add Interest"))
      |> assert_has(css("h2", text: "New Job Interest"))
      |> fill_in(css("input[name='job_interest[company_name]']"), with: "Acme Corporation")
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "Senior Software Engineer")
      |> fill_in(css("input[name='job_interest[job_url]']"), with: "https://acme.com/jobs/123")
      |> click(css("select[name='job_interest[status]'] option[value='interested']"))
      |> click(css("select[name='job_interest[priority]'] option[value='high']"))
      |> click(button("Save Job Interest"))
      |> assert_has(css("h3", text: "Senior Software Engineer"))
      |> assert_has(css("p", text: "Acme Corporation"))
    end

    test "validates required fields when creating", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/job-interests/new")
      |> click(button("Save Job Interest"))
      |> assert_has(css(".phx-form-error", text: "can't be blank"))
    end

    test "creates interest with minimal required fields", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard/job-interests/new")
      |> fill_in(css("input[name='job_interest[company_name]']"), with: "Tech Startup")
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "Developer")
      |> click(button("Save Job Interest"))
      |> assert_has(css("h3", text: "Developer"))
    end

    test "creates multiple job interests", %{session: session} do
      _user = create_user_and_login(session)

      # Create first interest
      session
      |> visit("/dashboard/job-interests/new")
      |> fill_in(css("input[name='job_interest[company_name]']"), with: "Company A")
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "Engineer A")
      |> click(button("Save Job Interest"))
      |> assert_has(css("h3", text: "Engineer A"))

      # Create second interest
      session
      |> visit("/dashboard")
      |> click(link("Add Interest"))
      |> fill_in(css("input[name='job_interest[company_name]']"), with: "Company B")
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "Engineer B")
      |> click(button("Save Job Interest"))
      |> assert_has(css("h3", text: "Engineer B"))
    end
  end

  describe "view job interest" do
    test "displays job interest details", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        company_name: "View Test Corp",
        position_title: "Test Engineer",
        status: "interested",
        priority: "high"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> assert_has(css("h1", text: "Test Engineer"))
      |> assert_has(css("h2", text: "View Test Corp"))
      |> assert_has(css("span", text: "interested"))
      |> assert_has(css("span", text: "high"))
    end

    test "can navigate from dashboard to interest detail", %{session: session} do
      user = create_user_and_login(session)
      _interest = create_job_interest(user.id, %{
        company_name: "Navigation Corp",
        position_title: "Navigation Engineer"
      })

      session
      |> visit("/dashboard")
      |> assert_has(css("h3", text: "Navigation Engineer"))
      |> click(css("div[phx-click='select_interest']"))
      |> assert_has(css("h1", text: "Navigation Engineer"))
      |> assert_has(css("h2", text: "Navigation Corp"))
    end

    test "shows no interests message when list is empty", %{session: session} do
      _user = create_user_and_login(session)

      session
      |> visit("/dashboard")
      |> assert_has(css("p", text: "No job interests found"))
    end
  end

  describe "edit job interest" do
    test "successfully updates job interest", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        company_name: "Original Corp",
        position_title: "Original Title"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> click(link("Edit"))
      |> assert_has(css("h2", text: "Edit Job Interest"))
      |> fill_in(css("input[name='job_interest[company_name]']"), with: "Updated Corp")
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "Updated Title")
      |> click(button("Save Job Interest"))
      |> assert_has(css("h1", text: "Updated Title"))
      |> assert_has(css("h2", text: "Updated Corp"))
    end

    test "can change job interest status", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{status: "interested"})

      session
      |> visit("/dashboard/job-interests/#{interest.id}/edit")
      |> click(css("select[name='job_interest[status]'] option[value='ready_to_apply']"))
      |> click(button("Save Job Interest"))
      |> assert_has(css("span", text: "ready_to_apply"))
    end

    test "can change job interest priority", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{priority: "low"})

      session
      |> visit("/dashboard/job-interests/#{interest.id}/edit")
      |> click(css("select[name='job_interest[priority]'] option[value='high']"))
      |> click(button("Save Job Interest"))
      |> assert_has(css("span", text: "high"))
    end

    test "validates required fields when editing", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id)

      session
      |> visit("/dashboard/job-interests/#{interest.id}/edit")
      |> fill_in(css("input[name='job_interest[company_name]']"), with: "")
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "")
      |> click(button("Save Job Interest"))
      |> assert_has(css(".phx-form-error", text: "can't be blank"))
    end

    test "can cancel editing and return to detail view", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        company_name: "Cancel Test Corp",
        position_title: "Cancel Test"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}/edit")
      |> click(link("Cancel"))
      |> assert_has(css("h1", text: "Cancel Test"))
      |> assert_has(css("h2", text: "Cancel Test Corp"))
    end
  end

  describe "delete job interest" do
    test "successfully deletes a job interest", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        company_name: "Delete Corp",
        position_title: "Delete Test"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> click(button("Delete Interest"))
      |> assert_has(css("h1", text: "Clientats Dashboard"))
      |> refute_has(css("h3", text: "Delete Test"))
    end

    test "can delete multiple interests", %{session: session} do
      user = create_user_and_login(session)
      interest1 = create_job_interest(user.id, %{position_title: "Delete 1"})
      interest2 = create_job_interest(user.id, %{position_title: "Delete 2"})

      session
      |> visit("/dashboard/job-interests/#{interest1.id}")
      |> click(button("Delete Interest"))
      |> assert_has(css("h3", text: "Delete 2"))
      |> click(css("div[phx-click='select_interest']"))
      |> click(button("Delete Interest"))
      |> assert_has(css("p", text: "No job interests found"))
    end
  end

  describe "search and filter" do
    test "can search for job interests by company name", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{company_name: "Apple", position_title: "iOS Developer"})
      create_job_interest(user.id, %{company_name: "Google", position_title: "Android Developer"})

      session
      |> visit("/dashboard")
      |> fill_in(css("input[name='search']"), with: "Apple")
      |> assert_has(css("h3", text: "iOS Developer"))
      |> refute_has(css("h3", text: "Android Developer"))
    end

    test "can search for job interests by position title", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{company_name: "TechCo", position_title: "Frontend Engineer"})
      create_job_interest(user.id, %{company_name: "DevCo", position_title: "Backend Engineer"})

      session
      |> visit("/dashboard")
      |> fill_in(css("input[name='search']"), with: "Frontend")
      |> assert_has(css("h3", text: "Frontend Engineer"))
      |> refute_has(css("h3", text: "Backend Engineer"))
    end

    test "can filter by status", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{status: "interested", position_title: "Interested Job"})
      create_job_interest(user.id, %{status: "ready_to_apply", position_title: "Ready Job"})

      session
      |> visit("/dashboard")
      |> click(css("select[name='status_filter'] option[value='interested']"))
      |> assert_has(css("h3", text: "Interested Job"))
      |> refute_has(css("h3", text: "Ready Job"))
    end

    test "can filter by priority", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{priority: "high", position_title: "High Priority Job"})
      create_job_interest(user.id, %{priority: "low", position_title: "Low Priority Job"})

      session
      |> visit("/dashboard")
      |> click(css("select[name='priority_filter'] option[value='high']"))
      |> assert_has(css("h3", text: "High Priority Job"))
      |> refute_has(css("h3", text: "Low Priority Job"))
    end

    test "shows all interests when search is cleared", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{position_title: "Job A"})
      create_job_interest(user.id, %{position_title: "Job B"})

      session
      |> visit("/dashboard")
      |> fill_in(css("input[name='search']"), with: "Job A")
      |> assert_has(css("h3", text: "Job A"))
      |> refute_has(css("h3", text: "Job B"))
      |> fill_in(css("input[name='search']"), with: "")
      |> assert_has(css("h3", text: "Job A"))
      |> assert_has(css("h3", text: "Job B"))
    end
  end

  describe "sorting" do
    test "can sort by date created", %{session: session} do
      user = create_user_and_login(session)
      # Create in specific order
      create_job_interest(user.id, %{position_title: "Oldest Job"})
      :timer.sleep(100)
      create_job_interest(user.id, %{position_title: "Newest Job"})

      session
      |> visit("/dashboard")
      |> click(css("select[name='sort'] option[value='date_created']"))
      # Should show newest first by default
      |> assert_has(css("div.job-interest:first-child h3", text: "Newest Job"))
    end

    test "can sort by priority", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{priority: "low", position_title: "Low Priority"})
      create_job_interest(user.id, %{priority: "high", position_title: "High Priority"})

      session
      |> visit("/dashboard")
      |> click(css("select[name='sort'] option[value='priority']"))
      # Should show high priority first
      |> assert_has(css("div.job-interest:first-child h3", text: "High Priority"))
    end

    test "can sort by company name alphabetically", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{company_name: "Zebra Corp", position_title: "Z Job"})
      create_job_interest(user.id, %{company_name: "Apple Inc", position_title: "A Job"})

      session
      |> visit("/dashboard")
      |> click(css("select[name='sort'] option[value='company']"))
      # Should show Apple first
      |> assert_has(css("div.job-interest:first-child h3", text: "A Job"))
    end
  end

  describe "status workflow" do
    test "can change status from interested to ready_to_apply", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        status: "interested",
        position_title: "Status Test"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> assert_has(css("span", text: "interested"))
      |> click(button("Mark Ready to Apply"))
      |> assert_has(css("span", text: "ready_to_apply"))
    end

    test "can change status from ready_to_apply to not_interested", %{session: session} do
      user = create_user_and_login(session)
      interest = create_job_interest(user.id, %{
        status: "ready_to_apply",
        position_title: "Status Change Test"
      })

      session
      |> visit("/dashboard/job-interests/#{interest.id}")
      |> assert_has(css("span", text: "ready_to_apply"))
      |> click(button("Mark Not Interested"))
      |> assert_has(css("span", text: "not_interested"))
    end

    test "displays different status badges correctly", %{session: session} do
      user = create_user_and_login(session)
      create_job_interest(user.id, %{status: "interested", position_title: "Interested"})
      create_job_interest(user.id, %{status: "ready_to_apply", position_title: "Ready"})
      create_job_interest(user.id, %{status: "not_interested", position_title: "Not Interested"})

      session
      |> visit("/dashboard")
      |> assert_has(css("span.status-interested"))
      |> assert_has(css("span.status-ready_to_apply"))
      |> assert_has(css("span.status-not_interested"))
    end
  end

  describe "complete workflow" do
    test "full job interest lifecycle: create -> view -> edit -> delete", %{session: session} do
      _user = create_user_and_login(session)

      # Create
      session
      |> visit("/dashboard")
      |> click(link("Add Interest"))
      |> fill_in(css("input[name='job_interest[company_name]']"), with: "Lifecycle Corp")
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "Lifecycle Test")
      |> click(button("Save Job Interest"))

      # View
      session
      |> assert_has(css("h3", text: "Lifecycle Test"))
      |> click(css("div[phx-click='select_interest']"))
      |> assert_has(css("h1", text: "Lifecycle Test"))
      |> assert_has(css("h2", text: "Lifecycle Corp"))

      # Edit
      session
      |> click(link("Edit"))
      |> fill_in(css("input[name='job_interest[position_title]']"), with: "Updated Lifecycle")
      |> click(button("Save Job Interest"))
      |> assert_has(css("h1", text: "Updated Lifecycle"))

      # Delete
      session
      |> click(button("Delete Interest"))
      |> assert_has(css("h1", text: "Clientats Dashboard"))
      |> refute_has(css("h3", text: "Updated Lifecycle"))
    end
  end
end
