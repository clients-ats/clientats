defmodule ClientatsWeb.LLMConfigLive do
  use ClientatsWeb, :live_view

  alias Clientats.LLMConfig
  alias Clientats.LLM.Setting
  alias Clientats.LLM.Providers.Ollama
  alias ClientatsWeb.LLMConfigLive.Components.{GeminiForm, OllamaForm}

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    providers = Setting.providers()
    provider_statuses = LLMConfig.get_provider_status(user_id)
    primary_provider = LLMConfig.get_primary_provider(user_id)
    active_provider = Enum.at(providers, 0)

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
            <span><%= @save_success %></span>
          </div>
        <% end %>

        <!-- Quick Start Guide -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <!-- Cloud Provider Card -->
          <div class="bg-white rounded-lg shadow p-6 border-l-4 border-blue-500">
            <div class="flex items-start gap-3">
              <div class="text-2xl">☁️</div>
              <div class="flex-1">
                <h3 class="font-semibold text-gray-900 mb-2">Quick Start (Cloud)</h3>
                <p class="text-sm text-gray-600 mb-3">Best for getting started quickly:</p>
                <ul class="text-sm text-gray-600 space-y-1 mb-3">
                  <li>✓ Get API key from Google AI Studio</li>
                  <li>✓ No installation required</li>
                  <li>✓ Free tier available</li>
                  <li>✓ Works immediately</li>
                </ul>
                <.link navigate={~p"/dashboard/llm-config"} class="text-sm text-blue-600 hover:text-blue-800 font-semibold">
                  → Set up Gemini
                </.link>
              </div>
            </div>
          </div>

          <!-- Local Provider Card -->
          <div class="bg-white rounded-lg shadow p-6 border-l-4 border-green-500">
            <div class="flex items-start gap-3">
              <div class="text-2xl">🖥️</div>
              <div class="flex-1">
                <h3 class="font-semibold text-gray-900 mb-2">Advanced (Local)</h3>
                <p class="text-sm text-gray-600 mb-3">Maximum privacy and control:</p>
                <ul class="text-sm text-gray-600 space-y-1 mb-3">
                  <li>✓ Run models locally</li>
                  <li>✓ No API costs</li>
                  <li>✓ Complete privacy</li>
                  <li>✓ Requires setup</li>
                </ul>
                <.link navigate={~p"/dashboard/llm-config"} class="text-sm text-green-600 hover:text-green-800 font-semibold">
                  → Set up Ollama
                </.link>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6">
          <div class="flex items-center justify-between mb-6">
            <div>
              <h2 class="text-xl font-semibold text-gray-900 mb-1">Configure Your Provider</h2>
              <p class="text-sm text-gray-600">Start with just one provider to get started. You can add more later.</p>
            </div>
          </div>

          <div class="tabs tabs-bordered">
            <%= for provider <- @providers do %>
              <button
                phx-click="select_provider"
                phx-value-provider={provider}
                class={
                  "tab tab-bordered " <>
                    if provider == @active_provider do
                      "tab-active"
                    else
                      ""
                    end
                }
              >
                <%= String.capitalize(provider) %>
              </button>
            <% end %>
          </div>

          <div class="mt-6">
            <.provider_form
              provider={@active_provider}
              user_id={@user_id}
              testing={@testing}
              test_result={@test_result}
              save_success={@save_success}
              form_errors={@form_errors}
              provider_config={@provider_config}
              ollama_models={@ollama_models}
              discovering_models={@discovering_models}
            />
          </div>
        </div>

        <div class="mt-8 bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">Provider Status</h2>
          <div class="space-y-4">
            <%= for status <- @provider_statuses do %>
              <div class={
                "flex items-center justify-between border rounded-lg p-4 " <>
                  if status.provider == @primary_provider do
                    "border-primary border-2"
                  else
                    ""
                  end
              }>
                <div class="flex items-center gap-3 flex-1">
                  <div class={
                    "w-3 h-3 rounded-full " <>
                      if status.status == "connected" do
                        "bg-green-500"
                      else
                        "bg-red-500"
                      end
                  }></div>
                  <div>
                    <div class="flex items-center gap-2">
                      <p class="font-semibold text-gray-900">
                        <%= String.capitalize(status.provider) %>
                      </p>
                      <%= if status.provider == @primary_provider do %>
                        <span class="badge badge-sm badge-primary">Primary</span>
                      <% end %>
                    </div>
                    <%= if status.configured do %>
                      <p class="text-sm text-gray-600">
                        Model: <%= status.model || "Not configured" %>
                      </p>
                    <% else %>
                      <p class="text-sm text-gray-500">Not configured</p>
                    <% end %>
                  </div>
                </div>
                <div class="flex gap-2">
                  <%= if status.enabled do %>
                    <span class="badge badge-success">Enabled</span>
                  <% else %>
                    <span class="badge badge-outline">Disabled</span>
                  <% end %>
                  <%= if status.provider != @primary_provider do %>
                    <button
                      type="button"
                      phx-click="set_primary_provider"
                      phx-value-provider={status.provider}
                      class="btn btn-sm btn-outline"
                    >
                      Set as Primary
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_provider", %{"provider" => provider}, socket) do
    {:noreply,
     socket
     |> assign(:active_provider, provider)
     |> assign(:test_result, nil)
     |> load_provider_data(socket.assigns.user_id, provider)}
  end

  def handle_event("test_connection", %{"provider" => provider}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.get_provider_config(user_id, provider) do
      {:ok, config} ->
        send(self(), {:test_connection, provider, config})
        {:noreply, assign(socket, :testing, true)}

      {:error, :not_found} ->
        {:noreply, assign(socket, test_result: {:error, "Provider not configured"})}
    end
  end

  def handle_event("set_primary_provider", %{"provider" => provider}, socket) do
    user_id = socket.assigns.user_id

    case LLMConfig.set_primary_provider(user_id, provider) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:primary_provider, provider)
         |> assign(:save_success, "#{String.capitalize(provider)} is now your primary LLM provider")}

      {:error, _} ->
        {:noreply, assign(socket, test_result: {:error, "Failed to set primary provider"})}
    end
  end

  def handle_event("discover_ollama_models", params, socket) do
    # Try to get base_url from phx-value or form params
    base_url =
      case params do
        %{"base_url" => url} when url != "" -> url
        _ -> nil
      end

    # If not in params, try to get from provider_config
    base_url = base_url || (socket.assigns.provider_config && socket.assigns.provider_config.base_url)

    # Filter out empty base_url
    if base_url && base_url != "" do
      send(self(), {:discover_ollama_models, base_url})
      {:noreply, assign(socket, :discovering_models, true)}
    else
      {:noreply, assign(socket, :discovering_models, false)}
    end
  end

  def handle_event("save_config", %{"setting" => params}, socket) do
    user_id = socket.assigns.user_id
    provider = params["provider"]

    config_params = %{
      "provider" => provider,
      "api_key" => params["api_key"],
      "base_url" => params["base_url"],
      "default_model" => params["default_model"],
      "vision_model" => params["vision_model"],
      "text_model" => params["text_model"],
      "enabled" => params["enabled"] == "true",
      "provider_status" => "configured"
    }

    # Validate API key if provided
    case LLMConfig.validate_api_key(provider, config_params["api_key"]) do
      :ok ->
        case LLMConfig.save_provider_config(user_id, provider, config_params) do
          {:ok, _setting} ->
            provider_statuses = LLMConfig.get_provider_status(user_id)

            {:noreply,
             socket
             |> assign(:provider_statuses, provider_statuses)
             |> assign(:save_success, "Configuration saved successfully for #{String.capitalize(provider)}")
             |> assign(:form_errors, %{})}

          {:error, changeset} ->
            form_errors = Enum.into(changeset.errors, %{}, fn {key, {msg, _}} -> {key, msg} end)

            {:noreply, assign(socket, form_errors: form_errors)}
        end

      {:error, msg} ->
        {:noreply, assign(socket, form_errors: %{api_key: msg})}
    end
  end

  @impl true
  def handle_info({:test_connection, provider, config}, socket) do
    case LLMConfig.test_connection(provider, config) do
      {:ok, status} ->
        {:noreply,
         socket
         |> assign(:testing, false)
         |> assign(:test_result, {:ok, status})}

      {:error, msg} ->
        {:noreply,
         socket
         |> assign(:testing, false)
         |> assign(:test_result, {:error, msg})}
    end
  end

  def handle_info({:discover_ollama_models, base_url}, socket) do
    case Ollama.list_models(base_url) do
      {:ok, response} ->
        models = response["models"] || []
        ollama_models = Enum.map(models, fn model ->
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

  defp provider_form(assigns) do
    ~H"""
    <.form :let={_f} for={%{}} as={:setting} phx-submit="save_config">
      <input type="hidden" name="setting[provider]" value={@provider} />

      <div class="space-y-6">
        <!-- Enable/Disable Toggle -->
        <div class="flex items-center gap-4">
          <label class="label cursor-pointer flex items-center gap-2 flex-1">
            <span class="label-text font-semibold">Enable this provider</span>
            <input
              type="checkbox"
              name="setting[enabled]"
              value="true"
              checked={@provider_config && @provider_config.enabled}
              class="checkbox"
            />
          </label>
          <%= if @provider_config && @provider_config.enabled do %>
            <span class="badge badge-success">Enabled</span>
          <% else %>
            <span class="badge badge-outline">Disabled</span>
          <% end %>
        </div>

        <!-- Provider-specific fields -->
        <div class="border-t pt-6">
          <h3 class="font-semibold text-gray-900 mb-4">Configuration</h3>
          <%= case @provider do %>
            <% "gemini" -> %>
              <GeminiForm.render provider_config={@provider_config} form_errors={@form_errors} />
            <% "ollama" -> %>
              <OllamaForm.render provider_config={@provider_config} form_errors={@form_errors} ollama_models={@ollama_models} discovering_models={@discovering_models} />
          <% end %>
        </div>

        <!-- Test Connection Section -->
        <div class="border-t pt-6">
          <h3 class="font-semibold text-gray-900 mb-4">Connection Test</h3>
          <div class="space-y-3">
            <button
              type="button"
              phx-click="test_connection"
              phx-value-provider={@provider}
              disabled={@testing}
              class="btn btn-outline w-full"
            >
              <%= if @testing do %>
                <span class="loading loading-spinner loading-sm"></span>
                Testing connection...
              <% else %>
                Test Connection
              <% end %>
            </button>

            <!-- Test Result -->
            <%= if @test_result do %>
              <%= case @test_result do %>
                <% {:ok, _} -> %>
                  <div class="alert alert-success">
                    <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                    <span>Connection successful!</span>
                  </div>
                <% {:error, msg} -> %>
                  <div class="alert alert-error">
                    <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l-2-2m0 0l-2-2m2 2l2-2m-2 2l-2 2m2-2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                    <span><%= msg %></span>
                  </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex gap-2 pt-6 border-t">
          <button type="submit" class="btn btn-primary">
            Save Configuration
          </button>
          <.link navigate={~p"/dashboard"} class="btn btn-outline">
            Cancel
          </.link>
        </div>
      </div>
    </.form>
    """
  end

  defp has_vision_capability(model_name) do
    vision_indicators = ["vision", "llava", "qwen", "vl", "multimodal", "image", "gpt-4v"]
    String.downcase(model_name)
    |> (fn name -> Enum.any?(vision_indicators, &String.contains?(name, &1)) end).()
  end
end
