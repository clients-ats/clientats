defmodule ClientatsWeb.ResumeLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "resumes index" do
    test "renders resumes list", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert html =~ "My Resumes"
    end

    test "displays resumes", %{conn: conn} do
      user = user_fixture()
      _resume = resume_fixture(user_id: user.id, name: "Test Resume")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert html =~ "Test Resume"
    end

    test "shows empty state when no resumes", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert html =~ "No resumes uploaded yet"
    end

    test "sets default resume", %{conn: conn} do
      user = user_fixture()
      resume = resume_fixture(user_id: user.id, is_default: false)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes")

      lv
      |> element("button", "Set as Default")
      |> render_click()

      updated = Clientats.Documents.get_resume!(resume.id)
      assert updated.is_default
    end

    test "deletes resume", %{conn: conn} do
      user = user_fixture()
      resume = resume_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes")

      lv
      |> element("button", "Delete")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn ->
        Clientats.Documents.get_resume!(resume.id)
      end
    end
  end

  describe "new resume" do
    test "renders upload form", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      assert html =~ "Upload Resume"
      assert html =~ "Resume Name"
    end

    test "redirects if not authenticated", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/dashboard/resumes/new")

      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/login"
    end

    test "validates resume name is required", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes/new")

      result =
        lv
        |> form("#resume-form", resume: %{name: ""})
        |> render_change()

      assert result =~ "can&#39;t be blank"
    end

    test "shows file upload area", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      assert html =~ "Drag and drop your resume here"
      assert html =~ "PDF, DOC, or DOCX up to 5MB"
    end

    test "validates form on change", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes/new")

      result =
        lv
        |> form("#resume-form", resume: %{name: "My Resume"})
        |> render_change()

      refute result =~ "can&#39;t be blank"
    end
  end

  describe "edit resume" do
    test "renders edit form", %{conn: conn} do
      user = user_fixture()
      resume = resume_fixture(user_id: user.id, name: "Test Resume")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/#{resume}/edit")

      assert html =~ "Edit Resume"
      assert html =~ "Test Resume"
    end

    test "updates resume with valid data", %{conn: conn} do
      user = user_fixture()
      resume = resume_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes/#{resume}/edit")

      lv
      |> form("#resume-form",
        resume: %{
          name: "Updated Resume",
          description: "New description"
        }
      )
      |> render_submit()

      updated = Clientats.Documents.get_resume!(resume.id)
      assert updated.name == "Updated Resume"
      assert updated.description == "New description"
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

  defp resume_fixture(attrs) do
    default_attrs = %{
      name: "Test Resume",
      file_path: "/uploads/resumes/test-#{System.unique_integer([:positive])}.pdf",
      original_filename: "resume.pdf",
      is_default: false
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, resume} = Clientats.Documents.create_resume(attrs)
    resume
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
