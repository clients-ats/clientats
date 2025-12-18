defmodule Clientats.LLM.Metrics do
  @moduledoc """
  In-memory metrics collection for LLM operations and performance monitoring.

  Tracks:
  - LLM API response times and success rates
  - Cache hit/miss ratios
  - Extraction success rates
  - Circuit breaker state changes
  - Provider availability and latency

  Uses Agent-based in-memory storage for simplicity.
  For production at scale, integrate with Prometheus or similar.
  """

  require Logger
  use Agent

  @doc """
  Start metrics collector as agent.
  """
  def start_link(_) do
    Agent.start_link(
      fn ->
        %{
          api_calls: %{},
          cache_stats: %{},
          extraction_stats: %{},
          latencies: %{},
          errors: %{}
        }
      end,
      name: __MODULE__
    )
  end

  @doc """
  Initialize metrics (no-op now that we use Agent).
  """
  def setup do
    Logger.info("LLM metrics collector initialized")
  end

  # Counter operations
  def inc_api_call(provider, model, status) do
    try do
      Agent.update(__MODULE__, fn state ->
        key = {provider, model, status}
        count = Map.get(state.api_calls, key, 0)
        put_in(state, [:api_calls, key], count + 1)
      end)
    rescue
      _ -> :ok
    end
  end

  def inc_cache_hit(provider) do
    try do
      Agent.update(__MODULE__, fn state ->
        key = {provider, :hits}
        count = Map.get(state.cache_stats, key, 0)
        put_in(state, [:cache_stats, key], count + 1)
      end)
    rescue
      _ -> :ok
    end
  end

  def inc_cache_miss(provider) do
    try do
      Agent.update(__MODULE__, fn state ->
        key = {provider, :misses}
        count = Map.get(state.cache_stats, key, 0)
        put_in(state, [:cache_stats, key], count + 1)
      end)
    rescue
      _ -> :ok
    end
  end

  def inc_extraction(provider, mode, status) do
    try do
      Agent.update(__MODULE__, fn state ->
        key = {provider, mode, status}
        count = Map.get(state.extraction_stats, key, 0)
        put_in(state, [:extraction_stats, key], count + 1)
      end)
    rescue
      _ -> :ok
    end
  end

  def inc_error(provider, error_type, retryable) do
    try do
      Agent.update(__MODULE__, fn state ->
        key = {provider, error_type, retryable}
        count = Map.get(state.errors, key, 0)
        put_in(state, [:errors, key], count + 1)
      end)
    rescue
      _ -> :ok
    end
  end

  # Gauge updates
  def set_provider_available(_provider, _available) do
    :ok
  end

  def set_active_requests(_provider, _count) do
    :ok
  end

  def set_latency_p95(provider, latency_ms) do
    try do
      Agent.update(__MODULE__, fn state ->
        put_in(state, [:latencies, provider], latency_ms)
      end)
    rescue
      _ -> :ok
    end
  end

  # Observation
  def observe_api_duration(provider, _model, duration_ms) do
    set_latency_p95(provider, duration_ms)
  end

  @doc """
  Track API call with timing and result.
  """
  def track_api_call(provider, model, status, duration_ms, result) do
    inc_api_call(provider, model, status)
    observe_api_duration(provider, model, duration_ms)
    result
  end

  @doc """
  Track extraction with timing.
  """
  def track_extraction(provider, mode, status, duration_ms, result) do
    inc_extraction(provider, mode, status)
    observe_api_duration(provider, mode, duration_ms)
    result
  end

  @doc """
  Get current metrics snapshot for monitoring/debugging.
  """
  def get_metrics do
    try do
      Agent.get(__MODULE__, & &1)
    rescue
      _ -> %{api_calls: %{}, cache_stats: %{}, extraction_stats: %{}, latencies: %{}, errors: %{}}
    end
  end

  @doc """
  Reset all metrics.
  """
  def reset do
    Agent.update(__MODULE__, fn _state ->
      %{
        api_calls: %{},
        cache_stats: %{},
        extraction_stats: %{},
        latencies: %{},
        errors: %{}
      }
    end)
  end
end
