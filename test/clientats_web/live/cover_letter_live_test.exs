defmodule ClientatsWeb.CoverLetterLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "cover letters index" do
    test "renders cover letter templates list", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      assert html =~ "Cover Letter Templates"
    end

    test "displays templates", %{conn: conn} do
      user = user_fixture()
      _template = cover_letter_fixture(user_id: user.id, name: "Test Template")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      assert html =~ "Test Template"
    end

    test "shows empty state when no templates", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      assert html =~ "No cover letter templates yet"
    end

    test "sets default template", %{conn: conn} do
      user = user_fixture()
      template = cover_letter_fixture(user_id: user.id, is_default: false)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters")

      lv
      |> element("button", "Set as Default")
      |> render_click()

      updated = Clientats.Documents.get_cover_letter_template!(template.id)
      assert updated.is_default
    end

    test "deletes template", %{conn: conn} do
      user = user_fixture()
      template = cover_letter_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters")

      lv
      |> element("button", "Delete")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn ->
        Clientats.Documents.get_cover_letter_template!(template.id)
      end
    end
  end

  describe "new cover letter" do
    test "renders new template form", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters/new")

      assert html =~ "New Cover Letter Template"
      assert html =~ "Template Name"
      assert html =~ "Cover Letter Content"
    end

    test "creates template with valid data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters/new")

      lv
      |> form("#template-form",
        cover_letter_template: %{
          name: "New Template",
          content: "Dear Hiring Manager,\n\nI am writing..."
        }
      )
      |> render_submit()

      template =
        Clientats.Repo.get_by(Clientats.Documents.CoverLetterTemplate, name: "New Template")

      assert template != nil
      assert template.content =~ "Dear Hiring Manager"
    end

    test "validates required fields", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters/new")

      result =
        lv
        |> form("#template-form",
          cover_letter_template: %{
            name: "",
            content: ""
          }
        )
        |> render_submit()

      assert result =~ "can&#39;t be blank"
    end
  end

  describe "edit cover letter" do
    test "renders edit form", %{conn: conn} do
      user = user_fixture()
      template = cover_letter_fixture(user_id: user.id, name: "Test Template")
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters/#{template}/edit")

      assert html =~ "Edit Cover Letter Template"
      assert html =~ "Test Template"
    end

    test "updates template with valid data", %{conn: conn} do
      user = user_fixture()
      template = cover_letter_fixture(user_id: user.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters/#{template}/edit")

      lv
      |> form("#template-form",
        cover_letter_template: %{
          name: "Updated Template",
          content: "Updated content"
        }
      )
      |> render_submit()

      updated = Clientats.Documents.get_cover_letter_template!(template.id)
      assert updated.name == "Updated Template"
      assert updated.content == "Updated content"
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

  defp cover_letter_fixture(attrs) do
    default_attrs = %{
      name: "Test Template",
      content: "Dear Hiring Manager,\n\nI am writing to express my interest...",
      is_default: false
    }

    attrs = Enum.into(attrs, default_attrs)
    {:ok, template} = Clientats.Documents.create_cover_letter_template(attrs)
    template
  end

  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
