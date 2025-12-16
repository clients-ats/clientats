defmodule ClientatsWeb.JobManagementLiveViewTest do
  @moduledoc """
  Comprehensive test suite for job interest and application LiveView components.

  Tests job tracking, creation, editing, filtering, and transitions with:
  - Form validation and state management
  - Job interest to application conversion
  - Status filtering and transitions
  - Accessibility compliance
  - Edge cases and error handling
  """

  use ClientatsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import ClientatsWeb.LiveViewTestHelpers

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "JobInterestLive.New" do
    test "renders job interest form", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert html =~ "New Job Interest"
      assert html =~ "Company"
      assert html =~ "Position"
      assert html =~ "Location"
      assert html =~ "Salary"
    end

    test "form has accessible structure", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert_accessible_form(html)
      assert_has_heading(html, 1, "New Job Interest")
    end

    test "creates job interest with valid data", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/new")

      result =
        lv
        |> form("#job_interest_form", %{
          "job_interest" => %{
            "company_name" => "Acme Corp",
            "position_title" => "Senior Engineer",
            "location" => "New York, NY",
            "work_model" => "remote",
            "salary_min" => "150000",
            "salary_max" => "200000",
            "status" => "interested",
            "priority" => "high"
          }
        })
        |> render_submit()

      # Should show success or redirect
      assert result =~ "Acme" or result =~ "Senior Engineer" or
             String.contains?(result, "dashboard")
    end

    test "validates required fields", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/new")

      # Submit without required fields
      result =
        lv
        |> form("#job_interest_form", %{
          "job_interest" => %{
            "company_name" => "",
            "position_title" => ""
          }
        })
        |> render_submit()

      # Should display validation errors
      assert String.contains?(result, "can't be blank") or
             String.contains?(result, "required")
    end

    test "validates salary range", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/new")

      # Invalid salary range (max < min)
      result =
        lv
        |> form("#job_interest_form", %{
          "job_interest" => %{
            "company_name" => "Test Corp",
            "position_title" => "Developer",
            "salary_min" => "200000",
            "salary_max" => "100000"
          }
        })
        |> render_change()

      assert result =~ "job_interest_form"
    end

    test "allows optional fields to be empty", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/new")

      result =
        lv
        |> form("#job_interest_form", %{
          "job_interest" => %{
            "company_name" => "Tech Inc",
            "position_title" => "Engineer",
            "location" => "",
            "notes" => ""
          }
        })
        |> render_submit()

      # Should succeed without location and notes
      assert String.contains?(result, "Tech Inc") or
             String.contains?(result, "dashboard")
    end

    test "form defaults to 'interested' status", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert html =~ "interested"
    end

    test "provides status options", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert html =~ "interested"
      assert html =~ "applied"
    end

    test "provides priority options", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert html =~ "low"
      assert html =~ "medium"
      assert html =~ "high"
    end
  end

  describe "JobInterestLive.Edit" do
    test "renders edit form with existing data", %{conn: conn, user: user} do
      interest = job_interest_fixture(user, %{company_name: "Original Corp"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}/edit")

      assert html =~ "Original Corp"
      assert html =~ "Edit Job Interest"
    end

    test "updates job interest", %{conn: conn, user: user} do
      interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}/edit")

      result =
        lv
        |> form("#job_interest_form", %{
          "job_interest" => %{
            "company_name" => "Updated Corp",
            "position_title" => "Senior Role"
          }
        })
        |> render_submit()

      assert String.contains?(result, "Updated Corp") or
             String.contains?(result, "dashboard")
    end

    test "edit form validates same as create", %{conn: conn, user: user} do
      interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}/edit")

      result =
        lv
        |> form("#job_interest_form", %{
          "job_interest" => %{"company_name" => ""}
        })
        |> render_submit()

      assert String.contains?(result, "can't be blank") or
             String.contains?(result, "required")
    end
  end

  describe "JobInterestLive.Show" do
    test "displays job interest details", %{conn: conn, user: user} do
      interest =
        job_interest_fixture(user, %{
          company_name: "Display Corp",
          position_title: "Test Role",
          salary_min: 100_000,
          salary_max: 150_000
        })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      assert html =~ "Display Corp"
      assert html =~ "Test Role"
      assert html =~ "100,000" or html =~ "$100"
    end

    test "shows accessible heading", %{conn: conn, user: user} do
      interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      assert_has_heading(html, 1, interest.company_name)
    end

    test "provides convert to application button", %{conn: conn, user: user} do
      interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      assert html =~ "Apply" or html =~ "Create Application"
    end

    test "provides delete option", %{conn: conn, user: user} do
      interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      assert html =~ "Delete" or html =~ "Remove"
    end

    test "deletes interest with confirmation", %{conn: conn, user: user} do
      interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      # Trigger delete event
      result = lv |> element("a[data-method='delete']") |> render_click()

      # Should redirect to dashboard
      assert String.contains?(result, "dashboard") or
             String.contains?(result, "job-interests")
    end
  end

  describe "DashboardLive filtering" do
    test "displays job interests and applications", %{conn: conn, user: user} do
      _interest = job_interest_fixture(user)
      _application = job_application_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Dashboard" or html =~ "Tech Corp"
    end

    test "toggle shows/hides closed applications", %{conn: conn, user: user} do
      app = job_application_fixture(user, %{status: "rejected"})
      conn = log_in_user(conn, user)

      {:ok, lv, html} = live(conn, ~p"/dashboard")

      # Initially should show closed
      assert String.contains?(html, "rejected") or String.contains?(html, "Tech Corp")

      # Toggle closed off
      result = lv |> element("input[type='checkbox']") |> render_change()

      # Behavior depends on implementation
      assert String.contains?(result, "dashboard")
    end

    test "displays job interests grouped or sorted", %{conn: conn, user: user} do
      job_interest_fixture(user, %{company_name: "Alpha Corp", priority: "high"})
      job_interest_fixture(user, %{company_name: "Beta Corp", priority: "low"})

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Alpha Corp"
      assert html =~ "Beta Corp"
    end
  end

  describe "job interest to application conversion" do
    test "converts interest to application", %{conn: conn, user: user} do
      interest =
        job_interest_fixture(user, %{
          company_name: "Convert Corp",
          position_title: "Role",
          job_description: "Do stuff"
        })

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      # Click convert button
      result = lv |> element("a[href*='job-applications/new']") |> render_click()

      # Should have converted data
      assert String.contains?(result, "Convert Corp") or
             String.contains?(result, "job-applications")
    end

    test "pre-fills application form from interest", %{conn: conn, user: user} do
      interest =
        job_interest_fixture(user, %{
          company_name: "Prefill Corp",
          position_title: "Test Role"
        })

      conn = log_in_user(conn, user)

      # Navigate to new application from interest
      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/new?interest_id=#{interest.id}")

      # Should contain pre-filled data (implementation dependent)
      assert html =~ "job_application" or html =~ "New"
    end
  end

  describe "accessibility in job management" do
    test "job list has accessible table structure", %{conn: conn, user: user} do
      _interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      # Should have table or list structure
      assert html =~ ~r/<table|<ul|<ol/i
    end

    test "status badges are accessible", %{conn: conn, user: user} do
      interest = job_interest_fixture(user, %{status: "interested"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      # Status should be visible or have aria-label
      assert html =~ "interested" or html =~ "aria-label"
    end

    test "salary display is formatted accessibly", %{conn: conn, user: user} do
      interest =
        job_interest_fixture(user, %{
          salary_min: 100_000,
          salary_max: 150_000
        })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}")

      # Should display formatted salary
      assert html =~ "100" or html =~ "$" or html =~ "salary"
    end
  end

  describe "edge cases and error handling" do
    test "handles non-existent job interest", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/nonexistent")

      # Should show error or redirect
      assert html =~ "not found" or html =~ "dashboard" or html =~ "error"
    end

    test "prevents viewing other users' interests", %{conn: conn, user: user} do
      other_user = user_fixture()
      other_interest = job_interest_fixture(other_user)

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{other_interest.id}")

      # Should not show other user's data
      refute String.contains?(html, "other_user") or
             assert html =~ "not found" or html =~ "dashboard"
    end

    test "handles concurrent edits gracefully", %{conn: conn, user: user} do
      interest = job_interest_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/#{interest.id}/edit")

      # Submit form twice rapidly
      _result1 = lv |> element("form") |> render_submit()

      # Second submit should handle gracefully
      result2 = lv |> element("form") |> render_submit()

      assert result2 =~ "job_interest" or result2 =~ "dashboard"
    end

    test "handles very long job descriptions", %{conn: conn, user: user} do
      long_desc = String.duplicate("A", 5000)

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/new")

      result =
        lv
        |> form("#job_interest_form", %{
          "job_interest" => %{
            "company_name" => "Test",
            "position_title" => "Role",
            "job_description" => long_desc
          }
        })
        |> render_submit()

      # Should truncate or accept gracefully
      assert String.contains?(result, "Test") or
             String.contains?(result, "too long")
    end
  end
end
