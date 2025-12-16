defmodule ClientatsWeb.LLMConfigLive.Components.OllamaForm do
  use Phoenix.Component

  def render(assigns) do
    text_models =
      Enum.filter(assigns[:ollama_models] || [], fn m -> !m.vision end)

    vision_models =
      Enum.filter(assigns[:ollama_models] || [], fn m -> m.vision end)

    assigns =
      assigns
      |> assign(:text_models, text_models)
      |> assign(:vision_models, vision_models)

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
            id="ollama_base_url"
            name="setting[base_url]"
            placeholder="http://localhost:11434"
            class="input input-bordered flex-1"
            value={@provider_config && @provider_config.base_url}
          />
          <button
            type="button"
            phx-click="discover_ollama_models"
            phx-value-base_url={@provider_config && @provider_config.base_url}
            disabled={@discovering_models}
            class="btn btn-primary"
            onclick="this.setAttribute('phx-value-base_url', document.getElementById('ollama_base_url').value)"
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
end
