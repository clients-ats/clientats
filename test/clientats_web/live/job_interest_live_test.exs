defmodule ClientatsWeb.JobInterestLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "new job interest" do
    test "renders new job interest form", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert html =~ "New Job Interest"
      assert html =~ "Company Name"
      assert html =~ "Position Title"
    end

    test "redirects if not authenticated", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/dashboard/job-interests/new")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "creates job interest with valid data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/new")

      lv
      |> form("#job-interest-form",
        job_interest: %{
          company_name: "Tech Corp",
          position_title: "Software Engineer",
          job_url: "https://example.com/job",
          status: "interested",
          priority: "high"
        }
      )
      |> render_submit()

      interest = Clientats.Repo.get_by(Clientats.Jobs.JobInterest, company_name: "Tech Corp")
      assert interest != nil
      assert interest.position_title == "Software Engineer"
    end

    test "validates required fields", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/new")

      result =
        lv
        |> form("#job-interest-form",
          job_interest: %{
            company_name: "",
            position_title: ""
          }
        )
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "edit job interest" do
    test "renders edit form", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, company_name: "Tech Corp")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}/edit")

      assert html =~ "Edit Job Interest"
      assert html =~ "Tech Corp"
    end

    test "updates job interest with valid data", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/#{interest}/edit")

      lv
      |> form("#job-interest-form",
        job_interest: %{
          company_name: "Updated Corp",
          status: "ready_to_apply"
        }
      )
      |> render_submit()

      updated = Clientats.Jobs.get_job_interest!(interest.id)
      assert updated.company_name == "Updated Corp"
      assert updated.status == "ready_to_apply"
    end
  end

  describe "show job interest" do
    test "displays job interest details", %{conn: conn} do
      user = user_fixture()

      interest =
        job_interest_fixture(
          user_id: user.id,
          company_name: "Tech Corp",
          position_title: "Software Engineer",
          location: "Remote"
        )

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Tech Corp"
      assert html =~ "Software Engineer"
      assert html =~ "Remote"
    end

    test "redirects if not authenticated", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)

      {:error, redirect} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "displays work model", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, work_model: "hybrid")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Hybrid"
    end

    test "displays salary range", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, salary_min: 100000, salary_max: 150000)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "100,000"
      assert html =~ "150,000"
    end

    test "displays job URL link", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, job_url: "https://careers.example.com/job")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "View Posting"
      assert html =~ "https://careers.example.com/job"
    end

    test "displays status and priority", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, status: "ready_to_apply", priority: "high")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Ready To Apply"
      assert html =~ "High"
    end

    test "displays job description", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, job_description: "Exciting opportunity")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Exciting opportunity"
    end

    test "displays notes", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id, notes: "Must follow up by Friday")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Must follow up by Friday"
    end

    test "shows apply for job button", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Apply for Job"
    end

    test "shows edit link", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Edit"
    end

    test "shows back to dashboard link", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      assert html =~ "Back to Dashboard"
    end

    test "deletes job interest", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/job-interests/#{interest}")

      lv
      |> element("button", "Delete")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn ->
        Clientats.Jobs.get_job_interest!(interest.id)
      end
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

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
