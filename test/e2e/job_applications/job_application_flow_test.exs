defmodule ClientatsWeb.Features.JobApplicationFlowTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query

  @moduletag :feature

  test "complete job application workflow", %{session: session} do
    user = create_user()

    session
    |> visit("/")
    |> click(link("Get Started"))
    |> assert_has(css("h2", text: "Create your account"))
    |> fill_in(css("input[name='user[email]']"), with: user.email)
    |> fill_in(css("input[name='user[first_name]']"), with: user.first_name)
    |> fill_in(css("input[name='user[last_name]']"), with: user.last_name)
    |> fill_in(css("input[name='user[password]']"), with: "password123")
    |> fill_in(css("input[name='user[password_confirmation]']"), with: "password123")
    |> click(button("Create an account"))
    |> assert_has(css("h1", text: "Welcome to Clientats"))
    |> click(link("Go to Dashboard"))
    |> assert_has(css("h1", text: "Clientats Dashboard"))
    |> click(link("Add Interest"))
    |> assert_has(css("h2", text: "New Job Interest"))
    |> fill_in(css("input[name='job_interest[company_name]']"), with: "Tech Corp")
    |> fill_in(css("input[name='job_interest[position_title]']"), with: "Software Engineer")
    |> click(button("Save Job Interest"))
    |> assert_has(css("h3", text: "Software Engineer"))
    |> click(css("div[phx-click='select_interest']"))
    |> assert_has(css("h1", text: "Software Engineer"))
    |> click(link("Apply for Job"))
    |> assert_has(css("h2", text: "New Job Application"))
    |> assert_has(css("p", text: "Converting job interest to application"))
    |> assert_has(css("input[value='Tech Corp']"))
    |> fill_in(css("input[name='job_application[application_date]']"), with: "2024-01-15")
    |> click(button("Create Application"))
    |> assert_has(css("h1", text: "Software Engineer"))
    |> assert_has(css("h2", text: "Tech Corp"))
  end

  test "convert application back to interest", %{session: session} do
    user = create_user_and_login(session)
    interest = create_job_interest(user.id)
    application = create_job_application_from_interest(user.id, interest.id)

    session
    |> visit("/dashboard/applications/#{application.id}")
    |> assert_has(css("h1", text: application.position_title))
    |> assert_has(button("Convert to Interest"))
  end

  test "manage resumes", %{session: session} do
    _user = create_user_and_login(session)

    session
    |> visit("/dashboard")
    |> click(link("Manage Resumes"))
    |> assert_has(css("h1", text: "My Resumes"))
    |> assert_has(css("p", text: "No resumes uploaded yet"))
  end

  test "manage cover letter templates", %{session: session} do
    _user = create_user_and_login(session)

    session
    |> visit("/dashboard")
    |> click(link("Cover Letter Templates"))
    |> assert_has(css("h1", text: "Cover Letter Templates"))
    |> click(link("Create Your First Template"))
    |> assert_has(css("h2", text: "New Cover Letter Template"))
    |> fill_in(css("input[name='cover_letter_template[name]']"), with: "General Template")
    |> fill_in(css("textarea[name='cover_letter_template[content]']"),
      with: "Dear Hiring Manager,\n\nI am very interested..."
    )
    |> click(button("Create Template"))
    |> assert_has(css("h3", text: "General Template"))
  end

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

  defp create_job_interest(user_id) do
    {:ok, interest} =
      Clientats.Jobs.create_job_interest(%{
        user_id: user_id,
        company_name: "Tech Corp",
        position_title: "Senior Engineer",
        status: "interested",
        priority: "high"
      })

    interest
  end

  defp create_job_application_from_interest(user_id, interest_id) do
    interest = Clientats.Jobs.get_job_interest!(interest_id)

    {:ok, app} =
      Clientats.Jobs.create_job_application(%{
        user_id: user_id,
        job_interest_id: interest_id,
        company_name: interest.company_name,
        position_title: interest.position_title,
        application_date: Date.utc_today()
      })

    Clientats.Jobs.delete_job_interest(interest)
    app
  end
end
