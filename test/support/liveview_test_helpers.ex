defmodule ClientatsWeb.LiveViewTestHelpers do
  @moduledoc """
  Testing utilities and helpers for LiveView component testing.

  Provides:
  - Common test setup and fixtures
  - Form interaction helpers
  - Accessibility testing utilities
  - Assertion helpers for LiveView
  """

  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  alias Clientats.Accounts
  alias Clientats.Jobs
  alias Clientats.Documents

  # User fixtures
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "test#{System.unique_integer()}@example.com",
        password: "password123",
        first_name: "Test",
        last_name: "User"
      })
      |> Accounts.register_user()

    user
  end

  def log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(user_id: user.id)
  end

  # Job interest fixtures
  def job_interest_fixture(user, attrs \\ %{}) do
    {:ok, interest} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        company_name: "Tech Corp",
        position_title: "Software Engineer",
        location: "San Francisco, CA",
        work_model: "hybrid",
        status: "interested",
        priority: "high"
      })
      |> Jobs.create_job_interest()

    interest
  end

  def job_application_fixture(user, attrs \\ %{}) do
    interest = job_interest_fixture(user)

    {:ok, application} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        job_interest_id: interest.id,
        company_name: interest.company_name,
        position_title: interest.position_title,
        application_date: Date.utc_today(),
        status: "applied"
      })
      |> Jobs.create_job_application()

    application
  end

  def resume_fixture(user, attrs \\ %{}) do
    {:ok, resume} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        name: "Main Resume",
        file_path: "/uploads/resume.pdf",
        original_filename: "resume.pdf",
        file_size: 102400,
        is_default: true
      })
      |> Documents.create_resume()

    resume
  end

  def cover_letter_template_fixture(user, attrs \\ %{}) do
    {:ok, template} =
      attrs
      |> Enum.into(%{
        user_id: user.id,
        name: "Default Template",
        content: "Dear {company_name},\n\nI am interested in the {position_title} role...",
        is_default: true
      })
      |> Documents.create_cover_letter_template()

    template
  end

  # Form interaction helpers
  def fill_form(lv, form_id, fields) do
    Enum.reduce(fields, lv, fn {field, value}, acc ->
      render_change(acc, "#{form_id}[#{field}]", %{"value" => to_string(value)})
      acc
    end)
  end

  def submit_form(lv, form_id) do
    render_submit(lv, "form", %{"#{form_id}" => %{}})
  end

  def get_form_errors(html) do
    Regex.scan(~r/phx-feedback-for="([^"]+)"[^>]*>([^<]+)</, html)
    |> Enum.map(fn [_full, field, error] -> {field, error} end)
    |> Enum.into(%{})
  end

  # Accessibility helpers
  def assert_accessible_label(html, input_id) do
    assert html =~ ~r/<label[^>]*for="#{input_id}"[^>]*>/,
           "Expected label with for=\"#{input_id}\" attribute"
  end

  def assert_accessible_form(html) do
    # Check for form landmarks
    assert html =~ ~r/<form/i, "Expected form element"

    # Check for submit button
    assert html =~ ~r/<button[^>]*type="submit"[^>]*>/i or
             html =~ ~r/<input[^>]*type="submit"[^>]*>/i,
           "Expected submit button in form"

    # Check for error container with aria-live
    if String.contains?(html, "phx-feedback-for") do
      assert html =~ ~r/aria-live="polite"/i or html =~ ~r/role="alert"/i,
             "Expected aria-live or role=alert for form errors"
    end
  end

  def assert_has_aria_label(html, expected_label) do
    assert html =~ ~r/aria-label="#{Regex.escape(expected_label)}"/i or
             html =~ ~r/>#{Regex.escape(expected_label)}</,
           "Expected aria-label or visible text: #{expected_label}"
  end

  def assert_button_accessible(html, button_text) do
    assert html =~ ~r/<button[^>]*>#{Regex.escape(button_text)}<\/button>/i or
             html =~ ~r/<input[^>]*value="#{Regex.escape(button_text)}"[^>]*type="button"/i or
             html =~ ~r/<input[^>]*type="submit"[^>]*value="#{Regex.escape(button_text)}"/i,
           "Expected accessible button with text: #{button_text}"
  end

  def assert_has_heading(html, level, text) do
    tag = "h#{level}"
    assert html =~ ~r/<#{tag}[^>]*>#{Regex.escape(text)}<\/#{tag}>/i,
           "Expected #{tag} with text: #{text}"
  end

  def assert_table_accessible(html) do
    # Check for table element
    assert html =~ ~r/<table/i, "Expected table element"

    # Check for thead with th elements
    assert html =~ ~r/<thead/i, "Expected thead element"
    assert html =~ ~r/<th/i, "Expected th elements for headers"

    # Check for tbody
    assert html =~ ~r/<tbody/i, "Expected tbody element"
  end

  def assert_list_accessible(html) do
    # Check for list element
    assert html =~ ~r/<(ul|ol)/i, "Expected list element (ul or ol)"

    # Check for list items
    assert html =~ ~r/<li/i, "Expected list items"
  end

  def assert_contrast_sufficient(html, _expected_ratio \\ 4.5) do
    # This is a simplified check - real WCAG contrast testing requires parsing colors
    # This just ensures we're not using low-contrast colors like white on white
    assert !String.contains?(html, "color:#fff;background:#fff") and
             !String.contains?(html, "color:#ffffff;background:#ffffff"),
           "Expected sufficient color contrast"
  end

  def get_accessibility_warnings(html) do
    warnings = []

    # Check for missing alt text
    warnings =
      if Regex.match?(~r/<img[^>]*(?!alt=)>/, html) do
        warnings ++ ["Images missing alt text"]
      else
        warnings
      end

    # Check for missing form labels
    warnings =
      if Regex.match?(~r/<input[^>]*type="(?!hidden)[^"]*"[^>]*(?!id=)>/, html) do
        warnings ++ ["Form inputs missing id/label association"]
      else
        warnings
      end

    # Check for color-only messaging
    warnings =
      if Regex.match?(~r/style="[^"]*color:\s*red[^"]*"[^>]*>[^<]*<\/>/, html) do
        warnings ++ ["Color used alone to convey information"]
      else
        warnings
      end

    warnings
  end

  # Assertion helpers
  def assert_flash(html, type, message) do
    selector = ".alert-#{type}"
    assert html =~ ~r/<div[^>]*class="[^"]*#{type}[^"]*"[^>]*>/i,
           "Expected flash of type #{type}"

    assert html =~ Regex.escape(message), "Expected flash message: #{message}"
  end

  def assert_redirect_to(conn, path) do
    assert redirected_to(conn) == path
  end

  def assert_live_component(lv, component, props) do
    # Verify component renders without errors
    html = render(lv)
    refute html =~ "error"
    refute html =~ "Error"
  end

  def wait_for_element(lv, selector, timeout \\ 100) do
    # Simple polling to wait for element to appear
    case render(lv) =~ ~r/#{Regex.escape(selector)}/i do
      true ->
        :ok

      false ->
        Process.sleep(timeout)
        wait_for_element(lv, selector, timeout)
    end
  end

  # Event simulation helpers
  def trigger_event(lv, event, payload \\ %{}) do
    lv
    |> element("button[phx-click=\"#{event}\"]")
    |> render_click(payload)
  end

  def fill_and_submit(lv, form_id, fields) do
    lv
    |> fill_form(form_id, fields)
    |> submit_form(form_id)
  end

  # Table and list helpers
  def get_table_rows(html) do
    Regex.scan(~r/<tr[^>]*>(.+?)<\/tr>/s, html)
    |> Enum.map(fn [_full, content] -> content end)
  end

  def get_list_items(html) do
    Regex.scan(~r/<li[^>]*>(.+?)<\/li>/s, html)
    |> Enum.map(fn [_full, content] -> content end)
  end

  def assert_paginated(html) do
    assert html =~ ~r/pagination/i or html =~ ~r/page/i,
           "Expected pagination controls"
  end

  # Error state helpers
  def assert_error_state(html) do
    assert html =~ ~r/error/i or
             html =~ ~r/failed/i or
             html =~ ~r/alert/i,
           "Expected error state displayed"
  end

  def assert_loading_state(html) do
    assert html =~ ~r/loading/i or
             html =~ ~r/spinner/i or
             html =~ ~r/disabled/i,
           "Expected loading state indicator"
  end

  def assert_empty_state(html) do
    assert html =~ ~r/no\s+(data|items|results|items found)/i or
             html =~ ~r/empty/i or
             html =~ ~r/nothing/i,
           "Expected empty state message"
  end
end
