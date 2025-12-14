defmodule ClientatsWeb.LLMConfigLive do
  use ClientatsWeb, :live_view

  alias Clientats.LLMConfig
  alias Clientats.LLM.Setting

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    providers = Setting.providers()
    provider_statuses = LLMConfig.get_provider_status(user_id)
    active_provider = Enum.at(providers, 0)

    {:ok,
     socket
     |> assign(:user_id, user_id)
     |> assign(:providers, providers)
     |> assign(:provider_statuses, provider_statuses)
     |> assign(:active_provider, active_provider)
     |> assign(:testing, false)
     |> assign(:test_result, nil)
     |> assign(:save_success, nil)
     |> assign(:form_errors, %{})
     |> load_provider_data(user_id, active_provider)}
  end

  defp load_provider_data(socket, user_id, provider) do
    case LLMConfig.get_provider_config(user_id, provider) do
      {:ok, config} ->
        assign(socket, :provider_config, config)

      {:error, :not_found} ->
        assign(socket, :provider_config, nil)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4">
          <h1 class="text-2xl font-bold text-gray-900">LLM Configuration</h1>
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

  defp provider_form(assigns) do
    config = assigns[:provider_config]

    ~H"""
    <.form :let={f} for={%{}} as={:setting} phx-submit="save_config">
      <input type="hidden" name="setting[provider]" value={@provider} />

      <div class="space-y-4">
        <!-- Enable/Disable Toggle -->
        <div class="form-control">
          <label class="label cursor-pointer">
            <span class="label-text font-semibold">Enable this provider</span>
            <input
              type="checkbox"
              name="setting[enabled]"
              value="true"
              checked={config && config.enabled}
              class="checkbox"
            />
          </label>
        </div>

        <!-- Status Indicator -->
        <div class="alert">
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 rounded-full bg-gray-400"></div>
            <span class="text-sm text-gray-600">Status: Not tested</span>
          </div>
        </div>

        <!-- Provider-specific fields -->
        <%= case @provider do %>
          <% "openai" -> %>
            <.openai_form provider={@provider} config={config} form_errors={@form_errors} />
          <% "anthropic" -> %>
            <.anthropic_form provider={@provider} config={config} form_errors={@form_errors} />
          <% "mistral" -> %>
            <.mistral_form provider={@provider} config={config} form_errors={@form_errors} />
          <% "ollama" -> %>
            <.ollama_form provider={@provider} config={config} form_errors={@form_errors} />
        <% end %>

        <!-- Test Connection Button -->
        <div class="flex gap-2">
          <button
            type="button"
            phx-click="test_connection"
            phx-value-provider={@provider}
            disabled={@testing}
            class="btn btn-outline"
          >
            <%= if @testing do %>
              <span class="loading loading-spinner loading-sm"></span>
              Testing...
            <% else %>
              Test Connection
            <% end %>
          </button>

          <!-- Test Result -->
          <%= if @test_result do %>
            <%= case @test_result do %>
              <% {:ok, status} -> %>
                <div class="alert alert-success flex-1">
                  <span>✓ Connection successful: <%= status %></span>
                </div>
              <% {:error, msg} -> %>
                <div class="alert alert-error flex-1">
                  <span>✗ Connection failed: <%= msg %></span>
                </div>
            <% end %>
          <% end %>
        </div>

        <!-- Save Button -->
        <div class="flex gap-2 pt-4 border-t">
          <button type="submit" class="btn btn-primary">
            Save Configuration
          </button>
          <button type="button" class="btn btn-outline">
            Cancel
          </button>
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
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="sk-..."
          value={@config && @config.api_key}
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
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="gpt-4o"
          value={@config && @config.default_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="gpt-4-vision"
          value={@config && @config.vision_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="gpt-4o"
          value={@config && @config.text_model}
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
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="sk-ant-..."
          value={@config && @config.api_key}
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
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="claude-3-opus-20240229"
          value={@config && @config.default_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="claude-3-opus-20240229"
          value={@config && @config.vision_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="claude-3-opus-20240229"
          value={@config && @config.text_model}
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
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="Your Mistral API key"
          value={@config && @config.api_key}
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
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="mistral-large-latest"
          value={@config && @config.default_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="mistral-vision-latest"
          value={@config && @config.vision_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="mistral-large-latest"
          value={@config && @config.text_model}
          class="input input-bordered"
        />
      </div>
    </div>
    """
  end

  defp ollama_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Base URL</span>
        </label>
        <input
          type="text"
          name="setting[base_url]"
          placeholder="http://localhost:11434"
          value={@config && @config.base_url}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Default Model</span>
        </label>
        <input
          type="text"
          name="setting[default_model]"
          placeholder="mistral"
          value={@config && @config.default_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Vision Model</span>
        </label>
        <input
          type="text"
          name="setting[vision_model]"
          placeholder="qwen2.5vl:7b"
          value={@config && @config.vision_model}
          class="input input-bordered"
        />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">Text Model</span>
        </label>
        <input
          type="text"
          name="setting[text_model]"
          placeholder="mistral"
          value={@config && @config.text_model}
          class="input input-bordered"
        />
      </div>

      <div class="alert alert-info">
        <span class="text-sm">Ollama requires a running instance at the specified URL</span>
      </div>
    </div>
    """
  end
end
