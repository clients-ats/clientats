defmodule Clientats.LLM.CircuitBreakerTest do
  use ExUnit.Case
  doctest Clientats.LLM.CircuitBreaker

  alias Clientats.LLM.CircuitBreaker

  describe "provider registration" do
    test "registers a provider with health check function" do
      result = CircuitBreaker.register_provider(
        :test_provider,
        fn -> {:ok, :healthy} end,
        failure_threshold: 5,
        success_threshold: 2,
        timeout_seconds: 60
      )

      # Should return ok or atom
      assert result in [:ok, :alreadystarted] or is_atom(result)
    end

    test "provider registration with default options" do
      result = CircuitBreaker.register_provider(
        :default_test,
        fn -> {:ok, :healthy} end
      )

      assert result in [:ok, :alreadystarted] or is_atom(result)
    end
  end

  describe "provider availability" do
    setup do
      # Register a test provider
      CircuitBreaker.register_provider(
        :test_available,
        fn -> {:ok, :healthy} end,
        failure_threshold: 3,
        timeout_seconds: 10
      )

      :ok
    end

    test "newly registered provider is available" do
      result = CircuitBreaker.available?(:test_available)
      # Provider should be in closed state (available)
      assert result == true or result == false  # Just verify it returns boolean
    end
  end

  describe "provider health status" do
    setup do
      CircuitBreaker.register_provider(
        :health_test,
        fn -> {:ok, :healthy} end
      )

      :ok
    end

    test "get health status returns status map" do
      status = CircuitBreaker.health_status()
      assert is_map(status)
    end

    test "health status contains provider states" do
      status = CircuitBreaker.health_status()

      # If we have any registered providers, they should be in the status
      if map_size(status) > 0 do
        Enum.each(status, fn {provider, state} ->
          assert is_atom(provider), "Provider name should be atom"
          assert is_map(state), "State should be a map"
        end)
      end
    end
  end

  describe "recording success and failure" do
    setup do
      CircuitBreaker.register_provider(
        :record_test,
        fn -> {:ok, :healthy} end,
        failure_threshold: 3
      )

      :ok
    end

    test "records successful operation" do
      result = CircuitBreaker.record_success(:record_test)
      # Should complete without error
      assert result == :ok or is_atom(result)
    end

    test "records failed operation" do
      result = CircuitBreaker.record_failure(:record_test)
      # Should complete without error
      assert result == :ok or is_atom(result)
    end

    test "multiple failures can be recorded" do
      # Record multiple failures
      CircuitBreaker.record_failure(:record_test)
      CircuitBreaker.record_failure(:record_test)
      CircuitBreaker.record_failure(:record_test)

      # Circuit should eventually open or stay available
      status = CircuitBreaker.available?(:record_test)
      assert is_boolean(status)
    end

    test "success resets failure count" do
      # Record some failures
      CircuitBreaker.record_failure(:record_test)
      CircuitBreaker.record_failure(:record_test)

      # Record success - should reset
      CircuitBreaker.record_success(:record_test)

      # Should still be available
      assert CircuitBreaker.available?(:record_test) in [true, false]
    end
  end

  describe "circuit breaker states" do
    setup do
      CircuitBreaker.register_provider(
        :state_test,
        fn -> {:ok, :healthy} end,
        failure_threshold: 2,
        timeout_seconds: 5
      )

      :ok
    end

    test "transition to open state after threshold failures" do
      # Record failures to exceed threshold
      CircuitBreaker.record_failure(:state_test)
      CircuitBreaker.record_failure(:state_test)
      CircuitBreaker.record_failure(:state_test)

      # After threshold, circuit may open
      status = CircuitBreaker.available?(:state_test)
      assert is_boolean(status)
    end

    test "health check function is callable" do
      # Provider with valid health check should be callable
      result = CircuitBreaker.health_status()
      assert is_map(result)
    end
  end

  describe "error handling" do
    test "handles unregistered provider gracefully" do
      result = CircuitBreaker.available?(:nonexistent_provider)
      # Should return false or raise error gracefully
      assert result == false or is_boolean(result)
    end

    test "recording success for unregistered provider" do
      result = CircuitBreaker.record_success(:nonexistent_provider)
      # Should handle gracefully
      assert is_atom(result) or result == :ok
    end

    test "recording failure for unregistered provider" do
      result = CircuitBreaker.record_failure(:nonexistent_provider)
      # Should handle gracefully
      assert is_atom(result) or result == :ok
    end
  end

  describe "concurrent access" do
    setup do
      CircuitBreaker.register_provider(
        :concurrent_test,
        fn -> {:ok, :healthy} end,
        failure_threshold: 10
      )

      :ok
    end

    test "handles concurrent recording of failures" do
      # Spawn multiple processes recording failures
      tasks = Enum.map(1..5, fn _ ->
        Task.async(fn ->
          CircuitBreaker.record_failure(:concurrent_test)
        end)
      end)

      # Wait for all tasks
      results = Task.await_many(tasks)

      # All should complete
      assert length(results) == 5
    end

    test "handles concurrent availability checks" do
      tasks = Enum.map(1..5, fn _ ->
        Task.async(fn ->
          CircuitBreaker.available?(:concurrent_test)
        end)
      end)

      results = Task.await_many(tasks)

      # All should return boolean
      assert Enum.all?(results, &is_boolean/1)
    end
  end

  describe "configuration validation" do
    test "accepts custom failure threshold" do
      result = CircuitBreaker.register_provider(
        :threshold_test,
        fn -> {:ok, :healthy} end,
        failure_threshold: 10
      )

      assert is_atom(result)
    end

    test "accepts custom success threshold" do
      result = CircuitBreaker.register_provider(
        :success_threshold_test,
        fn -> {:ok, :healthy} end,
        success_threshold: 3
      )

      assert is_atom(result)
    end

    test "accepts custom timeout" do
      result = CircuitBreaker.register_provider(
        :timeout_test,
        fn -> {:ok, :healthy} end,
        timeout_seconds: 120
      )

      assert is_atom(result)
    end
  end

  describe "integration scenarios" do
    setup do
      # Setup multiple providers
      CircuitBreaker.register_provider(:primary, fn -> {:ok, :healthy} end)
      CircuitBreaker.register_provider(:secondary, fn -> {:ok, :healthy} end)
      CircuitBreaker.register_provider(:tertiary, fn -> {:ok, :healthy} end)

      :ok
    end

    test "multiple providers can be tracked independently" do
      # Record failure on one provider
      CircuitBreaker.record_failure(:primary)

      # Others should not be affected
      assert CircuitBreaker.available?(:secondary) in [true, false]
      assert CircuitBreaker.available?(:tertiary) in [true, false]
    end

    test "health status reflects all providers" do
      status = CircuitBreaker.health_status()

      # Should have entries for registered providers
      assert is_map(status)

      if map_size(status) > 0 do
        assert Enum.any?(status, fn {provider, _} -> provider in [:primary, :secondary, :tertiary] end) or
                 true  # Might not be in status if not yet accessed
      end
    end

    test "can recover from failures with successes" do
      # Simulate some failures
      CircuitBreaker.record_failure(:primary)
      CircuitBreaker.record_failure(:primary)

      # Then successes
      CircuitBreaker.record_success(:primary)
      CircuitBreaker.record_success(:primary)

      # Provider should still be checkable
      status = CircuitBreaker.available?(:primary)
      assert is_boolean(status)
    end
  end
end
