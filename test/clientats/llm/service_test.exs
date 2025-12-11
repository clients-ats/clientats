defmodule Clientats.LLM.ServiceTest do
  use ExUnit.Case, async: true
  
  alias Clientats.LLM.Service
  alias Clientats.LLM.PromptTemplates
  
  describe "LLM Service" do
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
        assert result == {:error, :invalid_provider}
      end
    end
    
    describe "extract_job_data_from_url/3" do
      test "returns error for invalid URL format" do
        result = Service.extract_job_data_from_url("not-a-url", :generic)
        assert result == {:error, :invalid_url}
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
        assert Enum.any?(providers, &(&1.name == :openai || &1.name == :anthropic || &1.name == :mistral))
      end
    end
    
    describe "get_config/0" do
      test "returns configuration map" do
        config = Service.get_config()
        assert is_map(config)
      end
    end
  end
  
  describe "PromptTemplates" do
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
        
        assert String.contains?(prompt, "unknown job board")
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
    
    describe "detect_source/1" do
      test "detects LinkedIn URLs" do
        assert PromptTemplates.detect_source("https://www.linkedin.com/jobs/view/123") == :linkedin
      end
      
      test "detects Indeed URLs" do
        assert PromptTemplates.detect_source("https://www.indeed.com/viewjob?jk=123") == :indeed
      end
      
      test "detects unknown URLs" do
        assert PromptTemplates.detect_source("https://www.example.com/jobs/123") == :unknown
      end
    end
  end
  
  describe "Cache" do
    setup do
      # Clear cache before each test
      Clientats.LLM.Cache.clear()
      :ok
    end
    
    test "cache operations" do
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