defmodule ClientatsWeb.JobApplicationLive.ConversionWizardTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Clientats.Jobs
  alias Clientats.Documents

  describe "conversion wizard mounting" do
    test "mounts with valid interest_id and displays step 1", %{conn: conn} do
      user = user_fixture()

      interest =
        job_interest_fixture(
          user_id: user.id,
          company_name: "Tech Corp",
          position_title: "Senior Engineer",
          location: "San Francisco"
        )

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Check title and progress bar
      assert html =~ "Convert Interest to Application"
      assert html =~ "Job Details"
      assert html =~ "Resume"
      assert html =~ "Cover Letter"
      assert html =~ "Review"

      # Check step 1 content
      assert html =~ "Step 1: Review Application Details"
      assert html =~ "Tech Corp"
      assert html =~ "Senior Engineer"
      assert html =~ "San Francisco"
    end

    test "requires authentication", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)

      {:error, redirect} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "raises if interest not found", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/dashboard/applications/convert/99999")
      end
    end
  end

  describe "step navigation" do
    test "navigates forward through all steps", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Step 1 initially
      assert html =~ "Step 1"

      # Go to step 2
      html = lv |> element("button", "Next →") |> render_click()
      assert html =~ "Step 2: Select Resume"

      # Go to step 3
      html = lv |> element("button", "Next →") |> render_click()
      assert html =~ "Step 3: Cover Letter"

      # Go to step 4
      html = lv |> element("button", "Next →") |> render_click()
      assert html =~ "Step 4: Review &amp; Finalize"
    end

    test "navigates backward through steps", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Navigate to step 4
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()

      # Navigate back
      html = lv |> element("button", "← Previous") |> render_click()
      assert html =~ "Step 3"

      html = lv |> element("button", "← Previous") |> render_click()
      assert html =~ "Step 2"

      html = lv |> element("button", "← Previous") |> render_click()
      assert html =~ "Step 1"
    end

    test "shows cancel button linking back to interest", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      assert has_element?(lv, "a[href='/dashboard/job-interests/#{interest.id}']", "Cancel")
    end
  end

  describe "step 1: application details" do
    test "displays pre-filled form from interest", %{conn: conn} do
      user = user_fixture()

      interest =
        job_interest_fixture(
          user_id: user.id,
          company_name: "Test Company",
          position_title: "Test Position",
          location: "Test Location",
          work_model: "remote"
        )

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      assert html =~ "Test Company"
      assert html =~ "Test Position"
      assert html =~ "Test Location"
    end
  end

  describe "step 2: resume selection" do
    test "displays list of user resumes", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)

      _resume1 = resume_fixture(user_id: user.id, name: "Resume 2024", is_default: true)
      _resume2 = resume_fixture(user_id: user.id, name: "Technical Resume")

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")
      html = lv |> element("button", "Next →") |> render_click()

      assert html =~ "Step 2: Select Resume"
      assert html =~ "Resume 2024"
      assert html =~ "Technical Resume"
      assert html =~ "Default Resume"
    end

    test "shows message when no resumes available", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")
      html = lv |> element("button", "Next →") |> render_click()

      assert html =~ "don&#39;t have any resumes"
      assert html =~ "Upload a resume"
    end

    test "selects resume on click", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      resume = resume_fixture(user_id: user.id, name: "My Resume")

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")
      lv |> element("button", "Next →") |> render_click()

      html =
        lv
        |> element("[phx-click='select_resume'][phx-value-id='#{resume.id}']")
        |> render_click()

      assert html =~ "Selected Resume"
      assert html =~ "My Resume"
    end
  end

  describe "step 3: cover letter" do
    test "displays cover letter editor", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")
      lv |> element("button", "Next →") |> render_click()
      html = lv |> element("button", "Next →") |> render_click()

      assert html =~ "Step 3: Cover Letter"
      assert html =~ "Generate with AI"
      assert html =~ "Cover Letter Content"
    end

    test "allows text entry in cover letter", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()

      # Type in cover letter using phx-change event
      html =
        lv
        |> element("textarea[name='cover_letter_content']")
        |> render_change(%{"cover_letter_content" => "Test cover letter content"})

      # Should accept the content (no error shown)
      refute html =~ "error"
    end
  end

  describe "step 4: review and finalize" do
    test "displays review summary", %{conn: conn} do
      user = user_fixture()

      interest =
        job_interest_fixture(
          user_id: user.id,
          company_name: "Review Corp",
          position_title: "Engineer"
        )

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Navigate to step 4
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      html = lv |> element("button", "Next →") |> render_click()

      # Verify review content
      assert html =~ "Step 4: Review &amp; Finalize"
      assert html =~ "Job Details"
      assert html =~ "Review Corp"
      assert html =~ "Engineer"
      assert html =~ "Create Application"
    end

    test "shows no resume selected message", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Navigate to step 4
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      html = lv |> element("button", "Next →") |> render_click()

      assert html =~ "No resume selected"
    end
  end

  describe "finalization" do
    test "creates application and deletes interest", %{conn: conn} do
      user = user_fixture()

      interest =
        job_interest_fixture(
          user_id: user.id,
          company_name: "Final Corp",
          position_title: "Developer"
        )

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Navigate to final step and create
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Create Application") |> render_click()

      # Verify application was created
      app = Clientats.Repo.get_by(Jobs.JobApplication, company_name: "Final Corp")
      assert app != nil
      assert app.position_title == "Developer"
      assert app.user_id == user.id

      # Verify interest was deleted
      assert_raise Ecto.NoResultsError, fn ->
        Jobs.get_job_interest!(interest.id)
      end
    end

    test "redirects to application show page", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, company_name: "Redirect Test")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Navigate and finalize
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Create Application") |> render_click()

      # Get the created application ID
      app = Clientats.Repo.get_by(Jobs.JobApplication, company_name: "Redirect Test")

      # Check for redirect to the application show page
      assert_redirect(lv, "/dashboard/applications/#{app.id}")
    end

    test "includes resume when selected", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, company_name: "Resume Test")

      # Create a temporary test file
      test_file_path = "/tmp/test_resume_#{System.unique_integer([:positive])}.pdf"
      File.write!(test_file_path, "test content")

      resume = resume_fixture(user_id: user.id, file_path: test_file_path)

      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/convert/#{interest.id}")

      # Select resume and finalize
      lv |> element("button", "Next →") |> render_click()
      lv |> element("[phx-click='select_resume'][phx-value-id='#{resume.id}']") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Next →") |> render_click()
      lv |> element("button", "Create Application") |> render_click()

      # Verify resume path saved
      app = Clientats.Repo.get_by(Jobs.JobApplication, company_name: "Resume Test")
      assert app.resume_path == test_file_path

      # Cleanup
      File.rm(test_file_path)
    end
  end

  # Helper functions

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

  defp job_interest_fixture(attrs) do
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

  defp resume_fixture(attrs) do
    default_attrs = %{
      name: "Default Resume",
      is_default: false,
      file_path: "/tmp/test_resume.pdf",
      original_filename: "test_resume.pdf"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, resume} = Documents.create_resume(attrs)
    resume
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
