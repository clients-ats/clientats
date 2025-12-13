#!/usr/bin/env elixir
# Simple test script to verify job scraping works

Mix.start()
Mix.load_config()

# Test 1: Direct Ollama API call
IO.puts("="<> String.duplicate("=", 80))
IO.puts("TEST 1: Direct Ollama API call")
IO.puts("="<> String.duplicate("=", 80))

model = "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL"
test_prompt = """
Extract job posting information from this sample content:

Company: Red Hat
Job Title: Senior Site Reliability Engineer
Location: North Carolina, United States
Description: We are looking for a Senior SRE...

Return JSON with these fields:
- company_name
- position_title
- job_description
- location
- work_model (remote/hybrid/on_site)
"""

IO.puts("Prompt length: #{byte_size(test_prompt)} bytes")
IO.puts("Calling Ollama with model: #{model}")

case Clientats.LLM.Providers.Ollama.generate(model, test_prompt, [temperature: 0.1]) do
  {:ok, response} ->
    IO.puts("✓ Ollama responded successfully")
    IO.puts("\nResponse keys: #{inspect(Map.keys(response))}")

    # Check if response is a map or needs parsing
    if is_map(response) and Map.has_key?(response, "response") do
      IO.puts("Response text (first 500 chars):")
      IO.puts(String.slice(response["response"], 0, 500))
    else
      IO.puts("Full response: #{inspect(response, pretty: true)}")
    end

  {:error, reason} ->
    IO.puts("✗ Ollama call failed: #{inspect(reason)}")
end

IO.puts("\n" <> String.duplicate("=", 82) <> "\n")
