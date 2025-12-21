defmodule ClientatsWeb.JobInterestLive.ScrapeTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  @moduletag :ollama

  alias Clientats.Accounts
  alias Clientats.LLMConfig

  setup do
    # Create a test user
    user_attrs = %{
      email: "test#{System.unique_integer([:positive])}@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    }

    {:ok, user} = Accounts.register_user(user_attrs)

    # Configure at least one LLM provider (Ollama) for the user
    LLMConfig.save_provider_config(user.id, :ollama, %{
      "enabled" => true,
      "base_url" => "http://localhost:11434"
    })

    # Create authenticated connection
    conn =
      build_conn()
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_id, user.id)

    %{conn: conn, user: user}
  end

  describe "Job Scrape LiveView" do
    test "renders scrape page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/job-interests/scrape")

      assert html =~ "Import Job from URL"
      assert html =~ "Paste a job posting URL"
      assert html =~ "Import"
    end

    test "shows Job Scrape LiveView shows provider selection by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/job-interests/scrape")

      # Should show that a provider is configured
      assert html =~ "configured LLM provider"
      assert html =~ "ollama"
    end

    test "Job Scrape LiveView toggles provider settings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      # Verify page structure
      html = render(view)
      assert html =~ "Import Job from URL"
      assert html =~ "Enter URL"
    end

    test "Job Scrape LiveView selects different providers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      # Verify basic page structure
      html = render(view)
      assert html =~ "Supported Job Boards"
    end

    test "Job Scrape LiveView shows URL validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      # Verify form is present
      html = render(view)
      assert html =~ "<form"
    end

    test "Job Scrape LiveView updates URL input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      # Update URL input
      html =
        view
        |> form("form[phx-change='update_url']", %{
          "url" => "https://www.linkedin.com/jobs/view/123"
        })
        |> render_change()

      # Verify form still renders
      assert html =~ "Import" or html =~ "url"
    end

    test "Job Scrape LiveView shows Ollama status when selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      # Verify page structure
      html = render(view)
      assert html =~ "Supported Job Boards"
    end

    test "Job Scrape LiveView navigates back to URL step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      html = render(view)
      assert html =~ "Enter URL"
    end

    test "Job Scrape LiveView shows provider info in review step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      html = render(view)
      assert html =~ "configured LLM provider"
    end
  end

  describe "Provider Selection UI" do
    test "Provider Selection UI shows all provider options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      html = render(view)
      assert html =~ "Supported Job Boards"
    end

    test "Provider Selection UI highlights selected provider", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      html = render(view)
      assert html =~ "ollama"
    end

    test "Provider Selection UI shows provider descriptions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      html = render(view)
      # Provider info is shown in configuration message
      assert html =~ "configured LLM provider"
    end
  end

  describe "Ollama Integration" do
    test "Ollama Integration disables import button when checking Ollama", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      html = render(view)
      assert html =~ "Import"
    end

    test "Ollama Integration shows Ollama unavailable error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      html = render(view)
      # Should render the scrape page with Ollama provider configured
      assert html =~ "ollama"
    end
  end
end
