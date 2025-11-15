defmodule ClientatsWeb.DashboardLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "dashboard page" do
    test "redirects to login if not authenticated", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/dashboard")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "renders dashboard when authenticated", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Clientats Dashboard"
      assert html =~ user.first_name
      assert html =~ user.last_name
    end

    test "displays user name in header", %{conn: conn} do
      user = user_fixture(first_name: "John", last_name: "Doe")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "John Doe"
    end

    test "shows logout link", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Logout"
    end

    test "displays job interests section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Job Interests"
      assert html =~ "Add Interest"
    end

    test "displays applications section", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Applications"
      assert html =~ "Add Application"
    end

    test "shows placeholder when no data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "No job interests yet"
      assert html =~ "No applications yet"
    end

    test "displays job interests when they exist", %{conn: conn} do
      user = user_fixture()
      job_interest_fixture(user_id: user.id, company_name: "Tech Corp", position_title: "Software Engineer")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Tech Corp"
      assert html =~ "Software Engineer"
      refute html =~ "No job interests yet"
    end

    test "displays multiple job interests", %{conn: conn} do
      user = user_fixture()
      job_interest_fixture(user_id: user.id, company_name: "Company A", position_title: "Developer")
      job_interest_fixture(user_id: user.id, company_name: "Company B", position_title: "Engineer")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Company A"
      assert html =~ "Company B"
      assert html =~ "Developer"
      assert html =~ "Engineer"
    end

    test "displays job interest with location", %{conn: conn} do
      user = user_fixture()
      job_interest_fixture(user_id: user.id, location: "Remote")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Remote"
    end

    test "displays job interest status and priority badges", %{conn: conn} do
      user = user_fixture()
      job_interest_fixture(user_id: user.id, status: "interested", priority: "high")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Interested"
      assert html =~ "High"
    end

    test "navigates to interest detail when clicked", %{conn: conn} do
      user = user_fixture()
      interest = job_interest_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard")

      lv |> element("div[phx-click='select_interest'][phx-value-id='#{interest.id}']") |> render_click()

      assert_redirect(lv, ~p"/dashboard/job-interests/#{interest.id}")
    end

    test "displays job applications when they exist", %{conn: conn} do
      user = user_fixture()
      job_application_fixture(user_id: user.id, company_name: "App Corp", position_title: "Developer")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "App Corp"
      assert html =~ "Developer"
      refute html =~ "No applications yet"
    end

    test "displays application date", %{conn: conn} do
      user = user_fixture()
      application_date = ~D[2024-01-15]
      job_application_fixture(user_id: user.id, application_date: application_date)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Jan 15, 2024"
    end

    test "displays application status badge", %{conn: conn} do
      user = user_fixture()
      job_application_fixture(user_id: user.id, status: "interviewed")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Interviewed"
    end

    test "shows links to manage resumes and cover letters", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Manage Resumes"
      assert html =~ "Cover Letter Templates"
    end

    test "only shows current user's data", %{conn: conn} do
      user1 = user_fixture()
      user2 = user_fixture()
      job_interest_fixture(user_id: user1.id, company_name: "My Company")
      job_interest_fixture(user_id: user2.id, company_name: "Other Company")
      conn = log_in_user(conn, user1)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

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

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
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
      status: "applied",
      application_date: Date.utc_today()
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, application} = Clientats.Jobs.create_job_application(attrs)
    application
  end
end
