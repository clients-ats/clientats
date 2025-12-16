defmodule Clientats.LLM.Metrics do
  @moduledoc """
  Prometheus metrics collection for LLM operations and performance monitoring.

  Tracks:
  - LLM API response times and success rates
  - Cache hit/miss ratios
  - Extraction success rates
  - Circuit breaker state changes
  - Provider availability and latency
  - Token usage per provider
  """

  require Logger

  # Metrics registration
  def setup do
    :prometheus_registry.register_metric(
      :prometheus_counter,
      {:name, :llm_api_calls_total},
      help: "Total number of LLM API calls",
      labels: [:provider, :model, :status]
    )

    :prometheus_registry.register_metric(
      :prometheus_histogram,
      {:name, :llm_api_duration_ms},
      help: "LLM API response time in milliseconds",
      labels: [:provider, :model],
      buckets: [10, 50, 100, 500, 1000, 5000, 10000, 30000]
    )

    :prometheus_registry.register_metric(
      :prometheus_counter,
      {:name, :llm_cache_hits_total},
      help: "Total cache hits for LLM results",
      labels: [:provider]
    )

    :prometheus_registry.register_metric(
      :prometheus_counter,
      {:name, :llm_cache_misses_total},
      help: "Total cache misses for LLM results",
      labels: [:provider]
    )

    :prometheus_registry.register_metric(
      :prometheus_gauge,
      {:name, :llm_cache_hit_ratio},
      help: "Cache hit ratio (0.0 to 1.0)",
      labels: [:provider]
    )

    :prometheus_registry.register_metric(
      :prometheus_counter,
      {:name, :llm_extraction_total},
      help: "Total extraction attempts",
      labels: [:provider, :mode, :status]
    )

    :prometheus_registry.register_metric(
      :prometheus_counter,
      {:name, :llm_circuit_breaker_state_changes_total},
      help: "Circuit breaker state transitions",
      labels: [:provider, :from_state, :to_state]
    )

    :prometheus_registry.register_metric(
      :prometheus_gauge,
      {:name, :llm_provider_available},
      help: "Provider availability (1 = available, 0 = unavailable)",
      labels: [:provider]
    )

    :prometheus_registry.register_metric(
      :prometheus_counter,
      {:name, :llm_tokens_used_total},
      help: "Total tokens used by provider",
      labels: [:provider, :model, :token_type]
    )

    :prometheus_registry.register_metric(
      :prometheus_gauge,
      {:name, :llm_provider_latency_p95_ms},
      help: "95th percentile latency for provider in milliseconds",
      labels: [:provider]
    )

    :prometheus_registry.register_metric(
      :prometheus_counter,
      {:name, :llm_errors_total},
      help: "Total errors by type and provider",
      labels: [:provider, :error_type, :retryable]
    )

    :prometheus_registry.register_metric(
      :prometheus_gauge,
      {:name, :llm_active_requests},
      help: "Current number of active LLM requests",
      labels: [:provider]
    )

    Logger.info("LLM Prometheus metrics initialized")
  end

  # Counter increments
  def inc_api_call(provider, model, status) do
    increment_counter(:llm_api_calls_total, [provider, model, status])
  end

  def inc_cache_hit(provider) do
    increment_counter(:llm_cache_hits_total, [provider])
    update_cache_hit_ratio(provider)
  end

  def inc_cache_miss(provider) do
    increment_counter(:llm_cache_misses_total, [provider])
    update_cache_hit_ratio(provider)
  end

  def inc_extraction(provider, mode, status) do
    increment_counter(:llm_extraction_total, [provider, mode, status])
  end

  def inc_circuit_breaker_transition(provider, from_state, to_state) do
    increment_counter(:llm_circuit_breaker_state_changes_total, [provider, from_state, to_state])
  end

  def inc_error(provider, error_type, retryable) do
    retryable_str = if retryable, do: "true", else: "false"
    increment_counter(:llm_errors_total, [provider, error_type, retryable_str])
  end

  def inc_tokens(provider, model, token_type, count) do
    :prometheus_counter.inc(
      :llm_tokens_used_total,
      [provider, model, token_type],
      count
    )
  end

  # Gauge updates
  def set_provider_available(provider, available) do
    value = if available, do: 1, else: 0
    :prometheus_gauge.set(:llm_provider_available, [provider], value)
  end

  def set_active_requests(provider, count) do
    :prometheus_gauge.set(:llm_active_requests, [provider], count)
  end

  def set_latency_p95(provider, latency_ms) do
    :prometheus_gauge.set(:llm_provider_latency_p95_ms, [provider], latency_ms)
  end

  # Histogram observation
  def observe_api_duration(provider, model, duration_ms) do
    :prometheus_histogram.observe(:llm_api_duration_ms, [provider, model], duration_ms)
  end

  # Helper functions
  defp increment_counter(metric, labels) do
    try do
      :prometheus_counter.inc(metric, labels, 1)
    rescue
      e ->
        Logger.warning("Failed to increment counter #{metric}: #{inspect(e)}")
    end
  end

  defp update_cache_hit_ratio(provider) do
    try do
      hits = get_counter_value(:llm_cache_hits_total, [provider])
      misses = get_counter_value(:llm_cache_misses_total, [provider])
      total = hits + misses

      ratio =
        if total > 0 do
          hits / total
        else
          0.0
        end

      :prometheus_gauge.set(:llm_cache_hit_ratio, [provider], ratio)
    rescue
      _ -> :ok
    end
  end

  defp get_counter_value(metric, labels) do
    case :prometheus_counter.value(metric, labels) do
      value when is_number(value) -> value
      _ -> 0
    end
  end

  @doc """
  Track API call with timing and result.
  Returns the result unchanged for composition.
  """
  def track_api_call(provider, model, status, duration_ms, result) do
    inc_api_call(provider, model, status)
    observe_api_duration(provider, model, duration_ms)
    result
  end

  @doc """
  Track extraction with timing.
  Returns the result unchanged for composition.
  """
  def track_extraction(provider, mode, status, duration_ms, result) do
    inc_extraction(provider, mode, status)
    observe_api_duration(provider, mode, duration_ms)
    result
  end

  @doc """
  Start tracking an active request.
  Returns a handle to decrement when done.
  """
  def start_tracking_request(provider) do
    current = get_active_request_count(provider)
    set_active_requests(provider, current + 1)
    {:ok, provider}
  end

  @doc """
  End tracking an active request.
  """
  def end_tracking_request({:ok, provider}) do
    current = get_active_request_count(provider)
    set_active_requests(provider, max(current - 1, 0))
  end

  defp get_active_request_count(provider) do
    case :prometheus_gauge.value(:llm_active_requests, [provider]) do
      value when is_number(value) -> trunc(value)
      _ -> 0
    end
  end
end
