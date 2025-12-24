defmodule ClientatsWeb.JobApplicationLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "new job application" do
    test "renders new application form", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/new")

      assert html =~ "New Job Application"
      assert html =~ "Company Name"
      assert html =~ "Application Date"
    end

    test "pre-fills from job interest", %{conn: conn} do
      user = user_fixture()

      interest =
        job_interest_fixture(
          user_id: user.id,
          company_name: "Tech Corp",
          position_title: "Senior Engineer"
        )

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/new?from_interest=#{interest.id}")

      assert html =~ "Tech Corp"
      assert html =~ "Senior Engineer"
      assert html =~ "Converting job interest to application"
    end

    test "creates application and deletes job interest", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, company_name: "Tech Corp")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/new?from_interest=#{interest.id}")

      lv
      |> form("#application-form",
        job_application: %{
          company_name: "Tech Corp",
          position_title: "Engineer",
          application_date: "2024-01-15"
        }
      )
      |> render_submit()

      app = Clientats.Repo.get_by(Clientats.Jobs.JobApplication, company_name: "Tech Corp")
      assert app != nil

      assert_raise Ecto.NoResultsError, fn ->
        Clientats.Jobs.get_job_interest!(interest.id)
      end
    end

    test "validates required fields", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/new")

      result =
        lv
        |> form("#application-form",
          job_application: %{
            company_name: "",
            position_title: "",
            application_date: ""
          }
        )
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "show job application" do
    test "displays application details", %{conn: conn} do
      user = user_fixture()

      app =
        job_application_fixture(
          user_id: user.id,
          company_name: "Tech Corp",
          position_title: "Software Engineer"
        )

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Tech Corp"
      assert html =~ "Software Engineer"
    end

    test "redirects if not authenticated", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)

      {:error, redirect} = live(conn, ~p"/dashboard/applications/#{app}")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "displays optional location", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, location: "New York")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "New York"
    end

    test "displays work model", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, work_model: "remote")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Remote"
    end

    test "displays job URL link", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, job_url: "https://example.com/job")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "View Posting"
      assert html =~ "https://example.com/job"
    end

    test "displays salary range", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, salary_min: 80000, salary_max: 120_000)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "80,000"
      assert html =~ "120,000"
    end

    test "displays job description", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, job_description: "Great opportunity")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Great opportunity"
    end

    test "displays notes", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, notes: "Follow up next week")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Follow up next week"
    end

    test "displays resume link when present", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, resume_path: "/uploads/resume.pdf")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "View Resume"
      assert html =~ "/uploads/resume.pdf"
    end

    test "shows 'Not specified' when resume not present", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, resume_path: nil)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Not specified"
    end

    test "shows link to related job interest when present", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      app = job_application_fixture(user_id: user.id, job_interest_id: interest.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "View related job interest"
    end

    test "shows convert to interest button", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications/#{app}")

      assert html =~ "Convert to Interest"
    end

    test "converts application back to job interest", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id, company_name: "Tech Corp")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      lv
      |> element("button", "Convert to Interest")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn ->
        Clientats.Jobs.get_job_application!(app.id)
      end

      interest = Clientats.Repo.get_by(Clientats.Jobs.JobInterest, company_name: "Tech Corp")
      assert interest != nil
    end

    test "can edit cover letter", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      # Open editor
      lv
      |> element("#edit-cover-letter-btn")
      |> render_click()

      assert has_element?(lv, "#cover-letter-editor")
      assert has_element?(lv, "h3", "Edit Cover Letter")

      # Save content
      lv
      |> form("#cover-letter-form", job_application: %{cover_letter_content: "My new cover letter"})
      |> render_submit()

      assert render(lv) =~ "My new cover letter"
      assert render(lv) =~ "Cover letter updated successfully"
      refute has_element?(lv, "#cover-letter-editor")

      # Verify persistence
      updated_app = Clientats.Jobs.get_job_application!(app.id)
      assert updated_app.cover_letter_content == "My new cover letter"
    end

    test "deletes application", %{conn: conn} do
      user = user_fixture()
      app = job_application_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/applications/#{app}")

      lv
      |> element("button", "Delete")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn ->
        Clientats.Jobs.get_job_application!(app.id)
      end
    end
  end

  describe "applications index" do
    test "renders applications list", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "My Job Applications"
    end

    test "redirects if not authenticated", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/dashboard/applications")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "displays applications", %{conn: conn} do
      user = user_fixture()
      _app = job_application_fixture(user_id: user.id, company_name: "Tech Corp")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "Tech Corp"
    end

    test "shows empty state when no applications", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "No applications yet"
      assert html =~ "Record Your First Application"
    end

    test "displays multiple applications", %{conn: conn} do
      user = user_fixture()
      job_application_fixture(user_id: user.id, company_name: "Company A")
      job_application_fixture(user_id: user.id, company_name: "Company B")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "Company A"
      assert html =~ "Company B"
    end

    test "displays application with location", %{conn: conn} do
      user = user_fixture()
      job_application_fixture(user_id: user.id, location: "San Francisco")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "San Francisco"
    end

    test "displays application date", %{conn: conn} do
      user = user_fixture()
      application_date = ~D[2024-03-15]
      job_application_fixture(user_id: user.id, application_date: application_date)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "Mar 15, 2024"
    end

    test "displays status badge", %{conn: conn} do
      user = user_fixture()
      job_application_fixture(user_id: user.id, status: "interviewed")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "Interviewed"
    end

    test "shows 'From Interest' badge for applications from interests", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      job_application_fixture(user_id: user.id, job_interest_id: interest.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "From Interest"
    end

    test "shows links to new application and back to dashboard", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "New Application"
      assert html =~ "Back to Dashboard"
    end

    test "only shows current user's applications", %{conn: conn} do
      user1 = user_fixture()
      user2 = user_fixture()
      job_application_fixture(user_id: user1.id, company_name: "My Company")
      job_application_fixture(user_id: user2.id, company_name: "Other Company")
      conn = log_in_user(conn, user1)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "My Company"
      refute html =~ "Other Company"
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

  defp job_interest_fixture(attrs) do
    default_attrs = %{
      company_name: "Default Corp",
      position_title: "Software Engineer",
      status: "interested",
      priority: "medium"
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, interest} = Clientats.Jobs.create_job_interest(attrs)
    interest
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

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
