defmodule Clientats.Validation do
  @moduledoc """
  Centralized input validation and sanitization for user-provided data.

  Provides functions for validating and sanitizing:
  - URLs (job posting links)
  - Text content (job descriptions, notes)
  - Email addresses
  - File uploads
  - Search queries

  All validation ensures XSS prevention and injection attack prevention.
  """

  @doc """
  Validates and sanitizes a URL for job postings.

  Ensures:
  - Valid HTTP/HTTPS scheme
  - Proper URL structure
  - No malicious content

  Returns:
    - {:ok, sanitized_url} on success
    - {:error, :invalid_url} if validation fails
  """
  @spec validate_url(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def validate_url(url) when is_binary(url) do
    url = String.trim(url)

    cond do
      # Empty
      url == "" -> {:error, :invalid_url}
      # URL with only whitespace
      Regex.match?(~r/^\s+$/, url) -> {:error, :invalid_url}
      # Must start with http:// or https://
      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
        case validate_url_structure(url) do
          true -> {:ok, url}
          false -> {:error, :invalid_url}
        end
      # Reject other schemes
      true -> {:error, :invalid_url}
    end
  end

  def validate_url(_), do: {:error, :invalid_url}

  # Private helper to validate URL structure
  @spec validate_url_structure(String.t()) :: boolean()
  defp validate_url_structure(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
        # Basic hostname validation
        host != "" and String.length(host) > 1 and String.length(host) < 256

      _ ->
        false
    end
  end

  @doc """
  Validates and sanitizes text content (job descriptions, notes, etc.).

  Ensures:
  - Not empty or whitespace only
  - Reasonable length limits
  - No malicious HTML/JavaScript

  Returns:
    - {:ok, sanitized_text} on success
    - {:error, reason} if validation fails
  """
  @spec validate_text(String.t(), opts :: keyword()) :: {:ok, String.t()} | {:error, atom()}
  def validate_text(text, opts \\ [])

  def validate_text(text, opts) when is_binary(text) do
    max_length = Keyword.get(opts, :max_length, 50_000)
    min_length = Keyword.get(opts, :min_length, 1)

    text = String.trim(text)

    cond do
      # Empty or whitespace only
      text == "" -> {:error, :invalid_content}
      # Too short
      String.length(text) < min_length -> {:error, :invalid_content}
      # Too long
      String.length(text) > max_length -> {:error, :content_too_large}
      true -> {:ok, sanitize_text(text)}
    end
  end

  def validate_text(_, _), do: {:error, :invalid_content}

  @doc """
  Sanitizes text to prevent XSS attacks.

  Removes or escapes:
  - Script tags and JavaScript
  - Event handlers (onclick, onload, etc.)
  - Dangerous HTML entities
  - Null bytes

  Returns the sanitized text.
  """
  @spec sanitize_text(String.t()) :: String.t()
  def sanitize_text(text) do
    text
    # Remove null bytes
    |> String.replace("\0", "")
    # Remove script tags and content
    |> remove_script_tags()
    # Remove event handler attributes
    |> remove_event_handlers()
    # Escape HTML entities to prevent XSS
    |> escape_html()
  end

  @doc """
  Validates an email address.

  Returns:
    - {:ok, email} on success (normalized to lowercase)
    - {:error, :invalid_email} if validation fails
  """
  @spec validate_email(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def validate_email(email) when is_binary(email) do
    email = String.trim(email)

    # Basic email validation pattern
    case Regex.match?(~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$/, email) do
      true -> {:ok, String.downcase(email)}
      false -> {:error, :invalid_email}
    end
  end

  def validate_email(_), do: {:error, :invalid_email}

  @doc """
  Validates a search query.

  Ensures:
  - Not empty
  - Reasonable length
  - No SQL injection patterns

  Returns:
    - {:ok, sanitized_query} on success
    - {:error, reason} if validation fails
  """
  @spec validate_search_query(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def validate_search_query(query) when is_binary(query) do
    query = String.trim(query)
    max_length = 200

    cond do
      query == "" -> {:error, :invalid_search_query}
      String.length(query) > max_length -> {:error, :search_query_too_long}
      contains_sql_injection_patterns?(query) -> {:error, :invalid_search_query}
      true -> {:ok, query}
    end
  end

  def validate_search_query(_), do: {:error, :invalid_search_query}

  @doc """
  Validates a file upload.

  Checks:
  - Filename safety
  - File size limits
  - Allowed file types

  Returns:
    - {:ok, sanitized_filename} on success
    - {:error, reason} if validation fails
  """
  @spec validate_file_upload(
          filename :: String.t(),
          size :: integer(),
          allowed_types :: [String.t()]
        ) :: {:ok, String.t()} | {:error, atom()}
  def validate_file_upload(filename, size, allowed_types \\ ["pdf", "doc", "docx"])

  def validate_file_upload(filename, size, allowed_types)
      when is_binary(filename) and is_integer(size) and is_list(allowed_types) do
    max_size = 10 * 1024 * 1024  # 10MB

    cond do
      # Empty filename
      String.trim(filename) == "" -> {:error, :invalid_filename}
      # File too large
      size > max_size -> {:error, :file_too_large}
      # Not allowed type
      not allowed_file_type?(filename, allowed_types) -> {:error, :unsupported_file_type}
      true -> {:ok, sanitize_filename(filename)}
    end
  end

  def validate_file_upload(_, _, _), do: {:error, :invalid_file_upload}

  # Private helpers

  @spec remove_script_tags(String.t()) :: String.t()
  defp remove_script_tags(text) do
    # Remove <script>...</script> tags
    Regex.replace(
      ~r/<script[^>]*>.*?<\/script>/is,
      text,
      ""
    )
  end

  @spec remove_event_handlers(String.t()) :: String.t()
  defp remove_event_handlers(text) do
    # Remove event handler attributes like onclick, onload, etc.
    Regex.replace(
      ~r/\s*on\w+\s*=\s*["'][^"']*["']/i,
      text,
      ""
    )
  end

  @spec escape_html(String.t()) :: String.t()
  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  @spec contains_sql_injection_patterns?(String.t()) :: boolean()
  defp contains_sql_injection_patterns?(query) do
    dangerous_patterns = [
      ~r/(\bDROP\b|\bDELETE\b|\bINSERT\b|\bUPDATE\b|\bEXEC\b|\bSELECT\b)/i,
      ~r/(--|;|\/\*|\*\/)/,
      ~r/('\s*OR\s*'|"\s*OR\s*")/i
    ]

    Enum.any?(dangerous_patterns, fn pattern ->
      Regex.match?(pattern, query)
    end)
  end

  @spec allowed_file_type?(String.t(), [String.t()]) :: boolean()
  defp allowed_file_type?(filename, allowed_types) do
    extension =
      filename
      |> String.split(".")
      |> List.last("")
      |> String.downcase()

    Enum.member?(allowed_types, extension)
  end

  @spec sanitize_filename(String.t()) :: String.t()
  defp sanitize_filename(filename) do
    # Remove path separators and dangerous characters
    filename
    |> String.replace(~r/[\/\\:]/, "_")
    |> String.replace(~r/[^A-Za-z0-9._-]/, "_")
    |> String.slice(0..255)  # Max filename length
  end
end
