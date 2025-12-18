defmodule ScreenshotMockTest do
  use ExUnit.Case

  describe "generate_mock_screenshot/1" do
    test "generates a PNG file for generic scenario" do
      filename = ScreenshotMock.generate_mock_screenshot(:generic)
      assert File.exists?(filename)
      assert String.ends_with?(filename, ".png")

      # Verify it's a valid PNG file (has PNG signature)
      {:ok, content} = File.read(filename)
      assert String.starts_with?(content, <<137, 80, 78, 71>>)

      # Cleanup
      ScreenshotMock.cleanup_screenshot(filename)
      refute File.exists?(filename)
    end

    test "generates different files for different scenarios" do
      file1 = ScreenshotMock.generate_mock_screenshot(:linkedin)
      file2 = ScreenshotMock.generate_mock_screenshot(:indeed)

      assert file1 != file2
      assert File.exists?(file1)
      assert File.exists?(file2)

      ScreenshotMock.cleanup_screenshot(file1)
      ScreenshotMock.cleanup_screenshot(file2)
    end

    test "default scenario generates a file" do
      filename = ScreenshotMock.generate_mock_screenshot()
      assert File.exists?(filename)

      ScreenshotMock.cleanup_screenshot(filename)
      refute File.exists?(filename)
    end
  end

  describe "cleanup_screenshot/1" do
    test "removes screenshot file" do
      filename = ScreenshotMock.generate_mock_screenshot()
      assert File.exists?(filename)

      ScreenshotMock.cleanup_screenshot(filename)
      refute File.exists?(filename)
    end

    test "handles non-existent files gracefully" do
      assert :ok = ScreenshotMock.cleanup_screenshot("/nonexistent/file.png")
    end
  end

  describe "get_screenshot_content/1" do
    test "returns LinkedIn job posting content" do
      content = ScreenshotMock.get_screenshot_content(:linkedin)
      assert String.contains?(content, "LinkedIn")
      assert String.contains?(content, "Senior Software Engineer")
      assert String.contains?(content, "San Francisco")
    end

    test "returns Indeed job posting content" do
      content = ScreenshotMock.get_screenshot_content(:indeed)
      assert String.contains?(content, "Indeed")
      assert String.contains?(content, "Backend Engineer")
      assert String.contains?(content, "Austin")
    end

    test "returns Glassdoor job posting content" do
      content = ScreenshotMock.get_screenshot_content(:glassdoor)
      assert String.contains?(content, "Glassdoor")
      assert String.contains?(content, "Full Stack")
      assert String.contains?(content, "New York")
    end

    test "returns generic job posting content" do
      content = ScreenshotMock.get_screenshot_content(:generic)
      assert String.contains?(content, "Software Engineer")
      assert String.contains?(content, "Remote")
    end

    test "returns minimal job posting content" do
      content = ScreenshotMock.get_screenshot_content(:minimal)
      assert String.contains?(content, "QA Engineer")
      assert String.contains?(content, "Boston")
    end

    test "defaults to generic for unknown scenarios" do
      content = ScreenshotMock.get_screenshot_content(:unknown)
      assert String.contains?(content, "Software Engineer")
    end

    test "all scenarios return non-empty strings" do
      scenarios = [:linkedin, :indeed, :glassdoor, :generic, :minimal]

      Enum.each(scenarios, fn scenario ->
        content = ScreenshotMock.get_screenshot_content(scenario)
        assert is_binary(content)
        assert byte_size(content) > 0
      end)
    end
  end
end
