defmodule ClientatsWeb.PrometheusHandler do
  @moduledoc """
  Telemetry event handlers for Prometheus metrics collection.

  Automatically captures metrics for:
  - LLM API calls with timing and results
  - Cache operations
  - Extraction operations
  - Circuit breaker state changes
  - Provider availability checks
  - Error tracking
  """

  require Logger
  alias Clientats.LLM.Metrics

  def attach_handlers do
    # LLM API call tracking
    :telemetry.attach(
      "llm-api-call",
      [:clientats, :llm, :api_call, :stop],
      &handle_api_call/4,
      nil
    )

    # LLM extraction tracking
    :telemetry.attach(
      "llm-extraction",
      [:clientats, :llm, :extraction, :stop],
      &handle_extraction/4,
      nil
    )

    # Cache hit/miss tracking
    :telemetry.attach(
      "llm-cache-hit",
      [:clientats, :llm, :cache, :hit],
      &handle_cache_hit/4,
      nil
    )

    :telemetry.attach(
      "llm-cache-miss",
      [:clientats, :llm, :cache, :miss],
      &handle_cache_miss/4,
      nil
    )

    # Circuit breaker state changes
    :telemetry.attach(
      "llm-circuit-breaker",
      [:clientats, :llm, :circuit_breaker, :state_change],
      &handle_circuit_breaker_change/4,
      nil
    )

    # Provider availability
    :telemetry.attach(
      "llm-provider-available",
      [:clientats, :llm, :provider, :available],
      &handle_provider_available/4,
      nil
    )

    # Error tracking
    :telemetry.attach(
      "llm-error",
      [:clientats, :llm, :error, :occurred],
      &handle_error/4,
      nil
    )

    Logger.info("Prometheus telemetry handlers attached for LLM monitoring")
  end

  # Event handlers

  defp handle_api_call(_event, measurements, metadata, _config) do
    provider = metadata[:provider] || "unknown"
    model = metadata[:model] || "unknown"
    status = metadata[:status] || "unknown"
    duration = measurements[:duration] || 0

    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    Metrics.track_api_call(provider, model, status, duration_ms, :ok)
  end

  defp handle_extraction(_event, measurements, metadata, _config) do
    provider = metadata[:provider] || "unknown"
    mode = metadata[:mode] || "unknown"
    status = metadata[:status] || "unknown"
    duration = measurements[:duration] || 0

    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    Metrics.track_extraction(provider, mode, status, duration_ms, :ok)
  end

  defp handle_cache_hit(_event, _measurements, metadata, _config) do
    provider = metadata[:provider] || "unknown"
    Metrics.inc_cache_hit(provider)
  end

  defp handle_cache_miss(_event, _measurements, metadata, _config) do
    provider = metadata[:provider] || "unknown"
    Metrics.inc_cache_miss(provider)
  end

  defp handle_circuit_breaker_change(_event, _measurements, metadata, _config) do
    provider = metadata[:provider] || "unknown"
    from_state = metadata[:from_state] || "unknown"
    to_state = metadata[:to_state] || "unknown"

    Metrics.inc_circuit_breaker_transition(provider, from_state, to_state)
  end

  defp handle_provider_available(_event, _measurements, metadata, _config) do
    provider = metadata[:provider] || "unknown"
    available = metadata[:available] || false

    Metrics.set_provider_available(provider, available)
  end

  defp handle_error(_event, _measurements, metadata, _config) do
    provider = metadata[:provider] || "unknown"
    error_type = metadata[:error_type] || "unknown"
    retryable = metadata[:retryable] || false

    Metrics.inc_error(provider, error_type, retryable)
  end
end
