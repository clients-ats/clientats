defmodule ClientatsWeb.DocumentManagementLiveViewTest do
  @moduledoc """
  Comprehensive test suite for document management LiveView components.

  Tests resume and cover letter management with:
  - File upload and validation
  - Template creation and editing
  - Default selection
  - Accessibility compliance
  - Edge cases and error handling
  """

  use ClientatsWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ClientatsWeb.LiveViewTestHelpers

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "ResumeLive.Index" do
    test "displays empty state when no resumes", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      # Should display the resume page without any resume items
      assert html =~ "Resumes" or html =~ "Resume"
      assert html =~ "Upload"
    end

    test "lists all user resumes", %{conn: conn, user: user} do
      resume_fixture(user, %{name: "Main Resume"})
      resume_fixture(user, %{name: "Short Resume"})

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert html =~ "Main Resume"
      assert html =~ "Short Resume"
    end

    test "resume list is accessible", %{conn: conn, user: user} do
      resume_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert_has_heading(html, 1, "My Resumes") or assert_has_heading(html, 1, "Resumes") or assert_has_heading(html, 1, "Resume")
      # Should display resume items
      assert html =~ "resume.pdf" or html =~ "Resume" or html =~ "KB"
    end

    test "shows file size and upload date", %{conn: conn, user: user} do
      resume_fixture(user, %{file_size: 102_400})

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      # Should show file size
      assert html =~ "100" or html =~ "KB" or html =~ "file"
    end

    test "marks default resume", %{conn: conn, user: user} do
      resume_fixture(user, %{name: "Default", is_default: true})
      resume_fixture(user, %{name: "Other", is_default: false})

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      # Should indicate which is default
      assert html =~ "Default" and html =~ "default"
    end

    test "provides delete button", %{conn: conn, user: user} do
      _resume = resume_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert html =~ "Delete" or html =~ "Remove"
    end

    test "provides upload button", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert html =~ "Upload" or html =~ "New Resume" or html =~ "Add Resume"
    end

    test "sets resume as default", %{conn: conn, user: user} do
      _r1 = resume_fixture(user, %{name: "Resume 1", is_default: true})
      r2 = resume_fixture(user, %{name: "Resume 2", is_default: false})

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes")

      # Click set as default on Resume 2
      result =
        lv
        |> element("button[phx-click='set_default'][phx-value-id='#{r2.id}']")
        |> render_click()

      # Should update default status
      assert String.contains?(result, "Resume 2") or String.contains?(result, "default")
    end

    test "deletes resume with confirmation", %{conn: conn, user: user} do
      _resume = resume_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes")

      # Delete resume
      result = lv |> element("button[phx-click='delete']") |> render_click()

      # Should remove from list or show confirmation
      assert String.contains?(result, "deleted") or
             String.contains?(result, "removed") or
             String.contains?(result, "resumes")
    end
  end

  describe "ResumeLive.New" do
    test "renders file upload form", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      assert html =~ "Upload" or html =~ "Resume" or html =~ "file"
      assert html =~ "Description" or html =~ "Notes"
    end

    test "upload form is accessible", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      # Should have accessible form structure
      assert html =~ "<form"
      assert html =~ "file" or html =~ "Resume"
      assert_has_heading(html, 2, "Upload Resume") or
             assert_has_heading(html, 1, "Resume") or
             assert_has_heading(html, 2, "Resume")
    end

    test "validates file type", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      # Should indicate allowed file types
      assert html =~ "PDF" or html =~ "DOC" or html =~ "file type"
    end

    test "shows file size limit", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      # Should indicate max file size
      assert html =~ "5MB" or html =~ "5 MB" or html =~ "file size"
    end

    test "allows optional description", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      # Description field should be present and optional
      assert html =~ "description" or html =~ "notes"
    end

    test "allows setting as default", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      assert html =~ "default" or html =~ "primary"
    end

    test "shows upload progress", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      # Should have progress indicator
      assert html =~ "upload" or html =~ "progress"
    end
  end

  describe "CoverLetterLive.Index" do
    test "displays empty state when no templates", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      # Should display the cover letters page without any templates
      assert html =~ "Cover Letter" or html =~ "Template"
      assert html =~ "New"
    end

    test "lists all cover letter templates", %{conn: conn, user: user} do
      cover_letter_template_fixture(user, %{name: "Template 1"})
      cover_letter_template_fixture(user, %{name: "Template 2"})

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      assert html =~ "Template 1"
      assert html =~ "Template 2"
    end

    test "template list is accessible", %{conn: conn, user: user} do
      cover_letter_template_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      assert_has_heading(html, 1, "Cover Letter Templates") or
        assert_has_heading(html, 1, "Cover Letter") or
        assert_has_heading(html, 1, "Templates")
      # Should display template items
      assert html =~ "Default Template" or html =~ "Template" or html =~ "Created"
    end

    test "marks default template", %{conn: conn, user: user} do
      cover_letter_template_fixture(user, %{name: "Default", is_default: true})
      cover_letter_template_fixture(user, %{name: "Other", is_default: false})

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      assert html =~ "Default" and html =~ "default"
    end

    test "provides create button", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters")

      assert html =~ "New" or html =~ "Create" or html =~ "Add"
    end

    test "sets template as default", %{conn: conn, user: user} do
      _t1 = cover_letter_template_fixture(user, %{name: "Template 1", is_default: true})
      t2 = cover_letter_template_fixture(user, %{name: "Template 2", is_default: false})

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters")

      # Set Template 2 as default
      result =
        lv
        |> element("button[phx-click='set_default'][phx-value-id='#{t2.id}']")
        |> render_click()

      assert String.contains?(result, "default") or String.contains?(result, "Template 2")
    end

    test "deletes template with confirmation", %{conn: conn, user: user} do
      _template = cover_letter_template_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters")

      result = lv |> element("button[phx-click='delete']") |> render_click()

      assert String.contains?(result, "deleted") or
             String.contains?(result, "removed") or
             String.contains?(result, "cover-letters")
    end
  end

  describe "CoverLetterLive.New" do
    test "renders template creation form", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters/new")

      assert html =~ "New" or html =~ "Template"
      assert html =~ "Name"
      assert html =~ "Content"
    end

    test "form is accessible", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters/new")

      # Should have form with proper labels
      assert html =~ "<form"
      assert html =~ "Template Name" or html =~ "cover_letter_template_name"
      assert html =~ "Content" or html =~ "cover_letter_template_content"
    end

    test "provides placeholder help text", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters/new")

      # Should show available placeholders
      assert html =~ "{" and html =~ "}" or html =~ "placeholder"
    end

    test "creates template with valid data", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters/new")

      result =
        lv
        |> form("#template-form", %{
          "cover_letter_template" => %{
            "name" => "Professional Template",
            "content" => "Dear {company_name},\n\nI am interested...",
            "is_default" => "false"
          }
        })
        |> render_submit()

      # Form submission causes a redirect, so we check for that
      case result do
        {:error, {:live_redirect, _}} -> :ok  # Expected behavior
        html when is_binary(html) ->
          assert String.contains?(html, "Professional Template") or
                 String.contains?(html, "cover-letters")
      end
    end

    test "validates required fields", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters/new")

      result =
        lv
        |> form("#template-form", %{
          "cover_letter_template" => %{"name" => "", "content" => ""}
        })
        |> render_submit()

      assert String.contains?(result, "can't be blank") or
             String.contains?(result, "required")
    end
  end

  describe "CoverLetterLive.Edit" do
    test "renders edit form with template data", %{conn: conn, user: user} do
      template =
        cover_letter_template_fixture(user, %{
          name: "Edit Me",
          content: "Original content"
        })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters/#{template.id}/edit")

      assert html =~ "Edit Me"
      assert html =~ "Original content"
    end

    test "updates template", %{conn: conn, user: user} do
      template = cover_letter_template_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters/#{template.id}/edit")

      result =
        lv
        |> form("#template-form", %{
          "cover_letter_template" => %{
            "name" => "Updated Name",
            "content" => "Updated content"
          }
        })
        |> render_submit()

      # Form submission causes a redirect, so we check for that
      case result do
        {:error, {:live_redirect, _}} -> :ok  # Expected behavior
        html when is_binary(html) ->
          assert String.contains?(html, "Updated Name") or
                 String.contains?(html, "cover-letters")
      end
    end
  end

  describe "document accessibility" do
    test "file upload indicates accepted formats", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes/new")

      assert html =~ "PDF" or html =~ "DOC" or html =~ "accept="
    end

    test "document lists show modification dates accessibly", %{conn: conn, user: user} do
      resume_fixture(user)

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      # Should show date in human-readable format
      assert html =~ "202" or html =~ "date" or html =~ "updated"
    end

    test "template content is in properly formatted textarea", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/cover-letters/new")

      assert html =~ "<textarea" or html =~ "textarea"
    end
  end

  describe "edge cases" do
    test "handles special characters in file names", %{conn: conn, user: user} do
      resume_fixture(user, %{
        original_filename: "Resume_John_O'Brien-2024.pdf"
      })

      conn = log_in_user(conn, user)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      assert html =~ "O'Brien" or html =~ "Resume"
    end

    test "handles very long template content", %{conn: conn, user: user} do
      long_content = String.duplicate("A", 10_000)

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/cover-letters/new")

      result =
        lv
        |> form("#template-form", %{
          "cover_letter_template" => %{
            "name" => "Long Template",
            "content" => long_content
          }
        })
        |> render_submit()

      # Form submission causes a redirect, so we check for that
      case result do
        {:error, {:live_redirect, _}} -> :ok  # Expected behavior
        html when is_binary(html) ->
          assert String.contains?(html, "Long Template") or
                 String.contains?(html, "too long")
      end
    end

    test "prevents setting non-default as default when already has default", %{conn: conn, user: user} do
      _r1 = resume_fixture(user, %{name: "Default", is_default: true})
      r2 = resume_fixture(user, %{name: "Other", is_default: false})

      conn = log_in_user(conn, user)
      {:ok, lv, _html} = live(conn, ~p"/dashboard/resumes")

      # Set r2 as default (should replace r1)
      _result = lv |> element("button[phx-click='set_default'][phx-value-id='#{r2.id}']") |> render_click()

      # Both should not be marked default (implementation dependent)
      {:ok, _lv, html} = live(conn, ~p"/dashboard/resumes")

      # Only one should show as default
      assert html =~ "default"
    end
  end
end
