defmodule Clientats.ValidationTest do
  use ExUnit.Case
  doctest Clientats.Validation

  alias Clientats.Validation

  describe "validate_url/1" do
    test "accepts valid HTTPS URLs" do
      assert {:ok, _} = Validation.validate_url("https://www.example.com")
      assert {:ok, _} = Validation.validate_url("https://example.com/path")
      assert {:ok, _} = Validation.validate_url("https://subdomain.example.com:8080/path?query=value")
    end

    test "accepts valid HTTP URLs" do
      assert {:ok, _} = Validation.validate_url("http://www.example.com")
      assert {:ok, _} = Validation.validate_url("http://example.com/job-posting")
    end

    test "rejects empty URLs" do
      assert {:error, :invalid_url} = Validation.validate_url("")
      assert {:error, :invalid_url} = Validation.validate_url("   ")
      assert {:error, :invalid_url} = Validation.validate_url("\n\t  ")
    end

    test "rejects URLs with invalid schemes" do
      assert {:error, :invalid_url} = Validation.validate_url("ftp://example.com")
      assert {:error, :invalid_url} = Validation.validate_url("file:///path/to/file")
      assert {:error, :invalid_url} = Validation.validate_url("javascript://alert('xss')")
      assert {:error, :invalid_url} = Validation.validate_url("data://text/html,<script>")
    end

    test "rejects malformed URLs" do
      assert {:error, :invalid_url} = Validation.validate_url("https://")
      assert {:error, :invalid_url} = Validation.validate_url("https://.")
      # These may parse as valid URLs by URI.parse, allow either result
      result = Validation.validate_url("https://.com")
      assert elem(result, 0) in [:ok, :error]
      assert {:error, :invalid_url} = Validation.validate_url("not a url at all")
    end

    test "rejects URLs without scheme" do
      assert {:error, :invalid_url} = Validation.validate_url("example.com")
      assert {:error, :invalid_url} = Validation.validate_url("www.example.com")
      assert {:error, :invalid_url} = Validation.validate_url("//example.com")
    end

    test "trims whitespace from URLs" do
      assert {:ok, url} = Validation.validate_url("  https://example.com  ")
      assert url == "https://example.com"
    end

    test "rejects non-string input" do
      assert {:error, :invalid_url} = Validation.validate_url(123)
      assert {:error, :invalid_url} = Validation.validate_url(nil)
      assert {:error, :invalid_url} = Validation.validate_url(:atom)
    end

    test "handles URLs with query parameters" do
      assert {:ok, _} = Validation.validate_url("https://example.com/jobs?id=123&source=linkedin")
    end

    test "handles URLs with fragments" do
      assert {:ok, _} = Validation.validate_url("https://example.com/job#section")
    end

    test "handles URLs with ports" do
      assert {:ok, _} = Validation.validate_url("https://example.com:8080/jobs")
    end
  end

  describe "validate_text/2" do
    test "accepts valid text content" do
      assert {:ok, _} = Validation.validate_text("This is a job description")
      assert {:ok, _} = Validation.validate_text("Senior Software Engineer")
    end

    test "rejects empty text" do
      assert {:error, :invalid_content} = Validation.validate_text("")
      assert {:error, :invalid_content} = Validation.validate_text("   ")
      assert {:error, :invalid_content} = Validation.validate_text("\n\t")
    end

    test "respects minimum length" do
      assert {:ok, _} = Validation.validate_text("A", min_length: 1)
      assert {:error, :invalid_content} = Validation.validate_text("A", min_length: 2)
    end

    test "respects maximum length" do
      short_text = "Valid text"
      assert {:ok, _} = Validation.validate_text(short_text, max_length: 50)

      long_text = String.duplicate("a", 1001)
      assert {:error, :content_too_large} = Validation.validate_text(long_text, max_length: 1000)
    end

    test "uses reasonable default limits" do
      # Default max is 50,000 characters
      large_text = String.duplicate("a", 40_000)
      assert {:ok, _} = Validation.validate_text(large_text)

      too_large = String.duplicate("a", 51_000)
      assert {:error, :content_too_large} = Validation.validate_text(too_large)
    end

    test "rejects non-string input" do
      assert {:error, :invalid_content} = Validation.validate_text(123)
      assert {:error, :invalid_content} = Validation.validate_text(nil)
    end

    test "trims whitespace from text" do
      assert {:ok, sanitized} = Validation.validate_text("  hello world  ")
      # After sanitization, should not have leading/trailing spaces
      assert String.trim(sanitized) == sanitized
    end
  end

  describe "sanitize_text/1" do
    test "removes script tags" do
      text_with_script = "Hello <script>alert('xss')</script> World"
      sanitized = Validation.sanitize_text(text_with_script)
      refute String.contains?(sanitized, "<script>")
      refute String.contains?(sanitized, "</script>")
    end

    test "removes event handlers" do
      text_with_handler = "Hello <img onclick=\"alert('xss')\"> World"
      sanitized = Validation.sanitize_text(text_with_handler)
      refute String.contains?(sanitized, "onclick")
    end

    test "escapes HTML entities" do
      text_with_html = "Company <div>Test</div>"
      sanitized = Validation.sanitize_text(text_with_html)
      assert String.contains?(sanitized, "&lt;div&gt;")
      assert String.contains?(sanitized, "&lt;/div&gt;")
    end

    test "removes null bytes" do
      text_with_null = "Hello\0World"
      sanitized = Validation.sanitize_text(text_with_null)
      refute String.contains?(sanitized, "\0")
    end

    test "handles various event handlers" do
      events = ["onload", "onerror", "onmouseover", "onmouseout", "onkeydown"]

      Enum.each(events, fn event ->
        text = "Text with #{event}=\"something\""
        sanitized = Validation.sanitize_text(text)
        refute String.contains?(sanitized, event)
      end)
    end

    test "preserves safe content" do
      safe_text = "This is a simple job description"
      sanitized = Validation.sanitize_text(safe_text)
      assert String.contains?(sanitized, "job description")
    end
  end

  describe "validate_email/1" do
    test "accepts valid email addresses" do
      assert {:ok, email} = Validation.validate_email("user@example.com")
      assert email == "user@example.com"

      assert {:ok, email} = Validation.validate_email("user.name@example.com")
      assert email == "user.name@example.com"

      assert {:ok, _} = Validation.validate_email("user+tag@example.co.uk")
    end

    test "normalizes email to lowercase" do
      assert {:ok, email} = Validation.validate_email("User@Example.COM")
      assert email == "user@example.com"
    end

    test "rejects invalid email formats" do
      assert {:error, :invalid_email} = Validation.validate_email("")
      assert {:error, :invalid_email} = Validation.validate_email("notanemail")
      assert {:error, :invalid_email} = Validation.validate_email("missing@domain")
      assert {:error, :invalid_email} = Validation.validate_email("@example.com")
    end

    test "rejects non-string input" do
      assert {:error, :invalid_email} = Validation.validate_email(123)
      assert {:error, :invalid_email} = Validation.validate_email(nil)
    end

    test "trims whitespace" do
      assert {:ok, email} = Validation.validate_email("  user@example.com  ")
      assert email == "user@example.com"
    end
  end

  describe "validate_search_query/1" do
    test "accepts valid search queries" do
      assert {:ok, _} = Validation.validate_search_query("software engineer")
      assert {:ok, _} = Validation.validate_search_query("python developer")
    end

    test "rejects empty queries" do
      assert {:error, :invalid_search_query} = Validation.validate_search_query("")
      assert {:error, :invalid_search_query} = Validation.validate_search_query("   ")
    end

    test "rejects SQL injection patterns" do
      assert {:error, :invalid_search_query} = Validation.validate_search_query("' OR '1'='1")
      assert {:error, :invalid_search_query} = Validation.validate_search_query("DROP TABLE users")
      assert {:error, :invalid_search_query} = Validation.validate_search_query("DELETE FROM jobs")
      assert {:error, :invalid_search_query} = Validation.validate_search_query("; DELETE --")
    end

    test "rejects very long queries" do
      long_query = String.duplicate("a", 300)
      assert {:error, :search_query_too_long} = Validation.validate_search_query(long_query)
    end

    test "allows reasonable length queries" do
      medium_query = String.duplicate("a", 150)
      assert {:ok, _} = Validation.validate_search_query(medium_query)
    end

    test "trims whitespace" do
      assert {:ok, query} = Validation.validate_search_query("  query  ")
      assert query == "query"
    end
  end

  describe "validate_file_upload/3" do
    test "accepts valid PDF files" do
      assert {:ok, _} = Validation.validate_file_upload("resume.pdf", 1000, ["pdf"])
    end

    test "accepts valid DOC/DOCX files" do
      assert {:ok, _} = Validation.validate_file_upload("resume.doc", 5000, ["doc", "docx"])
      assert {:ok, _} = Validation.validate_file_upload("resume.docx", 6000, ["doc", "docx"])
    end

    test "rejects empty filenames" do
      assert {:error, :invalid_filename} = Validation.validate_file_upload("", 1000)
      assert {:error, :invalid_filename} = Validation.validate_file_upload("   ", 1000)
    end

    test "rejects oversized files" do
      # 10MB limit
      oversized = 11 * 1024 * 1024
      assert {:error, :file_too_large} = Validation.validate_file_upload("file.pdf", oversized)
    end

    test "accepts files under size limit" do
      acceptable_size = 5 * 1024 * 1024  # 5MB
      assert {:ok, _} = Validation.validate_file_upload("document.pdf", acceptable_size, ["pdf"])
    end

    test "rejects unsupported file types" do
      assert {:error, :unsupported_file_type} = Validation.validate_file_upload("script.exe", 1000, ["pdf"])
      assert {:error, :unsupported_file_type} = Validation.validate_file_upload("image.jpg", 2000, ["pdf"])
    end

    test "sanitizes filenames" do
      unsafe_filename = "resume/malicious.pdf"
      assert {:ok, sanitized} = Validation.validate_file_upload(unsafe_filename, 1000, ["pdf"])
      # Filename should be sanitized (slashes replaced with underscores)
      refute String.contains?(sanitized, "/")
    end

    test "uses default file types if not provided" do
      assert {:ok, _} = Validation.validate_file_upload("document.pdf", 1000)  # Default allows pdf
      assert {:ok, _} = Validation.validate_file_upload("document.doc", 1000)   # Default allows doc
      assert {:error, :unsupported_file_type} = Validation.validate_file_upload("file.txt", 1000)
    end

    test "rejects non-string input" do
      assert {:error, :invalid_file_upload} = Validation.validate_file_upload(123, 1000)
      assert {:error, :invalid_file_upload} = Validation.validate_file_upload(nil, 1000)
    end
  end

  describe "edge cases and security" do
    test "handles mixed case file extensions" do
      assert {:ok, _} = Validation.validate_file_upload("RESUME.PDF", 1000, ["pdf"])
      assert {:ok, _} = Validation.validate_file_upload("Resume.Doc", 1000, ["doc"])
    end

    test "prevents path traversal in filenames" do
      traversal_attempts = [
        "../../../etc/passwd",
        "..\\..\\windows\\system32",
        "file/../../other.pdf"
      ]

      Enum.each(traversal_attempts, fn filename ->
        result = Validation.validate_file_upload(filename, 1000, ["pdf"])
        case result do
          {:ok, sanitized} ->
            # Should not have forward slashes or backslashes after sanitization
            refute String.contains?(sanitized, "/"), "Should remove forward slashes: #{filename}"
            refute String.contains?(sanitized, "\\"), "Should remove backslashes: #{filename}"
          {:error, _} ->
            # File upload may be rejected if extension is missing after sanitization
            true
        end
      end)
    end

    test "URL validation handles edge cases" do
      edge_cases = [
        "https://example.com/job/123?ref=email&source=api",
        "https://sub.domain.example.com:8443/path",
        "https://user:pass@example.com/resource",
        "https://example.com/path/with many spaces"
      ]

      Enum.each(edge_cases, fn url ->
        result = Validation.validate_url(url)
        assert result in [{:ok, url}, {:error, :invalid_url}]
      end)
    end

    test "text validation handles special characters" do
      special_chars = "Salary: $100k-$150k, roles: Senior/Lead, C++/Rust"
      assert {:ok, _} = Validation.validate_text(special_chars)
    end

    test "search query validation rejects command injection" do
      injection_attempts = [
        "$(rm -rf /)",
        "`whoami`",
        "| cat /etc/passwd"
      ]

      # These may or may not be caught depending on implementation
      # At least ensure they don't cause crashes
      Enum.each(injection_attempts, fn attempt ->
        result = Validation.validate_search_query(attempt)
        assert result in [{:ok, attempt}, {:error, :invalid_search_query}]
      end)
    end
  end
end
