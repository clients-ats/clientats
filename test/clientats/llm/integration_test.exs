defmodule Clientats.LLM.IntegrationTest do
  use ExUnit.Case, async: true

  alias Clientats.LLM.Service
  alias Clientats.LLM.PromptTemplates
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

    # Clear cache
    Clientats.LLM.Cache.clear()

    %{user: user}
  end

  describe "Full workflow integration" do
    test "extracts job data and creates job interest", %{user: _user} do
      # This test would work with actual LLM API if configured
      # For now, we'll test the error handling path

      result = Service.extract_job_data("test content", "https://example.com", :generic)

      # Should return an error since we don't have actual LLM API keys in test
      assert match?({:error, _}, result)
    end

    test "handles different extraction modes", %{user: _user} do
      # Test specific mode
      specific_result = Service.extract_job_data("test", "https://linkedin.com/jobs/123", :specific)

      # Test generic mode
      generic_result = Service.extract_job_data("test", "https://example.com/jobs/123", :generic)

      # Both should return errors without actual LLM API
      assert match?({:error, _}, specific_result)
      assert match?({:error, _}, generic_result)
    end
  end

  describe "Prompt generation and parsing" do
    test "generates valid prompts for different scenarios" do
      # Test LinkedIn prompt
      linkedin_prompt = PromptTemplates.build_job_extraction_prompt(
        "Job content here",
        "https://www.linkedin.com/jobs/view/12345",
        :specific
      )

      assert String.contains?(linkedin_prompt, "LinkedIn")
      assert String.contains?(linkedin_prompt, "Job content here")

      # Test generic prompt
      generic_prompt = PromptTemplates.build_job_extraction_prompt(
        "Job content here",
        "https://www.example.com/jobs/123",
        :generic
      )

      assert String.contains?(generic_prompt, "unknown job board")
    end
  end

  describe "Error handling and edge cases" do
    test "handles very long URLs" do
      long_url = "https://example.com/" <> String.duplicate("a", 3000)

      result = Service.extract_job_data("test", long_url, :generic)
      assert result == {:error, :invalid_url}
    end

    test "handles empty content" do
      result = Service.extract_job_data("", "https://example.com", :generic)
      assert result == {:error, :invalid_content}
    end

    test "handles invalid provider specification" do
      result = Service.extract_job_data("test", "https://example.com", :generic, :invalid_provider)
      assert result == {:error, :invalid_provider}
    end
  end

  describe "Cache functionality" do
    test "cache stores and retrieves data correctly" do
      test_data = %{company_name: "Test Co", position_title: "Test Job"}

      # Store in cache
      assert Clientats.LLM.Cache.put("https://test-url.com", test_data) == :ok

      # Retrieve from cache
      assert Clientats.LLM.Cache.get("https://test-url.com") == {:ok, test_data}

      # Delete from cache
      assert Clientats.LLM.Cache.delete("https://test-url.com") == :ok
      assert Clientats.LLM.Cache.get("https://test-url.com") == :not_found
    end
  end
end