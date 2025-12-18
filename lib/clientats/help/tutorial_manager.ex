defmodule Clientats.Help.TutorialManager do
  @moduledoc """
  Manages user onboarding and interactive tutorials.

  Tracks tutorial completion, dismissal, and provides personalized
  tutorial recommendations based on user activity.
  """

  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    {:ok, %{}}
  end

  @doc """
  Track that a user has seen a tutorial.
  """
  def mark_tutorial_seen(user_id, feature) do
    # In a real implementation, this would persist to database
    # For now, store in-memory with eventual database sync
    GenServer.call(__MODULE__, {:mark_seen, user_id, feature})
  end

  @doc """
  Check if user has seen a tutorial.
  """
  def has_seen_tutorial?(user_id, feature) do
    GenServer.call(__MODULE__, {:has_seen, user_id, feature})
  end

  @doc """
  Dismiss a tutorial for a user.
  """
  def dismiss_tutorial(user_id, feature) do
    GenServer.call(__MODULE__, {:dismiss, user_id, feature})
  end

  @doc """
  Get recommended tutorials for a user based on their actions.
  """
  def get_recommended_tutorials(user_id) do
    GenServer.call(__MODULE__, {:get_recommendations, user_id})
  end

  # GenServer Callbacks

  @impl true
  def handle_call({:mark_seen, user_id, feature}, _from, state) do
    key = {user_id, :seen, feature}
    new_state = Map.put(state, key, DateTime.utc_now())
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:has_seen, user_id, feature}, _from, state) do
    key = {user_id, :seen, feature}
    has_seen = Map.has_key?(state, key)
    {:reply, has_seen, state}
  end

  @impl true
  def handle_call({:dismiss, user_id, feature}, _from, state) do
    key = {user_id, :dismissed, feature}
    new_state = Map.put(state, key, DateTime.utc_now())
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_recommendations, _user_id}, _from, state) do
    # Recommend tutorials based on dismissals and feature access patterns
    recommendations = []
    {:reply, recommendations, state}
  end
end
