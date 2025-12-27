defmodule ClientatsWeb.JobApplicationControllerTest do
  use ClientatsWeb.ConnCase

  describe "download_cover_letter" do
    test "downloads cover letter as PDF", %{conn: conn} do
      user = user_fixture()

      app =
        job_application_fixture(
          user_id: user.id,
          company_name: "Test Corp",
          cover_letter_content: "My cover letter content"
        )

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/dashboard/applications/#{app.id}/download-cover-letter")

      assert conn.status == 200
      assert response_content_type(conn, :pdf)
      assert conn.resp_body =~ "%PDF"
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
end
