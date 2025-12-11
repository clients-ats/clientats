defmodule Clientats.LLM.Cache do
  @moduledoc """
  Simple in-memory cache for LLM extraction results.
  
  In production, this should be replaced with a distributed cache like Redis.
  """
  
  @type cache_key :: String.t()
  @type cache_value :: map()
  @type cache_entry :: {%{inserted_at: DateTime.t(), ttl: integer(), data: cache_value}}
  
  @default_ttl 86400 # 24 hours in seconds
  
  @doc """
  Get cached value by URL.
  """
  def get(url) do
    ttl = Application.get_env(:req_llm, :cache_ttl, @default_ttl)
    
    case get_cache_entry(url) do
      nil -> :not_found
      %{inserted_at: inserted_at, ttl: _ttl, data: data} ->
        if DateTime.diff(DateTime.utc_now(), inserted_at, :second) < ttl do
          {:ok, data}
        else
          :not_found
        end
      _ -> :not_found
    end
  end
  
  @doc """
  Put value in cache.
  """
  def put(url, data) do
    ttl = Application.get_env(:req_llm, :cache_ttl, @default_ttl)
    entry = %{inserted_at: DateTime.utc_now(), ttl: ttl, data: data}
    put_cache_entry(url, entry)
    :ok
  end
  
  @doc """
  Clear cache entry.
  """
  def delete(url), do: delete_cache_entry(url)
  
  @doc """
  Clear entire cache.
  """
  def clear(), do: clear_cache()
  
  # In-memory cache implementation (replace with Redis in production)
  defp get_cache_entry(url) do
    Agent.get(@agent, &Map.get(&1, url))
  end
  
  defp put_cache_entry(url, entry) do
    Agent.update(@agent, &Map.put(&1, url, entry))
  end
  
  defp delete_cache_entry(url) do
    Agent.update(@agent, &Map.delete(&1, url))
  end
  
  defp clear_cache() do
    Agent.update(@agent, &Map.new())
  end
  
  # Start the cache agent
  def start_link(_) do
    Agent.start_link(fn -> Map.new() end, name: __MODULE__)
  end
  
  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
end