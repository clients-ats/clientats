defmodule ClientatsWeb.LLMWizardLive do
  use ClientatsWeb, :live_view

  alias Clientats.LLMConfig

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:current_step, 1)
      |> assign(:provider_choice, nil)
      |> assign(:gemini_config, %{})
      |> assign(:ollama_config, %{})
      |> assign(:connection_tested, false)
      |> assign(:testing, false)
      |> assign(:test_result, nil)
      |> assign(:save_success, nil)
      |> assign(:form_errors, %{})
      |> assign(:discovering_models, false)
      |> assign(:ollama_models, [])

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 py-12 px-4">
      <div class="max-w-2xl mx-auto">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900 mb-2">LLM Provider Setup</h1>
          <p class="text-gray-600">Let's get your AI provider configured in just a few steps</p>
        </div>

        <!-- Step Indicator -->
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <div class={step_class(1, @current_step)}>
              <div class="flex items-center">
                <div class="w-10 h-10 rounded-full bg-primary text-white flex items-center justify-center font-semibold">
                  1
                </div>
                <span class="ml-3 text-sm font-semibold">Choose</span>
              </div>
            </div>

            <div class={if @current_step > 1, do: "flex-1 h-1 bg-primary mx-2", else: "flex-1 h-1 bg-gray-300 mx-2"}></div>

            <div class={step_class(2, @current_step)}>
              <div class="flex items-center">
                <div class={
                  "w-10 h-10 rounded-full flex items-center justify-center font-semibold " <>
                    if @current_step >= 2 do
                      "bg-primary text-white"
                    else
                      "bg-gray-300 text-gray-600"
                    end
                }>
                  2
                </div>
                <span class="ml-3 text-sm font-semibold">Configure</span>
              </div>
            </div>

            <div class={if @current_step > 2, do: "flex-1 h-1 bg-primary mx-2", else: "flex-1 h-1 bg-gray-300 mx-2"}></div>

            <div class={step_class(3, @current_step)}>
              <div class="flex items-center">
                <div class={
                  "w-10 h-10 rounded-full flex items-center justify-center font-semibold " <>
                    if @current_step >= 3 do
                      "bg-primary text-white"
                    else
                      "bg-gray-300 text-gray-600"
                    end
                }>
                  3
                </div>
                <span class="ml-3 text-sm font-semibold">Review</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Step Content -->
        <div class="bg-white rounded-lg shadow p-8">
          <%= case @current_step do %>
            <% 1 -> %>
              <.render_step_1 provider_choice={@provider_choice} />

            <% 2 -> %>
              <%= if @provider_choice == "gemini" do %>
                <.render_step_2_gemini
                  config={@gemini_config}
                  testing={@testing}
                  test_result={@test_result}
                  form_errors={@form_errors}
                  connection_tested={@connection_tested}
                />
              <% else %>
                <.render_step_2_ollama
                  config={@ollama_config}
                  testing={@testing}
                  test_result={@test_result}
                  form_errors={@form_errors}
                  connection_tested={@connection_tested}
                  discovering_models={@discovering_models}
                  ollama_models={@ollama_models}
                />
              <% end %>

            <% 3 -> %>
              <.render_step_3
                provider_choice={@provider_choice}
                connection_tested={@connection_tested}
                test_result={@test_result}
              />
          <% end %>
        </div>

        <!-- Navigation -->
        <div class="mt-8 flex justify-between">
          <div class="flex gap-2">
            <%= if @current_step > 1 do %>
              <button
                type="button"
                phx-click="back"
                class="btn btn-outline"
              >
                ← Back
              </button>
            <% end %>
            <button
              type="button"
              phx-click="cancel"
              class="btn btn-ghost"
            >
              Cancel
            </button>
          </div>

          <%= if @current_step < 3 do %>
            <button
              type="button"
              phx-click="next"
              disabled={@current_step == 2 && !@connection_tested}
              class={
                "btn " <>
                  if @current_step == 2 && !@connection_tested do
                    "btn-disabled"
                  else
                    "btn-primary"
                  end
              }
            >
              Next →
            </button>
          <% else %>
            <button
              type="button"
              phx-click="complete"
              class="btn btn-primary"
            >
              Complete Setup
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Step 1: Choose Provider
  defp render_step_1(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-6">Choose Your LLM Provider</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <button
          type="button"
          phx-click="choose_provider"
          phx-value-provider="gemini"
          class={
            "p-6 border-2 rounded-lg text-left transition-all " <>
              if @provider_choice == "gemini" do
                "border-primary bg-blue-50"
              else
                "border-gray-300 hover:border-gray-400"
              end
          }
        >
          <div class="text-4xl mb-3">☁️</div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Gemini</h3>
          <p class="text-sm text-gray-600 mb-3">Cloud-based AI from Google</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li>✓ Best for getting started</li>
            <li>✓ No installation required</li>
            <li>✓ Free tier available</li>
          </ul>
        </button>

        <button
          type="button"
          phx-click="choose_provider"
          phx-value-provider="ollama"
          class={
            "p-6 border-2 rounded-lg text-left transition-all " <>
              if @provider_choice == "ollama" do
                "border-primary bg-blue-50"
              else
                "border-gray-300 hover:border-gray-400"
              end
          }
        >
          <div class="text-4xl mb-3">🖥️</div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">Ollama</h3>
          <p class="text-sm text-gray-600 mb-3">Run models locally on your machine</p>
          <ul class="text-sm text-gray-600 space-y-1">
            <li>✓ Complete privacy</li>
            <li>✓ No API costs</li>
            <li>✓ Advanced setup</li>
          </ul>
        </button>
      </div>
    </div>
    """
  end

  # Step 2: Configure Gemini
  defp render_step_2_gemini(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-2">Configure Gemini</h2>
      <p class="text-gray-600 mb-6">Set up your Gemini API key and choose your model</p>

      <form phx-change="validate_gemini" class="space-y-6">
        <!-- API Key -->
        <div>
          <label class="label">
            <span class="label-text font-semibold">API Key <span class="text-error">*</span></span>
          </label>
          <input
            type="password"
            name="api_key"
            value={@config["api_key"] || ""}
            placeholder="Paste your Gemini API key"
            class="input input-bordered w-full"
          />
          <p class="text-sm text-gray-600 mt-2">
            <a href="https://aistudio.google.com/app/apikey" target="_blank" class="link link-primary">
              Get your API key →
            </a>
          </p>
          <%= if errors = @form_errors["api_key"] do %>
            <div class="alert alert-error alert-sm mt-2">
              <span><%= Enum.join(errors, ", ") %></span>
            </div>
          <% end %>
        </div>

        <!-- Model Selection -->
        <div>
          <label class="label">
            <span class="label-text font-semibold">Model <span class="text-error">*</span></span>
          </label>
          <select name="default_model" class="select select-bordered w-full">
            <option value="gemini-2.5-flash" selected>gemini-2.5-flash (Recommended)</option>
            <option value="gemini-2.5-pro">gemini-2.5-pro</option>
            <option value="gemini-3-flash">gemini-3-flash</option>
            <option value="gemini-3-pro">gemini-3-pro</option>
            <option value="gemini-2.0-flash">gemini-2.0-flash</option>
          </select>
        </div>

        <!-- Test Connection -->
        <div>
          <button
            type="button"
            phx-click="test_connection_gemini"
            disabled={!@config["api_key"] || @testing}
            class={
              "btn btn-outline " <>
                if !@config["api_key"] || @testing do
                  "btn-disabled"
                else
                  ""
                end
            }
          >
            <%= if @testing do %>
              <span class="loading loading-spinner loading-sm"></span>
              Testing...
            <% else %>
              Test Connection
            <% end %>
          </button>
        </div>

        <!-- Test Result -->
        <%= if @test_result do %>
          <%= case @test_result do %>
            <% {:ok, _} -> %>
              <div class="alert alert-success">
                <span>✓ Connection successful! Ready to proceed.</span>
              </div>

            <% {:error, message} -> %>
              <div class="alert alert-error">
                <span><%= message %></span>
              </div>
          <% end %>
        <% end %>
      </form>
    </div>
    """
  end

  # Step 2: Configure Ollama
  defp render_step_2_ollama(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-2">Configure Ollama</h2>
      <p class="text-gray-600 mb-6">Connect to your local Ollama instance</p>

      <form phx-change="validate_ollama" class="space-y-6">
        <!-- Base URL -->
        <div>
          <label class="label">
            <span class="label-text font-semibold">Base URL <span class="text-error">*</span></span>
          </label>
          <input
            type="url"
            name="base_url"
            value={@config["base_url"] || "http://localhost:11434"}
            placeholder="http://localhost:11434"
            class="input input-bordered w-full"
          />
          <p class="text-sm text-gray-600 mt-2">
            <a href="https://ollama.ai" target="_blank" class="link link-primary">
              Install Ollama →
            </a>
          </p>
        </div>

        <!-- Discover Models -->
        <div>
          <button
            type="button"
            phx-click="discover_models"
            disabled={!@config["base_url"] || @discovering_models}
            class={
              "btn btn-outline " <>
                if !@config["base_url"] || @discovering_models do
                  "btn-disabled"
                else
                  ""
                end
            }
          >
            <%= if @discovering_models do %>
              <span class="loading loading-spinner loading-sm"></span>
              Discovering...
            <% else %>
              Discover Models
            <% end %>
          </button>
        </div>

        <!-- Model Selection -->
        <div>
          <label class="label">
            <span class="label-text font-semibold">Model <span class="text-error">*</span></span>
          </label>
          <select name="default_model" class="select select-bordered w-full">
            <option value="">Select a model...</option>
            <%= for model <- @ollama_models do %>
              <option value={model} selected={@config["default_model"] == model}><%= model %></option>
            <% end %>
          </select>
          <%= if Enum.empty?(@ollama_models) do %>
            <p class="text-sm text-gray-600 mt-2">No models found. Please click "Discover Models" first.</p>
          <% end %>
        </div>

        <!-- Test Connection -->
        <div>
          <button
            type="button"
            phx-click="test_connection_ollama"
            disabled={!@config["default_model"] || @testing}
            class={
              "btn btn-outline " <>
                if !@config["default_model"] || @testing do
                  "btn-disabled"
                else
                  ""
                end
            }
          >
            <%= if @testing do %>
              <span class="loading loading-spinner loading-sm"></span>
              Testing...
            <% else %>
              Test Connection
            <% end %>
          </button>
        </div>

        <!-- Test Result -->
        <%= if @test_result do %>
          <%= case @test_result do %>
            <% {:ok, _} -> %>
              <div class="alert alert-success">
                <span>✓ Connection successful! Ready to proceed.</span>
              </div>

            <% {:error, message} -> %>
              <div class="alert alert-error">
                <span><%= message %></span>
              </div>
          <% end %>
        <% end %>
      </form>
    </div>
    """
  end

  # Step 3: Review & Complete
  defp render_step_3(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-6">Review Your Setup</h2>

      <div class="bg-blue-50 border border-primary rounded-lg p-6">
        <div class="flex items-start gap-4">
          <div class="text-3xl">
            <%= if @provider_choice == "gemini" do %>
              ☁️
            <% else %>
              🖥️
            <% end %>
          </div>
          <div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">
              <%= String.capitalize(@provider_choice) %>
            </h3>
            <div class="text-sm text-gray-600 space-y-1">
              <p>✓ Provider configured</p>
              <p>
                <%= case @test_result do %>
                  <% {:ok, _} -> %>
                    <span class="text-success">✓ Connection verified</span>
                  <% _ -> %>
                    <span class="text-error">✗ Connection not tested</span>
                <% end %>
              </p>
              <p>✓ Set as primary provider</p>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-6 bg-green-50 border border-success rounded-lg p-4">
        <h4 class="font-semibold text-gray-900 mb-2">You're all set! 🎉</h4>
        <p class="text-sm text-gray-600">
          You can now use AI features in Clientats. You can configure additional providers or adjust settings at any time.
        </p>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("choose_provider", %{"provider" => provider}, socket) do
    {:noreply,
     socket
     |> assign(:provider_choice, provider)
     |> assign(:connection_tested, false)
     |> assign(:test_result, nil)}
  end

  def handle_event("next", _, socket) do
    new_step = min(socket.assigns.current_step + 1, 3)
    {:noreply, assign(socket, :current_step, new_step)}
  end

  def handle_event("back", _, socket) do
    new_step = max(socket.assigns.current_step - 1, 1)
    {:noreply, assign(socket, :current_step, new_step)}
  end

  def handle_event("cancel", _, socket) do
    {:noreply, redirect(socket, to: ~p"/dashboard")}
  end

  def handle_event("validate_gemini", %{"api_key" => api_key, "default_model" => model}, socket) do
    {:noreply,
     assign(socket, :gemini_config, %{
       "api_key" => api_key,
       "default_model" => model,
       "vision_model" => model,
       "text_model" => model
     })}
  end

  def handle_event("validate_ollama", %{"base_url" => base_url, "default_model" => model}, socket) do
    {:noreply,
     assign(socket, :ollama_config, %{
       "base_url" => base_url,
       "default_model" => model
     })}
  end

  def handle_event("discover_models", _, socket) do
    send(self(), :discover_models)
    {:noreply, assign(socket, :discovering_models, true)}
  end

  def handle_event("test_connection_gemini", _, socket) do
    send(self(), {:test_connection, :gemini})
    {:noreply, assign(socket, :testing, true)}
  end

  def handle_event("test_connection_ollama", _, socket) do
    send(self(), {:test_connection, :ollama})
    {:noreply, assign(socket, :testing, true)}
  end

  def handle_event("complete", _, socket) do
    user_id = socket.assigns.user_id
    provider = socket.assigns.provider_choice
    config = if provider == "gemini", do: socket.assigns.gemini_config, else: socket.assigns.ollama_config

    # Enable the provider by default when creating from wizard
    config_with_enabled = Map.put(config, "enabled", true)

    case LLMConfig.save_provider_config(user_id, provider, config_with_enabled) do
      {:ok, _setting} ->
        # Set as primary provider
        LLMConfig.set_primary_provider(user_id, provider)

        {:noreply,
         socket
         |> put_flash(:info, "LLM provider configured successfully!")
         |> redirect(to: ~p"/dashboard")}

      {:error, _changeset} ->
        {:noreply, assign(socket, :save_success, "Error saving configuration")}
    end
  end

  # Async handlers

  @impl true
  def handle_info(:discover_models, socket) do
    base_url = socket.assigns.ollama_config["base_url"] || "http://localhost:11434"

    case LLMConfig.test_connection(:ollama, %{base_url: base_url}) do
      {:ok, _} ->
        # Try to fetch models
        case fetch_ollama_models(base_url) do
          {:ok, models} ->
            {:noreply,
             socket
             |> assign(:ollama_models, models)
             |> assign(:discovering_models, false)}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:discovering_models, false)
             |> assign(:test_result, {:error, "Could not discover models"})}
        end

      {:error, message} ->
        {:noreply,
         socket
         |> assign(:discovering_models, false)
         |> assign(:test_result, {:error, message})}
    end
  end

  def handle_info({:test_connection, provider}, socket) do
    config = if provider == :gemini, do: socket.assigns.gemini_config, else: socket.assigns.ollama_config

    result = LLMConfig.test_connection(provider, config)

    {:noreply,
     socket
     |> assign(:testing, false)
     |> assign(:test_result, result)
     |> assign(:connection_tested, match?({:ok, _}, result))}
  end

  # Helpers

  defp step_class(step_num, current_step) do
    if step_num == current_step do
      "flex items-center"
    else
      "flex items-center"
    end
  end

  defp fetch_ollama_models(base_url) do
    try do
      case Req.get!("#{base_url}/api/tags", receive_timeout: 5000) do
        %{status: 200, body: body} ->
          case Jason.decode(body) do
            {:ok, %{"models" => models}} ->
              # Extract model names
              model_names = Enum.map(models, & &1["name"])
              {:ok, model_names}

            _ ->
              {:error, "Invalid response format"}
          end

        _ ->
          {:error, "Could not connect to Ollama"}
      end
    rescue
      _ -> {:error, "Connection failed"}
    end
  end
end
