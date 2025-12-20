defmodule ClientatsWeb.LLMConfigLive do
  use ClientatsWeb, :live_view

  alias Clientats.LLMConfig
  alias Clientats.LLM.Setting
  alias Clientats.LLM.Providers.Ollama

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    providers = Setting.providers()
    provider_statuses = LLMConfig.get_provider_status(user_id)
    primary_provider = LLMConfig.get_primary_provider(user_id)
    active_provider = Enum.at(providers, 0)

    # If no providers configured, redirect to wizard
    if Enum.empty?(provider_statuses) do
      {:ok, redirect(socket, to: ~p"/dashboard/llm-setup")}
    else
      socket =
        socket
        |> assign(:user_id, user_id)
        |> assign(:providers, providers)
        |> assign(:provider_statuses, provider_statuses)
        |> assign(:primary_provider, primary_provider)
        |> assign(:active_provider, active_provider)
        |> assign(:testing, false)
        |> assign(:test_result, nil)
        |> assign(:save_success, nil)
        |> assign(:form_errors, %{})
        |> assign(:ollama_models, [])
        |> assign(:discovering_models, false)
        |> assign(:provider_config, nil)

      socket = load_provider_data(socket, user_id, active_provider)

      {:ok, socket}
    end
  end

  defp load_provider_data(socket, user_id, provider) do
    case LLMConfig.get_provider_config(user_id, provider) do
      {:ok, config} ->
        # Verify API key is valid (plain text), if not clear it
        config =
          if config.api_key && !is_valid_api_key(config.api_key) do
            %{config | api_key: nil}
          else
            config
          end

        assign(socket, :provider_config, config)

      {:error, :not_found} ->
        # Apply defaults for Ollama on first load
        defaults = LLMConfig.get_env_defaults()
        provider_atom = String.to_atom(provider)
        provider_defaults = Map.get(defaults, provider_atom, %{})

        default_config = %Setting{
          provider: provider,
          base_url: Map.get(provider_defaults, :base_url),
          default_model: Map.get(provider_defaults, :default_model),
          vision_model: Map.get(provider_defaults, :vision_model),
          text_model: Map.get(provider_defaults, :text_model),
          enabled: false
        }

        assign(socket, :provider_config, default_config)
    end
  end

  defp is_valid_api_key(api_key) when is_binary(api_key) do
    # API keys should be valid UTF-8 and not contain too many non-printable characters
    String.valid?(api_key) && String.length(api_key) > 0
  end

  defp is_valid_api_key(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4 flex justify-between items-center">
          <h1 class="text-2xl font-bold text-gray-900">LLM Configuration</h1>
          <.link navigate={~p"/dashboard"} class="text-sm text-gray-600 hover:text-gray-900">
            ← Back to Dashboard
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8">
        <%= if @save_success do %>
          <div class="alert alert-success mb-4">
            <span>{@save_success}</span>
          </div>
        <% end %>
        
    <!-- Provider List Section (List-First) -->
        <div class="mb-8">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h2 class="text-2xl font-bold text-gray-900">Your Providers</h2>
              <p class="text-sm text-gray-600">
                Manage your LLM providers. Drag to reorder, click Edit to modify.
              </p>
            </div>
            <.link navigate={~p"/dashboard/llm-setup"} class="btn btn-primary btn-sm">
              + Add Provider
            </.link>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <div class="mt-8 bg-white rounded-lg shadow p-6">
              <h2 class="text-xl font-semibold text-gray-900 mb-4">Provider Status</h2>
              <div
                id="provider-list"
                phx-hook="ProviderReorder"
                class="space-y-4"
              >
                <%= for status <- @provider_statuses do %>
                  <div
                    data-provider={status.provider}
                    data-primary={status.provider == @primary_provider}
                    class={
                      "border rounded-lg p-4 transition-shadow cursor-move " <>
                        if status.provider == @primary_provider do
                          "border-primary border-2 bg-blue-50"
                        else
                          "border-gray-300"
                        end
                    }
                  >
                    <!-- Header Row -->
                    <div class="flex items-center justify-between mb-3">
                      <div class="flex items-center gap-3">
                        <!-- Drag Handle -->
                        <div class="drag-handle cursor-grab active:cursor-grabbing text-gray-400 hover:text-gray-600 transition-colors flex-shrink-0">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-5 w-5"
                            viewBox="0 0 20 20"
                            fill="currentColor"
                          >
                            <path d="M7 2a2 2 0 1 0 .001 4.001A2 2 0 0 0 7 2zm0 6a2 2 0 1 0 .001 4.001A2 2 0 0 0 7 8zm0 6a2 2 0 1 0 .001 4.001A2 2 0 0 0 7 14zm6-8a2 2 0 1 0-.001-4.001A2 2 0 0 0 13 6zm0 2a2 2 0 1 0 .001 4.001A2 2 0 0 0 13 8zm0 6a2 2 0 1 0 .001 4.001A2 2 0 0 0 13 14z" />
                          </svg>
                        </div>

                        <div class="text-2xl">
                          {provider_icon(status.provider)}
                        </div>
                        <div>
                          <div class="flex items-center gap-2">
                            <p class="font-semibold text-gray-900">
                              {String.capitalize(status.provider)}
                            </p>
                            <%= if status.provider == @primary_provider do %>
                              <span class="badge badge-sm badge-primary">Primary</span>
                            <% end %>
                          </div>
                        </div>
                      </div>
                      <span class={status_badge_class(status)}>
                        {status_label(status)}
                      </span>
                    </div>
                    
    <!-- Status Info Row -->
                    <div class="space-y-2 mb-3">
                      <!-- Last Tested -->
                      <div class="text-sm text-gray-600">
                        <%= if status.last_tested_at do %>
                          Last tested:
                          <span class="font-medium">
                            {format_relative_time(status.last_tested_at)}
                          </span>
                        <% else %>
                          <span class="text-gray-500">Not tested yet</span>
                        <% end %>
                      </div>
                      
    <!-- Model Info -->
                      <%= if status.model do %>
                        <div class="text-sm text-gray-600">
                          Model: <span class="font-medium">{status.model}</span>
                        </div>
                      <% end %>
                      
    <!-- Error Message -->
                      <%= if status.last_error do %>
                        <div class="alert alert-error alert-sm py-2">
                          <span class="text-sm">{status.last_error}</span>
                        </div>
                      <% end %>
                    </div>
                    
    <!-- Action Buttons Row -->
                    <div class="flex flex-wrap gap-2">
                      <button
                        type="button"
                        phx-click="edit_provider"
                        phx-value-provider={status.provider}
                        class="btn btn-sm btn-outline"
                        title="Go to provider configuration"
                      >
                        Edit
                      </button>

                      <button
                        type="button"
                        phx-click="test_provider_from_status"
                        phx-value-provider={status.provider}
                        class="btn btn-sm btn-outline"
                        title="Test connection for this provider"
                      >
                        Test
                      </button>

                      <button
                        type="button"
                        phx-click="toggle_provider_enabled"
                        phx-value-provider={status.provider}
                        class={
                          "btn btn-sm " <>
                            if status.enabled do
                              "btn-warning"
                            else
                              "btn-outline"
                            end
                        }
                        title={
                          if status.enabled do
                            "Disable this provider"
                          else
                            "Enable this provider"
                          end
                        }
                      >
                        {if status.enabled do
                          "Disable"
                        else
                          "Enable"
                        end}
                      </button>

                      <%= if status.provider != @primary_provider do %>
                        <button
                          type="button"
                          phx-click="set_primary_provider"
                          phx-value-provider={status.provider}
                          class="btn btn-sm btn-outline"
                          title="Set as primary provider"
                        >
                          Set as Primary
                        </button>
                      <% end %>

                      <button
                        type="button"
                        phx-click="delete_provider"
                        phx-value-provider={status.provider}
                        data-confirm={delete_provider_message(status.provider, @primary_provider)}
                        class="btn btn-sm btn-error"
                        title="Delete this provider configuration"
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>

              <%= if Enum.empty?(@provider_statuses) do %>
                <div class="text-center py-8 text-gray-500">
                  <p class="mb-4">No providers configured yet.</p>
                  <.link navigate={~p"/dashboard/llm-setup"} class="btn btn-primary btn-sm">
                    Get Started with Wizard
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_primary_provider", %{"provider" => provider}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.set_primary_provider(user_id, provider) do
      {:ok, _user} ->
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:primary_provider, provider)
         |> assign(:provider_statuses, provider_statuses)
         |> assign(
           :save_success,
           "#{String.capitalize(provider)} is now your primary LLM provider"
         )}

      {:error, _} ->
        {:noreply, assign(socket, test_result: {:error, "Failed to set primary provider"})}
    end
  end

  def handle_event("edit_provider", %{"provider" => provider}, socket) do
    {:noreply,
     socket
     |> assign(:active_provider, provider)
     |> assign(:test_result, nil)
     |> load_provider_data(socket.assigns.user_id, provider)}
  end

  def handle_event("test_provider_from_status", %{"provider" => provider}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.get_provider_config(user_id, provider) do
      {:ok, config} ->
        send(self(), {:test_connection_from_status, provider, config})
        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, assign(socket, test_result: {:error, "Provider not configured"})}
    end
  end

  def handle_event("toggle_provider_enabled", %{"provider" => provider}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.toggle_provider_enabled(user_id, provider) do
      {:ok, updated_status} ->
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:provider_statuses, provider_statuses)
         |> assign(
           :save_success,
           "#{String.capitalize(provider)} has been #{if updated_status.enabled do
             "enabled"
           else
             "disabled"
           end}"
         )}

      {:error, _} ->
        {:noreply, assign(socket, :test_result, {:error, "Failed to toggle provider"})}
    end
  end

  def handle_event("reorder_providers", %{"provider_order" => provider_order}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.reorder_providers(user_id, provider_order) do
      {:ok, _count} ->
        # Reload provider statuses to reflect new order
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:provider_statuses, provider_statuses)
         |> assign(:save_success, "Provider order updated successfully")}

      {:error, _reason} ->
        {:noreply, assign(socket, test_result: {:error, "Failed to update provider order"})}
    end
  end

  def handle_event("delete_provider", %{"provider" => provider}, socket) do
    user_id = socket.assigns.user_id
    primary_provider = socket.assigns.primary_provider

    case LLMConfig.delete_provider(user_id, provider) do
      {:ok, _deleted_setting} ->
        # If we deleted the primary provider, promote another or reset to default
        new_primary =
          if provider == primary_provider do
            promote_next_provider(user_id)
          else
            primary_provider
          end

        # Update primary provider if it changed
        :ok =
          if new_primary != primary_provider do
            case LLMConfig.set_primary_provider(user_id, new_primary) do
              {:ok, _} -> :ok
              {:error, _} -> :ok
            end
          else
            :ok
          end

        # Reload provider statuses
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:provider_statuses, provider_statuses)
         |> assign(:primary_provider, new_primary)
         |> assign(:save_success, "#{String.capitalize(provider)} provider deleted successfully")}

      {:error, :not_found} ->
        {:noreply, assign(socket, test_result: {:error, "Provider not found"})}

      {:error, _reason} ->
        {:noreply, assign(socket, test_result: {:error, "Failed to delete provider"})}
    end
  end

  @impl true
  def handle_info({:test_connection, provider, config}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.test_connection(provider, config) do
      {:ok, status} ->
        LLMConfig.save_test_result(user_id, provider, {:ok, status})
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:testing, false)
         |> assign(:test_result, {:ok, status})
         |> assign(:provider_statuses, provider_statuses)}

      {:error, msg} ->
        LLMConfig.save_test_result(user_id, provider, {:error, msg})
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:testing, false)
         |> assign(:test_result, {:error, msg})
         |> assign(:provider_statuses, provider_statuses)}
    end
  end

  def handle_info({:test_connection_from_status, provider, config}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.test_connection(provider, config) do
      {:ok, status} ->
        LLMConfig.save_test_result(user_id, provider, {:ok, status})
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:provider_statuses, provider_statuses)
         |> assign(:save_success, "#{String.capitalize(provider)} connection test successful!")}

      {:error, msg} ->
        LLMConfig.save_test_result(user_id, provider, {:error, msg})
        provider_statuses = LLMConfig.get_provider_status(user_id)

        {:noreply,
         socket
         |> assign(:provider_statuses, provider_statuses)
         |> assign(:test_result, {:error, msg})}
    end
  end

  def handle_info({:discover_ollama_models, base_url}, socket) do
    case Ollama.list_models(base_url) do
      {:ok, response} ->
        models = response["models"] || []

        ollama_models =
          Enum.map(models, fn model ->
            %{
              name: model["name"],
              vision: has_vision_capability(model["name"])
            }
          end)

        {:noreply,
         socket
         |> assign(:ollama_models, ollama_models)
         |> assign(:discovering_models, false)}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:ollama_models, [])
         |> assign(:discovering_models, false)}
    end
  end

  defp has_vision_capability(model_name) do
    vision_indicators = ["vision", "llava", "qwen", "vl", "multimodal", "image", "gpt-4v"]

    String.downcase(model_name)
    |> (fn name -> Enum.any?(vision_indicators, &String.contains?(name, &1)) end).()
  end

  # Helper functions for Provider Status section
  defp provider_icon(provider) do
    case provider do
      "gemini" -> "☁️"
      "ollama" -> "🖥️"
      _ -> "⚙️"
    end
  end

  defp status_label(status_info) when is_map(status_info) do
    cond do
      status_info.enabled && status_info.last_tested_at ->
        "Connected"

      status_info.enabled ->
        "Configured"

      status_info.last_error ->
        "Error"

      true ->
        "Disabled"
    end
  end

  defp status_badge_class(status_info) when is_map(status_info) do
    cond do
      status_info.enabled && status_info.last_tested_at ->
        "badge badge-success badge-lg"

      status_info.enabled ->
        "badge badge-warning badge-lg"

      status_info.last_error ->
        "badge badge-error badge-lg"

      true ->
        "badge badge-ghost badge-lg"
    end
  end

  defp format_relative_time(nil), do: "Never"

  defp format_relative_time(%NaiveDateTime{} = datetime) do
    now = NaiveDateTime.utc_now()
    seconds_ago = NaiveDateTime.diff(now, datetime)

    cond do
      seconds_ago < 60 -> "Just now"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)} minutes ago"
      seconds_ago < 86400 -> "#{div(seconds_ago, 3600)} hours ago"
      seconds_ago < 604_800 -> "#{div(seconds_ago, 86400)} days ago"
      true -> "#{div(seconds_ago, 604_800)} weeks ago"
    end
  end

  defp format_relative_time(_), do: "Unknown"

  defp promote_next_provider(user_id) do
    # Get all enabled providers, sorted by sort_order
    providers = LLMConfig.list_providers(user_id)

    # Find the first enabled provider (in sort order)
    next_provider = Enum.find(providers, fn p -> p.enabled end)

    if next_provider do
      next_provider.provider
    else
      # No other enabled providers, default to gemini
      "gemini"
    end
  end

  defp delete_provider_message(provider_name, primary_provider) do
    if provider_name == primary_provider do
      """
      You are about to delete your PRIMARY provider (#{String.capitalize(provider_name)}).

      Your next enabled provider will automatically be promoted to primary.
      If no other providers are available, Gemini will be set as default.

      Are you sure?
      """
    else
      "Are you sure you want to delete the #{String.capitalize(provider_name)} provider configuration?"
    end
  end
end
