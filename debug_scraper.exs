#!/usr/bin/env elixir

# Debug script to test job scraping with the RedHat URL

Mix.install([
  {:clientats, path: "."},
  {:req, "~> 0.4"},
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

alias Clientats.LLM.Service

# The URL we want to test
url = "https://redhat.wd5.myworkdayjobs.com/en-US/jobs/job/Senior-Site-Reliability-Engineer_R-044303-1"

IO.puts("=" <> String.duplicate("=", 80))
IO.puts("Testing job scraping with RedHat URL")
IO.puts("=" <> String.duplicate("=", 80))
IO.puts("URL: #{url}\n")

# Step 1: Try to fetch the URL content
IO.puts("[STEP 1] Fetching URL content...")
case Req.get!(url,
     headers: [
       {"User-Agent", "Mozilla/5.0 (compatible; Clientats/1.0; +https://clientats.com)"},
       {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
       {"Accept-Language", "en-US,en;q=0.5"}
     ],
     receive_timeout: 30_000,
     follow_redirects: true
    ) |> (fn resp -> {:ok, resp} end).() do
  %{status: 200, body: body} ->
    IO.puts("✓ Successfully fetched URL (#{byte_size(body)} bytes)")
    IO.puts("\n[Content Preview]")
    IO.puts(String.slice(body, 0, 500))
    IO.puts("...\n")

    # Step 2: Try extraction with Ollama
    IO.puts("[STEP 2] Testing extraction with Ollama...")
    case Service.extract_job_data(body, url, :generic, :ollama) do
      {:ok, result} ->
        IO.puts("✓ Extraction successful!")
        IO.puts("\nExtracted data:")
        IO.inspect(result, pretty: true)

      {:error, reason} ->
        IO.puts("✗ Extraction failed!")
        IO.puts("Reason: #{inspect(reason)}")
    end

  %{status: status, body: body} ->
    IO.puts("✗ HTTP Error #{status}")
    IO.puts("Response: #{String.slice(body, 0, 200)}")

  error ->
    IO.puts("✗ Request failed: #{inspect(error)}")
end

IO.puts("\n" <> String.duplicate("=", 82))
