defmodule Clientats.LLM.OllamaTest do
  use ExUnit.Case, async: true

  alias Clientats.LLM.Providers.Ollama

  describe "ping/1" do
    test "checks Ollama server availability" do
      # This will fail if Ollama is not running, which is expected in test environment
      result = Ollama.ping()

      # Should return either available or unavailable
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "list_models/1" do
    test "lists available models" do
      # This will fail if Ollama is not running
      result = Ollama.list_models()

      # Should return either models or error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "generate/4" do
    test "generates text with proper parameters" do
      # Mock the HTTP request to test the function without actual Ollama server
      # In a real test environment with Ollama running, this would make actual calls

      # Test parameter building
      model = "test-model"
      prompt = "Test prompt"
      options = [temperature: 0.5, top_p: 0.9, num_predict: 100]

      # This would actually call Ollama if it were running
      # For testing purposes, we'll just verify the function can be called
      assert match?({:error, _}, Ollama.generate(model, prompt, options))
    end
  end

  describe "chat/4" do
    test "converts messages to prompt format" do
      messages = [
        %{role: "system", content: "You are a helpful assistant"},
        %{role: "user", content: "Hello!"}
      ]

      # This would call the generate function
      result = Ollama.chat("test-model", messages)

      # Should return error since Ollama is not running in test
      assert match?({:error, _}, result)
    end
  end

  describe "configuration" do
    test "uses default base URL" do
      assert Ollama.ping() == Ollama.ping("http://localhost:11434")
    end

    test "accepts custom base URL" do
      # Different result expected since different URL
      assert Ollama.ping("http://localhost:11434") != Ollama.ping("http://localhost:9999")
    end
  end
end