defmodule ClientatsWeb.LLMConfigLive.Components.GeminiForm do
  use Phoenix.Component

  def render(assigns) do
    assigns =
      assign(assigns, :gemini_models, [
        {"gemini-2.5-pro - Powerful, most capable (recommended)", "gemini-2.5-pro"},
        {"gemini-2.5-flash - Fast, efficient, most balanced", "gemini-2.5-flash"},
        {"gemini-2.0-flash - Previous generation flash", "gemini-2.0-flash"},
        {"gemini-1.5-pro - Previous generation pro", "gemini-1.5-pro"},
        {"gemini-1.5-flash - Previous generation flash", "gemini-1.5-flash"}
      ])

    ~H"""
    <div class="space-y-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">API Key</span>
          <span class="label-text-alt text-gray-500">Required to use Google Gemini</span>
        </label>
        <input
          type="password"
          name="setting[api_key]"
          placeholder="Your Google Gemini API key"
          value={@provider_config && @provider_config.api_key}
          class="input input-bordered"
        />
        <span class="label-text-alt text-gray-600">
          Get your API key from
          <a href="https://aistudio.google.com/apikey" target="_blank" class="link link-primary">
            Google AI Studio
          </a>
        </span>
        <%= if @form_errors[:api_key] do %>
          <label class="label">
            <span class="label-text-alt text-error">{@form_errors[:api_key]}</span>
          </label>
        <% end %>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">
            Default Model
            <span class="badge badge-sm badge-success">Recommended: gemini-2.5-flash</span>
          </span>
          <span class="label-text-alt text-gray-500">Primary model for most tasks</span>
        </label>
        <select
          name="setting[default_model]"
          class="select select-bordered"
        >
          <option value="">Select a model...</option>
          <%= for {label, value} <- @gemini_models do %>
            <option
              value={value}
              selected={@provider_config && @provider_config.default_model == value}
            >
              {label}
            </option>
          <% end %>
        </select>
        <span class="label-text-alt text-gray-600">
          Used for text extraction and general processing. Falls back to Vision Model when image analysis is needed.
        </span>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">
            Vision Model <span class="badge badge-sm">Optional</span>
          </span>
          <span class="label-text-alt text-gray-500">Image and document analysis</span>
        </label>
        <select
          name="setting[vision_model]"
          class="select select-bordered"
        >
          <option value="">Select a model or leave empty for default...</option>
          <%= for {label, value} <- @gemini_models do %>
            <option
              value={value}
              selected={@provider_config && @provider_config.vision_model == value}
            >
              {label}
            </option>
          <% end %>
        </select>
        <span class="label-text-alt text-gray-600">
          Used when document images or visual content needs to be analyzed. Leave empty to use Default Model for vision tasks.
        </span>
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-semibold">
            Text Model <span class="badge badge-sm">Optional</span>
          </span>
          <span class="label-text-alt text-gray-500">Text-only operations</span>
        </label>
        <select
          name="setting[text_model]"
          class="select select-bordered"
        >
          <option value="">Select a model or leave empty for default...</option>
          <%= for {label, value} <- @gemini_models do %>
            <option
              value={value}
              selected={@provider_config && @provider_config.text_model == value}
            >
              {label}
            </option>
          <% end %>
        </select>
        <span class="label-text-alt text-gray-600">
          Used for text-only tasks when you want to use a faster or cheaper model. Falls back to Default Model if not specified.
        </span>
      </div>

      <div class="alert alert-info">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="stroke-current shrink-0 h-6 w-6"
          fill="none"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
        <div>
          <p class="font-semibold mb-2">Getting Started with Google Gemini</p>
          <ul class="text-sm list-disc list-inside space-y-1">
            <li>
              Get your API key from
              <a href="https://aistudio.google.com/apikey" target="_blank" class="link link-primary">
                Google AI Studio
              </a>
            </li>
            <li>
              Enable the Generative AI API in your
              <a href="https://console.cloud.google.com" target="_blank" class="link link-primary">
                Google Cloud Console
              </a>
            </li>
            <li>
              Available models: gemini-2.5-pro, gemini-2.5-flash (recommended), gemini-2.0-flash, gemini-1.5-pro
            </li>
            <li>Use the "Test Connection" button to verify your API key</li>
          </ul>
          <p class="text-sm mt-3 font-semibold">Security Notes:</p>
          <ul class="text-sm list-disc list-inside space-y-1">
            <li>Never share your API key or commit it to version control</li>
            <li>Consider using environment variables instead of storing keys in the database</li>
            <li>Monitor your API usage on the Google Cloud Console to avoid unexpected charges</li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
