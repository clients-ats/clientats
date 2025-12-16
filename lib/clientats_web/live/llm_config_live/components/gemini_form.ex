defmodule ClientatsWeb.LLMConfigLive.Components.GeminiForm do
  use Phoenix.Component

  def render(assigns) do
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
end
