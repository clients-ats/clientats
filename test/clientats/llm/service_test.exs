defmodule Clientats.LLM.ServiceTest do
  use ExUnit.Case, async: true

  alias Clientats.LLM.Service
  alias Clientats.LLM.PromptTemplates

  describe "extract_job_data/5" do
    test "returns error for empty content" do
      result = Service.extract_job_data("", "https://example.com", :generic)
      assert result == {:error, :invalid_content}
    end

    test "returns error for invalid URL" do
      result = Service.extract_job_data("test content", "invalid-url", :generic)
      assert result == {:error, :invalid_url}
    end

    test "returns error for unsupported provider" do
      result = Service.extract_job_data("test", "https://example.com", :generic, :unsupported_provider)
      # Unsupported providers fail during extraction with invalid_response_format
      assert match?({:error, _}, result)
    end
  end

  describe "extract_job_data_from_url/3" do
    test "returns error for invalid URL format" do
      result = Service.extract_job_data_from_url("not-a-url", :generic)
      # Invalid URLs get caught during fetch, not validation
      assert match?({:error, _}, result)
    end

    test "returns error for unreachable URL" do
      # This would actually make an HTTP request, so we'll mock it in a separate test
      result = Service.extract_job_data_from_url("https://this-url-should-not-exist-12345.com", :generic)
      # Should return fetch error or timeout
      assert match?({:error, _}, result)
    end
  end

  describe "get_available_providers/0" do
    test "returns list of providers" do
      providers = Service.get_available_providers()
      assert is_list(providers)
      # Just verify we get a list of providers back
      assert Enum.all?(providers, &is_map/1)
    end
  end

  describe "get_config/0" do
    test "returns configuration map" do
      config = Service.get_config()
      assert is_map(config)
    end
  end

  describe "build_job_extraction_prompt/3" do
    test "generates specific mode prompt for known job boards" do
      content = "Test job content"
      url = "https://www.linkedin.com/jobs/view/12345"

      prompt = PromptTemplates.build_job_extraction_prompt(content, url, :specific)

      assert String.contains?(prompt, "LinkedIn")
      assert String.contains?(prompt, "Test job content")
    end

    test "generates generic mode prompt for unknown sources" do
      content = "Test job content"
      url = "https://www.example.com/jobs/123"

      prompt = PromptTemplates.build_job_extraction_prompt(content, url, :generic)

      assert String.contains?(prompt, "unknown")
      assert String.contains?(prompt, "Test job content")
    end
  end

  describe "system_prompt/0" do
    test "returns system prompt string" do
      prompt = PromptTemplates.system_prompt()
      assert is_binary(prompt)
      assert String.length(prompt) > 50
    end
  end

  describe "build_job_extraction_prompt/3 source detection" do
    test "detects LinkedIn URLs in prompt" do
      prompt = PromptTemplates.build_job_extraction_prompt("job content", "https://www.linkedin.com/jobs/view/123", :specific)
      assert String.contains?(prompt, "LinkedIn")
    end

    test "detects Indeed URLs in prompt" do
      prompt = PromptTemplates.build_job_extraction_prompt("job content", "https://www.indeed.com/viewjob?jk=123", :specific)
      assert String.contains?(prompt, "Indeed")
    end

    test "handles unknown URLs in prompt" do
      prompt = PromptTemplates.build_job_extraction_prompt("job content", "https://www.example.com/jobs/123", :specific)
      assert String.contains?(prompt, "unknown job board")
    end
  end

  describe "cache operations" do
    setup do
      # Clear cache before each test
      Clientats.LLM.Cache.clear()
      :ok
    end

    test "cache put and get" do
      # Test cache put and get
      assert Clientats.LLM.Cache.get("test-url") == :not_found

      assert Clientats.LLM.Cache.put("test-url", %{test: "data"}) == :ok
      assert Clientats.LLM.Cache.get("test-url") == {:ok, %{test: "data"}}

      # Test cache deletion
      assert Clientats.LLM.Cache.delete("test-url") == :ok
      assert Clientats.LLM.Cache.get("test-url") == :not_found
    end
  end
end