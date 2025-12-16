defmodule ClientatsWeb.LLMConfigLive.Components.AnthropicForm do
  use Phoenix.Component

  def render(assigns) do
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
end
