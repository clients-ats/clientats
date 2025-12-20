defmodule Clientats.LLM.ErrorHandler do
  @moduledoc """
  Centralized error handling for LLM operations.

  Provides:
  - Error classification (retryable vs permanent)
  - User-friendly error messages
  - Retry logic with exponential backoff
  - Detailed error context preservation
  """

  @type error_reason :: atom() | {atom(), any()} | String.t()
  @type retry_config :: %{max_retries: integer(), base_delay: integer()}

  # milliseconds
  @default_base_delay 100
  @default_max_retries 3

  @doc """
  Determine if an error is retryable (temporary failure vs permanent).

  Retryable errors:
  - :timeout - Connection timeout
  - :rate_limited - HTTP 429
  - :auth_error - Transient auth issues (but not invalid API key)
  - :http_error with status 5xx - Server errors
  - :connection_refused - Network issue
  - :unavailable - Service temporarily down

  Permanent errors (should NOT retry):
  - :invalid_content - Bad input data
  - :content_too_large - Content exceeds limits
  - :invalid_url - Bad URL format
  - :invalid_api_key - Wrong credentials
  - :invalid_response_format - Response parsing issue
  - :http_error with status 4xx (except 429) - Client errors
  """
  @spec retryable?({atom(), any()} | atom()) :: boolean()
  def retryable?(:timeout), do: true
  def retryable?(:rate_limited), do: true
  def retryable?(:unavailable), do: true
  def retryable?(:connection_refused), do: true
  def retryable?(:unsupported_for_screenshot), do: true
  def retryable?({:timeout, _}), do: true
  def retryable?({:rate_limited, _}), do: true
  def retryable?({:http_error, status}) when status >= 500, do: true
  def retryable?({:http_error, status}) when status in [408, 429], do: true
  def retryable?({:connection_error, _}), do: true
  def retryable?({:exception, _}), do: false
  def retryable?(:invalid_content), do: false
  def retryable?(:content_too_large), do: false
  def retryable?(:invalid_url), do: false
  def retryable?(:invalid_api_key), do: false
  def retryable?(:invalid_response_format), do: false
  def retryable?(_), do: false

  @doc """
  Calculate exponential backoff delay in milliseconds.

  Formula: base_delay * (2 ^ attempt_number) + jitter
  Example: attempt 0 = 100ms, attempt 1 = 200ms, attempt 2 = 400ms (plus up to 10% jitter)
  """
  @spec calculate_backoff(non_neg_integer(), integer()) :: integer()
  def calculate_backoff(attempt, base_delay \\ @default_base_delay) when attempt >= 0 do
    delay = base_delay * Integer.pow(2, attempt)
    jitter = :rand.uniform(max(1, div(delay, 10)))
    delay + jitter
  end

  @doc """
  Retry a function with exponential backoff.

  ## Options
    - max_retries: Maximum number of retry attempts (default: 3)
    - base_delay: Base delay in milliseconds (default: 100)
    - retryable: Custom function to determine if error is retryable
  """
  @spec with_retry(
          function :: (-> {:ok, any()} | {:error, any()}),
          options :: Keyword.t()
        ) :: {:ok, any()} | {:error, any()}
  def with_retry(fun, options \\ []) do
    max_retries = Keyword.get(options, :max_retries, @default_max_retries)
    base_delay = Keyword.get(options, :base_delay, @default_base_delay)
    retryable_fn = Keyword.get(options, :retryable, &retryable?/1)

    do_retry(fun, 0, max_retries, base_delay, retryable_fn)
  end

  @doc """
  Convert error to user-friendly message suitable for display.
  """
  @spec user_friendly_message({atom(), any()} | atom() | String.t()) :: String.t()
  def user_friendly_message(:timeout), do: "Request timed out. Please try again."
  def user_friendly_message({:timeout, _}), do: "Request timed out. Please try again."

  def user_friendly_message(:rate_limited),
    do: "Rate limited. Please wait a moment and try again."

  def user_friendly_message({:rate_limited, _}),
    do: "Rate limited. Please wait a moment and try again."

  def user_friendly_message(:invalid_api_key), do: "Invalid API key or credentials."
  def user_friendly_message(:auth_error), do: "Authentication failed. Please check your API key."

  def user_friendly_message({:auth_error, _}),
    do: "Authentication failed. Please check your API key."

  def user_friendly_message(:invalid_url), do: "Invalid URL format. Please check and try again."

  def user_friendly_message(:content_too_large),
    do: "Job posting content is too large. Please try a different page."

  def user_friendly_message(:invalid_content),
    do: "Could not extract job data. Page may not be a valid job posting."

  def user_friendly_message(:unavailable),
    do: "Service is temporarily unavailable. Please try again shortly."

  def user_friendly_message({:unavailable, _}),
    do: "Service is temporarily unavailable. Please try again shortly."

  def user_friendly_message(:connection_refused),
    do: "Cannot connect to service. Please check your connection."

  def user_friendly_message({:connection_error, _}), do: "Connection error. Please try again."

  def user_friendly_message(:all_providers_failed),
    do: "All LLM providers are currently unavailable. Please use the manual entry form below."

  def user_friendly_message({:http_error, 404}), do: "Job page not found. Please verify the URL."

  def user_friendly_message({:http_error, 403}),
    do: "Access denied. You may need to update cookies or authentication."

  def user_friendly_message({:http_error, 500}), do: "Server error. Please try again in a moment."

  def user_friendly_message({:http_error, status}) when status >= 500,
    do: "Service error (#{status}). Please try again."

  def user_friendly_message({:http_error, status}) when status >= 400, do: "Error: HTTP #{status}"

  def user_friendly_message({:parse_error, _}),
    do: "Could not parse job data. The page format may not be supported."

  def user_friendly_message({:exception, msg}), do: "Unexpected error: #{msg}"
  def user_friendly_message(msg) when is_binary(msg), do: msg
  def user_friendly_message(other), do: "An unexpected error occurred: #{inspect(other)}"

  @doc """
  Get error details for improved fallback UI with provider info and recovery steps.
  """
  @spec error_details({atom(), any()} | atom() | String.t()) :: map()
  def error_details(error) do
    %{
      user_message: user_friendly_message(error),
      error_type: classify_error(error),
      retryable: retryable?(error),
      recovery_steps: recovery_steps(error),
      error_raw: error
    }
  end

  @spec classify_error({atom(), any()} | atom() | String.t()) :: atom()
  defp classify_error(:timeout), do: :provider_timeout
  defp classify_error({:timeout, _}), do: :provider_timeout
  defp classify_error(:rate_limited), do: :rate_limited
  defp classify_error({:rate_limited, _}), do: :rate_limited
  defp classify_error(:invalid_api_key), do: :auth_config_issue
  defp classify_error(:auth_error), do: :auth_config_issue
  defp classify_error({:auth_error, _}), do: :auth_config_issue
  defp classify_error(:invalid_url), do: :bad_input
  defp classify_error(:content_too_large), do: :bad_input
  defp classify_error(:invalid_content), do: :unsupported_page
  defp classify_error(:unavailable), do: :provider_unavailable
  defp classify_error({:unavailable, _}), do: :provider_unavailable
  defp classify_error(:connection_refused), do: :provider_unavailable
  defp classify_error({:connection_error, _}), do: :provider_unavailable
  defp classify_error(:all_providers_failed), do: :all_failed
  defp classify_error({:http_error, status}) when status >= 500, do: :provider_error
  defp classify_error({:http_error, _}), do: :page_error
  defp classify_error({:parse_error, _}), do: :unsupported_page
  defp classify_error({:exception, _}), do: :unexpected_error
  defp classify_error(_), do: :unknown_error

  @spec recovery_steps({atom(), any()} | atom() | String.t()) :: list(String.t())
  defp recovery_steps(:all_providers_failed) do
    [
      "Use the manual form below to enter job details yourself",
      "Or verify your LLM provider configuration and try again",
      "Check the LLM Configuration page to update your settings"
    ]
  end

  defp recovery_steps(:invalid_api_key) do
    [
      "Visit the LLM Configuration page",
      "Verify your API key is correct",
      "Make sure the API key has not expired"
    ]
  end

  defp recovery_steps(:connection_refused) do
    [
      "Check if Ollama is running (if using local provider)",
      "Verify network connectivity",
      "Try a different provider if available"
    ]
  end

  defp recovery_steps(:timeout) do
    [
      "The provider was too slow to respond",
      "Wait a moment and try again",
      "Or use the manual form to enter details directly"
    ]
  end

  defp recovery_steps(:unsupported_page) do
    [
      "This page might not be a valid job posting",
      "Try copying the text and using the manual form",
      "Or check if the job board is supported"
    ]
  end

  defp recovery_steps(_) do
    [
      "Try again in a moment",
      "Use the manual form to enter details yourself",
      "Visit LLM Configuration to check provider settings"
    ]
  end

  @doc """
  Create detailed error context for logging.
  """
  @spec error_context(
          error :: {atom(), any()} | atom() | String.t(),
          context :: map()
        ) :: map()
  def error_context(error, context \\ %{}) do
    Map.merge(context, %{
      error: error,
      retryable: retryable?(error),
      user_message: user_friendly_message(error),
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Normalize different error types to a standard format.
  """
  @spec normalize_error(any()) :: {atom(), String.t()}
  def normalize_error({:http_error, status}), do: {:http_error, "HTTP #{status}"}
  def normalize_error({:exception, msg}), do: {:exception, msg}
  def normalize_error({:parse_error, msg}), do: {:parse_error, msg}
  def normalize_error({type, details}) when is_atom(type), do: {type, inspect(details)}
  def normalize_error(atom) when is_atom(atom), do: {atom, atom_to_string(atom)}
  def normalize_error(msg) when is_binary(msg), do: {:error, msg}
  def normalize_error(other), do: {:error, inspect(other)}

  # Private functions

  defp do_retry(fun, attempt, max_retries, _base_delay, _retryable_fn)
       when attempt > max_retries do
    fun.()
  end

  defp do_retry(fun, attempt, max_retries, base_delay, retryable_fn) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} = error ->
        if retryable_fn.(reason) and attempt < max_retries do
          delay = calculate_backoff(attempt, base_delay)
          Process.sleep(delay)
          do_retry(fun, attempt + 1, max_retries, base_delay, retryable_fn)
        else
          error
        end
    end
  end

  defp atom_to_string(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
