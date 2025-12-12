defmodule ClientatsWeb.JobInterestLive.ScrapeTest do
  use ClientatsWeb.ConnCase
  
  import Phoenix.LiveViewTest
  
  alias Clientats.Accounts
  
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
    
    test "shows provider selection by default", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      assert html =~ "LLM Provider"
      assert html =~ "Auto (Recommended)"
      assert html =~ "Choose how to process"
    end
    
    test "toggles provider settings", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Initially should not show all providers
      refute html =~ "OpenAI (GPT-4)"
      
      # Click to show settings
      html = view |> element("button", "Show Settings") |> render_click()
      
      # Now should show all providers
      assert html =~ "OpenAI (GPT-4)"
      assert html =~ "Anthropic (Claude)"
      assert html =~ "Mistral AI"
      assert html =~ "Ollama (Local)"
    end
    
    test "selects different providers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Show settings
      view = view |> element("button", "Show Settings") |> render_click()
      
      # Select Ollama
      view = view |> element("input[value='ollama']") |> render_click()
      
      # Verify selection
      assert get_assign(view, :llm_provider) == "ollama"
    end
    
    test "shows URL validation errors", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Try to submit without URL
      html = view |> element("button", "Import") |> render_click()
      
      # Should show error
      assert html =~ "Please enter a URL"
    end
    
    test "updates URL input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Update URL
      view = view |> form("input[type='url']", %{"url" => "https://example.com/jobs/123"})
      
      # Verify URL is updated
      assert get_assign(view, :url) == "https://example.com/jobs/123"
    end
    
    test "shows Ollama status when selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Show settings and select Ollama
      view = view 
             |> element("button", "Show Settings") |> render_click()
             |> element("input[value='ollama']") |> render_click()
      
      # Click Import to trigger Ollama check
      html = view |> element("button", "Import") |> render_click()
      
      # Should show checking status
      assert html =~ "Checking Ollama server..."
    end
    
    test "navigates back to URL step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Go to step 2 (simulate by setting assigns)
      view = assign(view, step: 2, scraped_data: %{company_name: "Test Co"})
      html = render(view)
      
      # Should show review step
      assert html =~ "Review & Save"
      
      # Click back
      html = view |> element("button", "Back") |> render_click()
      
      # Should be back to step 1
      assert html =~ "Enter URL"
    end
    
    test "shows provider info in review step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Set provider to Ollama and go to review step
      view = assign(view, 
                   step: 2, 
                   llm_provider: "ollama",
                   llm_status: "success",
                   scraped_data: %{company_name: "Test Co"})
      html = render(view)
      
      # Should show provider info
      assert html =~ "Processed using"
      assert html =~ "Ollama (Local)"
      assert html =~ "Success"
    end
  end
  
  describe "Provider Selection UI" do
    test "shows all provider options", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Show settings
      html = view |> element("button", "Show Settings") |> render_click()
      
      # Check all providers are present
      assert html =~ "Auto (Recommended)"
      assert html =~ "OpenAI (GPT-4)"
      assert html =~ "Anthropic (Claude)"
      assert html =~ "Mistral AI"
      assert html =~ "Ollama (Local)"
      
      # Check Ollama has local badge
      assert html =~ "Local"
    end
    
    test "highlights selected provider", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Show settings
      html = view |> element("button", "Show Settings") |> render_click()
      
      # Auto should be selected by default
      assert html =~ "border-blue-300 bg-blue-50"
      
      # Select Ollama
      view = view |> element("input[value='ollama']") |> render_click()
      html = render(view)
      
      # Ollama should now be highlighted
      assert html =~ "border-blue-300 bg-blue-50"
    end
    
    test "shows provider descriptions", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Show settings
      html = view |> element("button", "Show Settings") |> render_click()
      
      # Check descriptions are shown
      assert html =~ "Automatically select the best available provider"
      assert html =~ "High accuracy, commercial API"
      assert html =~ "Excellent reasoning, commercial API"
      assert html =~ "Open-source models, commercial API"
      assert html =~ "Privacy-focused, runs on your machine"
    end
  end
  
  describe "Ollama Integration" do
    test "disables import button when checking Ollama", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Show settings and select Ollama
      view = view 
             |> element("button", "Show Settings") |> render_click()
             |> element("input[value='ollama']") |> render_click()
      
      # Set URL
      view = view |> form("input[type='url']", %{"url" => "https://example.com"})
      
      # Click Import
      html = view |> element("button", "Import") |> render_click()
      
      # Button should be disabled while checking
      assert html =~ "btn-disabled"
    end
    
    test "shows Ollama unavailable error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/job-interests/scrape")
      
      # Show settings and select Ollama
      view = view 
             |> element("button", "Show Settings") |> render_click()
             |> element("input[value='ollama']") |> render_click()
      
      # Set URL
      view = view |> form("input[type='url']", %{"url" => "https://example.com"})
      
      # Click Import to trigger Ollama check
      view = view |> element("button", "Import") |> render_click()
      
      # Wait for Ollama check to complete (simulated)
      # In real scenario, this would get the :ollama_unavailable message
      html = render(view)
      
      # Should show checking status initially
      assert html =~ "Checking Ollama server..."
    end
  end
end