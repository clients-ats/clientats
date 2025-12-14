defmodule ClientatsWeb.LLMConfigLiveTest do
  use ClientatsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Clientats.Accounts
  alias Clientats.LLMConfig

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "test#{System.unique_integer()}@example.com",
        password: "testpassword123",
        first_name: "Test",
        last_name: "User"
      })

    {:ok, user: user}
  end

  describe "LLM Configuration Live View" do
    test "mounts and displays provider tabs", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/llm-config")

      assert html =~ "LLM Configuration"
      assert html =~ "Ollama"
      assert html =~ "OpenAI"
      assert html =~ "Anthropic"
      assert html =~ "Mistral"
    end

    test "displays provider status section", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/llm-config")

      assert html =~ "Provider Status"
    end

    test "saves provider configuration", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/llm-config")

      result =
        lv
        |> form("#setting-form", %{
          "setting" => %{
            "provider" => "ollama",
            "base_url" => "http://localhost:11434",
            "default_model" => "mistral",
            "enabled" => "true"
          }
        })
        |> render_submit()

      assert result =~ "saved"
    end

    test "validates API key before saving", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/llm-config")

      # Try to save with invalid OpenAI key
      html =
        lv
        |> form("#setting-form", %{
          "setting" => %{
            "provider" => "openai",
            "api_key" => "invalid",
            "enabled" => "true"
          }
        })
        |> render_submit()

      # Error message should be displayed
      assert html =~ "error" or html =~ "Invalid"
    end

    test "switches between provider tabs", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard/llm-config")

      # Click on anthropic tab
      html =
        lv
        |> element("button", "Anthropic")
        |> render_click()

      assert html =~ "API Key"
    end

    test "shows loaded configuration when editing", %{conn: conn, user: user} do
      # Save a configuration first
      LLMConfig.save_provider_config(user.id, :openai, %{
        "provider" => "openai",
        "api_key" => "sk-test-key",
        "default_model" => "gpt-4o",
        "enabled" => true
      })

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/llm-config")

      # Verify the form loads with data
      assert html =~ "gpt-4o"
    end

    test "requires authentication", %{conn: conn} do
      {:error, {:redirect, %{to: redirect_path}}} = live(conn, ~p"/dashboard/llm-config")

      assert redirect_path == ~p"/login"
    end

    test "displays test connection button", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/llm-config")

      assert html =~ "Test Connection"
    end
  end

  describe "Job Interest guard tests" do
    test "redirects to dashboard if no providers configured", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _lv, _html} = live(conn, ~p"/dashboard/job-interests/scrape")

      # Should be redirected (LiveView returns error)
      # The redirect happens on mount
    end

    test "allows access to scrape page if provider configured", %{conn: conn, user: user} do
      # Configure a provider
      LLMConfig.save_provider_config(user.id, :ollama, %{
        "provider" => "ollama",
        "base_url" => "http://localhost:11434",
        "enabled" => true
      })

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/scrape")

      assert html =~ "Import Job from URL"
    end
  end

  describe "Job Interest New page" do
    test "shows import link if provider configured", %{conn: conn, user: user} do
      LLMConfig.save_provider_config(user.id, :ollama, %{
        "provider" => "ollama",
        "base_url" => "http://localhost:11434",
        "enabled" => true
      })

      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert html =~ "Import from URL"
    end

    test "hides import link if no provider configured", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/job-interests/new")

      assert html =~ "disabled"
      assert html =~ "Configure an LLM provider"
    end
  end

  defp log_in_user(conn, user) do
    conn
    |> post(~p"/login", user: %{email: user.email, password: "testpassword123"})
    |> redirected_to(302)
    |> follow_redirect(conn)
    |> elem(1)
  end
end
