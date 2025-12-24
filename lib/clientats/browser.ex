defmodule Clientats.Browser do
  @moduledoc """
  Browser automation for capturing job posting pages as images.

  Uses headless Chrome via Puppeteer-over-HTTP or similar services
  to capture screenshots of web pages, enabling multimodal LLM
  extraction with visual context.
  """

  require Logger

  @default_timeout 30000

  @doc """
  Capture a screenshot of a URL and save it to a file.

  ## Parameters
    - url: The URL to capture
    - options: Additional options (viewport_width, viewport_height, timeout, etc.)

  ## Returns
    - {:ok, file_path} where file_path is the path to the saved PNG
    - {:error, reason} on failure

  ## Notes
    Currently requires Chrome/Chromium to be installed on the system.
    The screenshot is saved to /tmp/ with a timestamp-based filename.
  """
  def capture_screenshot(url, options \\ []) do
    with {:ok, url} <- validate_url(url),
         {:ok, output_file} <- run_chrome_screenshot(url, options) do
      IO.puts("[Browser] Screenshot captured: #{output_file}")
      {:ok, output_file}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Generate a PDF from HTML content and save it to a file.

  ## Parameters
    - html: The HTML content to convert
    - options: Additional options (format, margin, etc.)

  ## Returns
    - {:ok, file_path} where file_path is the path to the saved PDF
    - {:error, reason} on failure
  """
  def generate_pdf(html, _options \\ []) do
    output_file = "/tmp/clientats_document_#{System.unique_integer([:positive])}.pdf"
    
    script_path = Path.join(:code.priv_dir(:clientats), "../../../scripts/generate_pdf.js")
    script_path = if File.exists?(script_path), do: script_path, else: "scripts/generate_pdf.js"

    case File.exists?(script_path) do
      false ->
        IO.puts("[Browser] PDF script not found at #{script_path}")
        {:error, :script_not_found}

      true ->
        IO.puts("[Browser] Generating PDF...")
        
        try do
          # We pass HTML as a direct argument. For very large HTML, this might hit command line limits.
          # In a production app, we might want to write to a temp file first.
          case System.cmd("node", [script_path, output_file, html], stderr_to_stdout: true) do
            {_output, 0} ->
              if File.exists?(output_file), do: {:ok, output_file}, else: {:error, :file_not_created}
            {error_output, exit_code} ->
              IO.puts("[Browser] PDF Script failed: #{error_output}")
              {:error, {:script_error, exit_code}}
          end
        rescue
          e -> {:error, {:exception, Exception.message(e)}}
        end
    end
  end

  @doc """
  Get the path to the Chrome/Chromium executable.

  ## Returns
    - Path to Chrome executable if found
    - nil if not found
  """
  def find_chrome do
    # Try common Chrome/Chromium paths
    paths = [
      System.find_executable("google-chrome"),
      System.find_executable("chromium"),
      System.find_executable("chromium-browser"),
      System.find_executable("chrome"),
      "/usr/bin/google-chrome",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser",
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
      System.get_env("CHROME_PATH")
    ]

    Enum.find(paths, fn path -> path && File.exists?(path) end)
  end

  # Private functions

  defp validate_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] do
      {:ok, url}
    else
      {:error, :invalid_url}
    end
  end

  defp validate_url(_), do: {:error, :invalid_url}

  defp run_chrome_screenshot(url, options) do
    output_file = "/tmp/clientats_screenshot_#{System.unique_integer()}.png"

    # Use Playwright script for better page load handling
    script_path = Path.join(:code.priv_dir(:clientats), "../../../scripts/capture_screenshot.js")

    # Fall back to direct script path if priv doesn't work
    script_path =
      if File.exists?(script_path) do
        script_path
      else
        "scripts/capture_screenshot.js"
      end

    case File.exists?(script_path) do
      false ->
        IO.puts(
          "[Browser] Screenshot script not found at #{script_path}. Screenshot capture unavailable."
        )

        {:error, :script_not_found}

      true ->
        IO.puts("[Browser] Capturing screenshot from: #{url}")
        IO.puts("[Browser] Using Playwright script: #{script_path}")
        IO.puts("[Browser] Output file: #{output_file}")

        # Call the Node.js script with timeout
        timeout_ms = options[:timeout] || @default_timeout
        timeout_sec = div(timeout_ms, 1000)

        case run_playwright_script(script_path, url, output_file, timeout_sec) do
          {_output, 0} ->
            if File.exists?(output_file) do
              IO.puts("[Browser] Screenshot saved successfully")
              {:ok, output_file}
            else
              IO.puts("[Browser] Script reported success but file not found")
              {:error, :screenshot_file_not_created}
            end

          {error_output, exit_code} ->
            IO.puts("[Browser] Script failed: #{error_output} (exit code: #{exit_code})")
            {:error, {:script_error, "Exit code: #{exit_code}"}}
        end
    end
  end

  defp run_playwright_script(script_path, url, output_file, _timeout_sec) do
    # Note: System.cmd doesn't support timeout directly in Elixir.
    # The node script has built-in timeouts (30s page load, 15s content wait)
    # For longer timeouts, users can wrap this in Task.async_stream with timeouts
    try do
      System.cmd("node", [script_path, url, output_file], stderr_to_stdout: true)
    catch
      :exit, reason ->
        IO.puts("[Browser] Script command failed: #{inspect(reason)}")
        {"", 1}
    end
  end
end
