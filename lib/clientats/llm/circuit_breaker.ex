defmodule Clientats.LLM.CircuitBreaker do
  @moduledoc """
  Circuit breaker pattern implementation for LLM provider health management.

  States:
  - :closed - Normal operation, requests pass through
  - :open - Too many failures, requests rejected immediately
  - :half_open - Testing if service recovered, limited requests allowed

  Transitions:
  - closed -> open: Failure threshold exceeded
  - open -> half_open: Timeout expires (default 60s)
  - half_open -> closed: Health check succeeds
  - half_open -> open: Health check fails
  """

  use GenServer

  require Logger

  @default_failure_threshold 5
  @default_success_threshold 2
  @default_timeout_seconds 60
  @default_health_check_timeout 5_000

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a provider with the circuit breaker.
  """
  def register_provider(provider, health_check_fn, opts \\ []) do
    GenServer.call(__MODULE__, {:register_provider, provider, health_check_fn, opts})
  end

  @doc """
  Record a successful call to a provider.
  """
  def record_success(provider) do
    GenServer.call(__MODULE__, {:record_success, provider})
  end

  @doc """
  Record a failed call to a provider.
  """
  def record_failure(provider) do
    GenServer.call(__MODULE__, {:record_failure, provider})
  end

  @doc """
  Check if a provider is available (can accept requests).
  """
  def available?(provider) do
    GenServer.call(__MODULE__, {:available, provider})
  end

  @doc """
  Get current state of a provider.
  Returns: {:closed | :open | :half_open, metrics}
  """
  def get_state(provider) do
    GenServer.call(__MODULE__, {:get_state, provider})
  end

  @doc """
  Get health status of all providers.
  """
  def health_status do
    GenServer.call(__MODULE__, :health_status)
  end

  @doc """
  Reset a provider's circuit breaker.
  """
  def reset(provider) do
    GenServer.call(__MODULE__, {:reset, provider})
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Use ETS for fast, concurrent access
    :ets.new(:circuit_breaker, [:set, :protected, :named_table])

    # Start background process to check half-open providers
    spawn_link(&monitor_half_open_providers/0)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:register_provider, provider, health_check_fn, opts}, _from, state) do
    failure_threshold = Keyword.get(opts, :failure_threshold, @default_failure_threshold)
    success_threshold = Keyword.get(opts, :success_threshold, @default_success_threshold)
    timeout_seconds = Keyword.get(opts, :timeout_seconds, @default_timeout_seconds)

    provider_state = %{
      provider: provider,
      health_check_fn: health_check_fn,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      failure_threshold: failure_threshold,
      success_threshold: success_threshold,
      timeout_seconds: timeout_seconds,
      last_failure_time: nil,
      opened_at: nil
    }

    :ets.insert(:circuit_breaker, {provider, provider_state})
    {:reply, :ok, state}
  end

  def handle_call({:record_success, provider}, _from, state) do
    case :ets.lookup(:circuit_breaker, provider) do
      [{_provider, provider_state}] ->
        new_state = provider_state |> Map.update!(:success_count, &(&1 + 1))

        # In half-open state, check if we've succeeded enough times to close
        new_state =
          if new_state.state == :half_open and
             new_state.success_count >= new_state.success_threshold do
            Logger.info("Circuit breaker: #{provider} closed after successful recovery")
            new_state
            |> Map.put(:state, :closed)
            |> Map.put(:failure_count, 0)
            |> Map.put(:success_count, 0)
          else
            new_state
          end

        :ets.insert(:circuit_breaker, {provider, new_state})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :provider_not_registered}, state}
    end
  end

  def handle_call({:record_failure, provider}, _from, state) do
    case :ets.lookup(:circuit_breaker, provider) do
      [{_provider, provider_state}] ->
        new_state =
          provider_state
          |> Map.update!(:failure_count, &(&1 + 1))
          |> Map.put(:last_failure_time, DateTime.utc_now())

        # Check if we should open the circuit
        new_state =
          if new_state.state == :closed and
             new_state.failure_count >= new_state.failure_threshold do
            Logger.warning("Circuit breaker: #{provider} opened due to failures")
            new_state
            |> Map.put(:state, :open)
            |> Map.put(:opened_at, DateTime.utc_now())
          else
            # In half-open state, any failure returns to open
            if new_state.state == :half_open do
              Logger.warning("Circuit breaker: #{provider} reopened (health check failed)")
              new_state
              |> Map.put(:state, :open)
              |> Map.put(:opened_at, DateTime.utc_now())
              |> Map.put(:success_count, 0)
            else
              new_state
            end
          end

        :ets.insert(:circuit_breaker, {provider, new_state})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :provider_not_registered}, state}
    end
  end

  def handle_call({:available, provider}, _from, state) do
    case :ets.lookup(:circuit_breaker, provider) do
      [{_provider, provider_state}] ->
        available = check_availability(provider_state)
        {:reply, available, state}

      [] ->
        # Provider not registered, assume available
        {:reply, true, state}
    end
  end

  def handle_call({:get_state, provider}, _from, state) do
    case :ets.lookup(:circuit_breaker, provider) do
      [{_provider, provider_state}] ->
        metrics = %{
          state: provider_state.state,
          failure_count: provider_state.failure_count,
          success_count: provider_state.success_count,
          last_failure: provider_state.last_failure_time
        }
        {:reply, metrics, state}

      [] ->
        {:reply, nil, state}
    end
  end

  def handle_call(:health_status, _from, state) do
    status =
      :ets.match_object(:circuit_breaker, {:"$1", :_})
      |> Enum.map(fn {provider, provider_state} ->
        {provider,
         %{
           state: provider_state.state,
           failures: provider_state.failure_count,
           successes: provider_state.success_count
         }}
      end)
      |> Enum.into(%{})

    {:reply, status, state}
  end

  def handle_call({:reset, provider}, _from, state) do
    case :ets.lookup(:circuit_breaker, provider) do
      [{_provider, provider_state}] ->
        new_state =
          provider_state
          |> Map.put(:state, :closed)
          |> Map.put(:failure_count, 0)
          |> Map.put(:success_count, 0)
          |> Map.put(:last_failure_time, nil)
          |> Map.put(:opened_at, nil)

        :ets.insert(:circuit_breaker, {provider, new_state})
        Logger.info("Circuit breaker: #{provider} reset")
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :provider_not_registered}, state}
    end
  end

  # Private functions

  defp check_availability(%{state: :closed}), do: true

  defp check_availability(%{state: :open, timeout_seconds: timeout, opened_at: opened_at}) do
    if opened_at do
      elapsed_seconds =
        DateTime.utc_now()
        |> DateTime.diff(opened_at)

      if elapsed_seconds >= timeout do
        # Transition to half-open
        false  # Still not available, but will try half-open
      else
        false
      end
    else
      false
    end
  end

  defp check_availability(%{state: :half_open}), do: true

  defp monitor_half_open_providers do
    :timer.sleep(5000)

    :ets.match_object(:circuit_breaker, {:"$1", :_})
    |> Enum.each(fn {provider, provider_state} ->
      if provider_state.state == :open do
        check_and_transition_to_half_open(provider, provider_state)
      end
    end)

    monitor_half_open_providers()
  end

  defp check_and_transition_to_half_open(provider, provider_state) do
    elapsed_seconds =
      DateTime.utc_now()
      |> DateTime.diff(provider_state.opened_at)

    if elapsed_seconds >= provider_state.timeout_seconds do
      Logger.info("Circuit breaker: #{provider} transitioning to half-open")

      new_state =
        provider_state
        |> Map.put(:state, :half_open)
        |> Map.put(:failure_count, 0)
        |> Map.put(:success_count, 0)

      :ets.insert(:circuit_breaker, {provider, new_state})

      # Attempt health check
      spawn(fn ->
        case execute_health_check(provider, provider_state.health_check_fn) do
          :ok -> record_success(provider)
          :error -> record_failure(provider)
        end
      end)
    end
  end

  defp execute_health_check(_provider, health_check_fn) do
    try do
      case health_check_fn.() do
        {:ok, _} -> :ok
        {:error, _} -> :error
        :ok -> :ok
        :error -> :error
        _ -> :error
      end
    catch
      _, _ -> :error
    end
  end
end
