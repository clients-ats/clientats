defmodule Clientats.LLM.ErrorHandlerTest do
  use ExUnit.Case

  alias Clientats.LLM.ErrorHandler

  describe "retryable?/1" do
    test "recognizes timeout as retryable" do
      assert ErrorHandler.retryable?(:timeout) == true
      assert ErrorHandler.retryable?({:timeout, "detail"}) == true
    end

    test "recognizes rate limiting as retryable" do
      assert ErrorHandler.retryable?(:rate_limited) == true
      assert ErrorHandler.retryable?({:rate_limited, "detail"}) == true
    end

    test "recognizes server errors (5xx) as retryable" do
      assert ErrorHandler.retryable?({:http_error, 500}) == true
      assert ErrorHandler.retryable?({:http_error, 503}) == true
      assert ErrorHandler.retryable?({:http_error, 502}) == true
    end

    test "recognizes specific status codes as retryable" do
      # Request timeout
      assert ErrorHandler.retryable?({:http_error, 408}) == true
      # Rate limit
      assert ErrorHandler.retryable?({:http_error, 429}) == true
    end

    test "recognizes connection errors as retryable" do
      assert ErrorHandler.retryable?(:unavailable) == true
      assert ErrorHandler.retryable?(:connection_refused) == true
      assert ErrorHandler.retryable?({:connection_error, "detail"}) == true
    end

    test "does not retry permanent errors" do
      assert ErrorHandler.retryable?(:invalid_content) == false
      assert ErrorHandler.retryable?(:content_too_large) == false
      assert ErrorHandler.retryable?(:invalid_url) == false
      assert ErrorHandler.retryable?(:invalid_api_key) == false
      assert ErrorHandler.retryable?(:invalid_response_format) == false
    end

    test "does not retry 4xx client errors (except 408, 429)" do
      assert ErrorHandler.retryable?({:http_error, 400}) == false
      assert ErrorHandler.retryable?({:http_error, 401}) == false
      assert ErrorHandler.retryable?({:http_error, 403}) == false
      assert ErrorHandler.retryable?({:http_error, 404}) == false
    end

    test "does not retry exceptions" do
      assert ErrorHandler.retryable?({:exception, "message"}) == false
    end
  end

  describe "calculate_backoff/2" do
    test "calculates exponential backoff" do
      # Without jitter control, we can only test the base calculation
      # attempt 0: base_delay * 2^0 = 100
      base = ErrorHandler.calculate_backoff(0, 100)
      # With 10% jitter
      assert base >= 100 and base <= 110

      # attempt 1: base_delay * 2^1 = 200
      base = ErrorHandler.calculate_backoff(1, 100)
      assert base >= 200 and base <= 220

      # attempt 2: base_delay * 2^2 = 400
      base = ErrorHandler.calculate_backoff(2, 100)
      assert base >= 400 and base <= 440
    end

    test "uses default base delay" do
      # Default is 100ms
      base = ErrorHandler.calculate_backoff(0)
      assert base >= 100 and base <= 110
    end
  end

  describe "with_retry/2" do
    test "returns ok on first success" do
      fun = fn -> {:ok, :result} end
      assert ErrorHandler.with_retry(fun) == {:ok, :result}
    end

    test "retries on retryable error" do
      # Use a mutable counter via a process
      {:ok, counter_pid} = Agent.start_link(fn -> 0 end)

      fun = fn ->
        count = Agent.get_and_update(counter_pid, fn c -> {c, c + 1} end)

        if count < 2 do
          {:error, :timeout}
        else
          {:ok, :success}
        end
      end

      # With 3 retries, should succeed on 3rd attempt (count = 2)
      assert ErrorHandler.with_retry(fun, max_retries: 3) == {:ok, :success}

      Agent.stop(counter_pid)
    end

    test "returns error after max retries exceeded" do
      fun = fn -> {:error, :timeout} end
      result = ErrorHandler.with_retry(fun, max_retries: 2)
      assert {:error, :timeout} = result
    end

    test "does not retry permanent errors" do
      fun = fn -> {:error, :invalid_content} end
      result = ErrorHandler.with_retry(fun, max_retries: 3)
      assert {:error, :invalid_content} = result
    end

    test "uses custom retryable function" do
      fun = fn -> {:error, :custom_error} end
      custom_retryable = fn _ -> false end

      result = ErrorHandler.with_retry(fun, max_retries: 3, retryable: custom_retryable)
      assert {:error, :custom_error} = result
    end
  end

  describe "user_friendly_message/1" do
    test "provides friendly messages for common errors" do
      assert ErrorHandler.user_friendly_message(:timeout) =~ "timed out"
      assert ErrorHandler.user_friendly_message(:rate_limited) =~ "Rate limited"
      assert ErrorHandler.user_friendly_message(:invalid_api_key) =~ "Invalid API key"
      assert ErrorHandler.user_friendly_message(:auth_error) =~ "Authentication"
      assert ErrorHandler.user_friendly_message(:invalid_url) =~ "Invalid URL"
      assert ErrorHandler.user_friendly_message(:content_too_large) =~ "too large"
    end

    test "handles HTTP status codes" do
      assert ErrorHandler.user_friendly_message({:http_error, 404}) =~ "not found"
      assert ErrorHandler.user_friendly_message({:http_error, 403}) =~ "denied"
      assert ErrorHandler.user_friendly_message({:http_error, 500}) =~ "error"
    end

    test "returns string messages as-is" do
      msg = "Custom error message"
      assert ErrorHandler.user_friendly_message(msg) == msg
    end
  end

  describe "normalize_error/1" do
    test "normalizes different error formats" do
      {type, msg} = ErrorHandler.normalize_error({:http_error, 500})
      assert type == :http_error
      assert msg =~ "HTTP"

      {type, msg} = ErrorHandler.normalize_error({:exception, "test"})
      assert type == :exception
      assert msg == "test"

      {type, _msg} = ErrorHandler.normalize_error(:timeout)
      assert type == :timeout
    end
  end

  describe "error_context/2" do
    test "creates error context with metadata" do
      error = :timeout
      context = ErrorHandler.error_context(error, %{url: "test"})

      assert context[:error] == :timeout
      assert context[:retryable] == true
      assert context[:user_message] =~ "timed out"
      assert context[:url] == "test"
      assert Map.has_key?(context, :timestamp)
    end
  end
end
