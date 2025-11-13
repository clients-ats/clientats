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

    test "displays applications", %{conn: conn} do
      user = user_fixture()
      _app = job_application_fixture(user_id: user.id, company_name: "Tech Corp")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/applications")

      assert html =~ "Tech Corp"
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
