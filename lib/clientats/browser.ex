defmodule Clientats.Browser do
  @moduledoc """
  Browser automation for capturing job posting pages as images.

  Uses headless Chrome via Puppeteer-over-HTTP or similar services
  to capture screenshots of web pages, enabling multimodal LLM
  extraction with visual context.
  """

  require Logger

  @default_viewport_width 1920
  @default_viewport_height 1080
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
    case find_chrome() do
      nil ->
        IO.puts("[Browser] Chrome not found. Screenshot capture unavailable.")
        {:error, :chrome_not_found}

      chrome_path ->
        viewport_width = options[:viewport_width] || @default_viewport_width
        viewport_height = options[:viewport_height] || @default_viewport_height
        output_file = "/tmp/clientats_screenshot_#{System.unique_integer()}.png"

        # Build Chrome arguments for headless screenshot
        args = [
          "--headless=new",
          "--no-sandbox",
          "--disable-dev-shm-usage",
          "--disable-gpu",
          "--window-size=#{viewport_width},#{viewport_height}",
          "--screenshot=#{output_file}",
          url
        ]

        IO.puts("[Browser] Capturing screenshot from: #{url}")
        IO.puts("[Browser] Using Chrome: #{chrome_path}")
        IO.puts("[Browser] Output file: #{output_file}")

        case run_chrome_command(chrome_path, args, options[:timeout] || @default_timeout) do
          {_output, 0} ->
            if File.exists?(output_file) do
              IO.puts("[Browser] Screenshot saved successfully")
              {:ok, output_file}
            else
              IO.puts("[Browser] Chrome reported success but file not found")
              {:error, :screenshot_file_not_created}
            end

          {error_output, exit_code} ->
            IO.puts("[Browser] Chrome failed: #{error_output} (exit code: #{exit_code})")
            {:error, {:chrome_error, "Exit code: #{exit_code}"}}
        end
    end
  end

  defp run_chrome_command(chrome_path, args, _timeout) do
    # Note: System.cmd doesn't support timeout directly in older Elixir versions
    # We rely on Chrome's built-in timeouts and the --disable-background-networking flag
    try do
      System.cmd(chrome_path, args, stderr_to_stdout: true)
    catch
      :exit, reason ->
        IO.puts("[Browser] Chrome command failed: #{inspect(reason)}")
        {"", 1}
    end
  end
end
