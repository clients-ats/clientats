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
    active_provider = Enum.at(providers, 0)

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:providers, providers)
      |> assign(:provider_statuses, provider_statuses)
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

        <div class="bg-white rounded-lg shadow p-6">
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
            />
          </div>
        </div>

        <div class="mt-8 bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold text-gray-900 mb-4">Provider Status</h2>
          <div class="space-y-4">
            <%= for status <- @provider_statuses do %>
              <div class="flex items-center justify-between border rounded-lg p-4">
                <div class="flex items-center gap-3">
                  <div class={
                    "w-3 h-3 rounded-full " <>
                      if status.status == "connected" do
                        "bg-green-500"
                      else
                        "bg-red-500"
                      end
                  }></div>
                  <div>
                    <p class="font-semibold text-gray-900">
                      <%= String.capitalize(status.provider) %>
                    </p>
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

  def handle_event("discover_ollama_models", %{"base_url" => base_url}, socket) do
    send(self(), {:discover_ollama_models, base_url})
    {:noreply, assign(socket, :discovering_models, true)}
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
      "enabled" => params["enabled"] == "true"
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
            <% "openai" -> %>
              <.openai_form provider={@provider} provider_config={@provider_config} form_errors={@form_errors} />
            <% "anthropic" -> %>
              <.anthropic_form provider={@provider} provider_config={@provider_config} form_errors={@form_errors} />
            <% "mistral" -> %>
              <.mistral_form provider={@provider} provider_config={@provider_config} form_errors={@form_errors} />
            <% "gemini" -> %>
              <.gemini_form provider={@provider} provider_config={@provider_config} form_errors={@form_errors} />
            <% "ollama" -> %>
              <.ollama_form provider={@provider} provider_config={@provider_config} form_errors={@form_errors} ollama_models={@ollama_models} discovering_models={@discovering_models} />
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

  defp openai_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">API Key</span>
          <span class="label-text-alt text-gray-500">Get from https://platform.openai.com/api-keys</span>
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="sk-..."
          value={@provider_config && @provider_config.api_key}
          class="input input-bordered"
        />
        <%= if @form_errors[:api_key] do %>
          <label class="label">
            <span class="label-text-alt text-error"><%= @form_errors[:api_key] %></span>
          </label>
        <% end %>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Default Model</span>
          <span class="label-text-alt text-gray-500">e.g., gpt-4o</span>
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="gpt-4o"
          value={@provider_config && @provider_config.default_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
          <span class="label-text-alt text-gray-500">e.g., gpt-4-vision</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="gpt-4-vision"
          value={@provider_config && @provider_config.vision_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
          <span class="label-text-alt text-gray-500">e.g., gpt-4o</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="gpt-4o"
          value={@provider_config && @provider_config.text_model}
          class="input input-bordered"
        />
      </div>
    </div>
    """
  end

  defp anthropic_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">API Key</span>
          <span class="label-text-alt text-gray-500">Get from https://console.anthropic.com/account/keys</span>
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="sk-ant-..."
          value={@provider_config && @provider_config.api_key}
          class="input input-bordered"
        />
        <%= if @form_errors[:api_key] do %>
          <label class="label">
            <span class="label-text-alt text-error"><%= @form_errors[:api_key] %></span>
          </label>
        <% end %>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Default Model</span>
          <span class="label-text-alt text-gray-500">e.g., claude-opus-4-20250514</span>
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="claude-opus-4-20250514"
          value={@provider_config && @provider_config.default_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
          <span class="label-text-alt text-gray-500">e.g., claude-opus-4-20250514</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="claude-opus-4-20250514"
          value={@provider_config && @provider_config.vision_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
          <span class="label-text-alt text-gray-500">e.g., claude-opus-4-20250514</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="claude-opus-4-20250514"
          value={@provider_config && @provider_config.text_model}
          class="input input-bordered"
        />
      </div>
    </div>
    """
  end

  defp mistral_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">API Key</span>
          <span class="label-text-alt text-gray-500">Get from https://console.mistral.ai/api-keys</span>
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="Your Mistral API key"
          value={@provider_config && @provider_config.api_key}
          class="input input-bordered"
        />
        <%= if @form_errors[:api_key] do %>
          <label class="label">
            <span class="label-text-alt text-error"><%= @form_errors[:api_key] %></span>
          </label>
        <% end %>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Default Model</span>
          <span class="label-text-alt text-gray-500">e.g., mistral-large-latest</span>
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="mistral-large-latest"
          value={@provider_config && @provider_config.default_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
          <span class="label-text-alt text-gray-500">e.g., mistral-vision-latest</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="mistral-vision-latest"
          value={@provider_config && @provider_config.vision_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
          <span class="label-text-alt text-gray-500">e.g., mistral-large-latest</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="mistral-large-latest"
          value={@provider_config && @provider_config.text_model}
          class="input input-bordered"
        />
      </div>
    </div>
    """
  end

  defp gemini_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">API Key</span>
          <span class="label-text-alt text-gray-500">Get from https://aistudio.google.com/apikey</span>
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="Your Google Gemini API key"
          value={@provider_config && @provider_config.api_key}
          class="input input-bordered"
        />
        <%= if @form_errors[:api_key] do %>
          <label class="label">
            <span class="label-text-alt text-error"><%= @form_errors[:api_key] %></span>
          </label>
        <% end %>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Default Model</span>
          <span class="label-text-alt text-gray-500">e.g., gemini-2.0-flash, gemini-1.5-pro</span>
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="gemini-2.0-flash"
          value={@provider_config && @provider_config.default_model}
          class="input input-bordered"
        />
        <span class="label-text-alt text-gray-600">Used for general text processing</span>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
          <span class="label-text-alt text-gray-500">e.g., gemini-2.0-flash, gemini-1.5-pro</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="gemini-2.0-flash"
          value={@provider_config && @provider_config.vision_model}
          class="input input-bordered"
        />
        <span class="label-text-alt text-gray-600">Model with vision capabilities for image processing</span>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
          <span class="label-text-alt text-gray-500">e.g., gemini-2.0-flash, gemini-1.5-pro</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="gemini-2.0-flash"
          value={@provider_config && @provider_config.text_model}
          class="input input-bordered"
        />
        <span class="label-text-alt text-gray-600">Model for text-only tasks</span>
      </div>

      <div class="alert alert-info">
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
        <div>
          <p class="font-semibold mb-1">Getting Started with Google Gemini</p>
          <ul class="text-sm list-disc list-inside space-y-1">
            <li>Get your API key from <a href="https://aistudio.google.com/apikey" target="_blank" class="link link-primary">Google AI Studio</a></li>
            <li>Enable the Gemini API in your Google Cloud Console</li>
            <li>Use the "Test Connection" button to verify your API key</li>
            <li>Most Gemini models support both text and vision capabilities</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  defp ollama_form(assigns) do
    assigns = assign(
      assigns,
      :text_models,
      Enum.filter(assigns[:ollama_models] || [], fn m -> !m.vision end)
    )

    assigns = assign(
      assigns,
      :vision_models,
      Enum.filter(assigns[:ollama_models] || [], fn m -> m.vision end)
    )

    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Base URL</span>
          <span class="label-text-alt text-gray-500">e.g., http://localhost:11434</span>
        </label>
        <div class="flex gap-2">
          <input
            type="text"
            name="setting[base_url]"
            placeholder="http://localhost:11434"
            value={@provider_config && @provider_config.base_url}
            class="input input-bordered flex-1"
          />
          <button
            type="button"
            phx-click="discover_ollama_models"
            phx-value-base_url={@provider_config && @provider_config.base_url}
            disabled={@discovering_models}
            class="btn btn-primary"
          >
            <%= if @discovering_models, do: "Discovering...", else: "Discover Models" %>
          </button>
        </div>
        <span class="label-text-alt text-gray-600">The URL where Ollama is running</span>
      </div>

      <%= if length(@ollama_models) > 0 do %>
        <div class="form-control">
          <label class="label">
            <span class="label-text font-semibold">Default Model (Text)</span>
            <span class="label-text-alt text-gray-500">General text processing</span>
          </label>
          <select
            name="setting[default_model]"
            class="select select-bordered"
          >
            <option value="">Select a text model...</option>
            <%= for model <- @text_models do %>
              <option
                value={model.name}
                selected={@provider_config && @provider_config.default_model == model.name}
              >
                <%= model.name %>
              </option>
            <% end %>
          </select>
          <span class="label-text-alt text-gray-600">Used for general text processing</span>
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text font-semibold">Text Model</span>
            <span class="label-text-alt text-gray-500">Explicit text-only tasks</span>
          </label>
          <select
            name="setting[text_model]"
            class="select select-bordered"
          >
            <option value="">Select a text model...</option>
            <%= for model <- @text_models do %>
              <option
                value={model.name}
                selected={@provider_config && @provider_config.text_model == model.name}
              >
                <%= model.name %>
              </option>
            <% end %>
          </select>
          <span class="label-text-alt text-gray-600">Explicit model for text-only tasks</span>
        </div>

        <div class="form-control">
          <label class="label">
            <span class="label-text font-semibold">Vision Model</span>
            <span class="label-text-alt text-gray-500">Image processing</span>
          </label>
          <select
            name="setting[vision_model]"
            class="select select-bordered"
          >
            <option value="">Select a vision model...</option>
            <%= for model <- @vision_models do %>
              <option
                value={model.name}
                selected={@provider_config && @provider_config.vision_model == model.name}
              >
                <%= model.name %>
              </option>
            <% end %>
          </select>
          <span class="label-text-alt text-gray-600">Model with vision capabilities for image processing</span>
        </div>
      <% else %>
        <div class="alert alert-warning">
          <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4v.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          <span>Click "Discover Models" to fetch available models from your Ollama instance</span>
        </div>
      <% end %>

      <div class="alert alert-info">
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
        <div>
          <p class="font-semibold mb-1">Getting Started with Ollama</p>
          <ul class="text-sm list-disc list-inside space-y-1">
            <li>Ensure Ollama is running at the Base URL</li>
            <li>Models must be installed locally (e.g., <code class="text-xs bg-gray-100 px-1 rounded">ollama pull mistral</code>)</li>
            <li>Click "Discover Models" to automatically populate available models</li>
            <li>Use the "Test Connection" button to verify your setup</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to detect if a model has vision capabilities
  defp has_vision_capability(model_name) do
    vision_indicators = ["vision", "llava", "qwen", "vl", "multimodal", "image", "gpt-4v"]
    String.downcase(model_name)
    |> (fn name -> Enum.any?(vision_indicators, &String.contains?(name, &1)) end).()
  end
end
