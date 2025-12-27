defmodule ClientatsWeb.JobApplicationLive.CustomPromptModal do
  use ClientatsWeb, :live_component

  alias Clientats.LLM.PromptTemplates

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div :if={@show} class="relative z-50">
        <!-- Overlay -->
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-40"></div>

        <!-- Modal -->
        <div class="fixed inset-0 z-50 overflow-y-auto">
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-white shadow-xl transition-all w-full max-w-6xl max-h-[90vh] overflow-y-auto">
            <!-- Header -->
            <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">
                    Customize AI Prompt
                  </h3>
                  <p class="mt-1 text-sm text-gray-600">
                    Customize the prompt used to generate your cover letter. Use variables to personalize the output.
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="close"
                  phx-target={@myself}
                  class="text-gray-400 hover:text-gray-500"
                >
                  <.icon name="hero-x-mark" class="w-6 h-6" />
                </button>
              </div>
            </div>

            <!-- Content -->
            <div class="px-6 py-6">
              <!-- Validation Errors -->
              <%= if @validation_errors != [] do %>
                <div class="mb-4 rounded-md bg-red-50 p-4">
                  <div class="flex">
                    <.icon name="hero-exclamation-circle" class="w-5 h-5 text-red-400 mr-3" />
                    <div class="text-sm text-red-800">
                      <ul class="list-disc list-inside space-y-1">
                        <%= for error <- @validation_errors do %>
                          <li><%= error %></li>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Grid: Editor + Documentation -->
              <div class="grid grid-cols-2 gap-6">
                <!-- Left: Editor -->
                <div>
                  <div class="mb-4">
                    <label class="block text-sm font-medium text-gray-700 mb-2">
                      Custom Prompt Template
                    </label>
                    <textarea
                      id="custom-prompt-textarea"
                      phx-change="validate"
                      phx-debounce="300"
                      phx-target={@myself}
                      name="custom_prompt"
                      rows="20"
                      class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 font-mono text-sm"
                      placeholder={"Enter your custom prompt here. Use variables like {{JOB_DESCRIPTION}}, {{CANDIDATE_NAME}}, etc."}
                    ><%= @custom_prompt %></textarea>
                    <div class="mt-2 flex justify-between text-xs text-gray-500">
                      <span><%= character_count(@custom_prompt) %> characters</span>
                      <span class="text-gray-400">Min: 50 | Max: 4000</span>
                    </div>
                  </div>

                  <!-- Example Prompts -->
                  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
                    <h4 class="text-sm font-semibold text-blue-900 mb-2">Example Prompts</h4>
                    <div class="space-y-2">
                      <%= for example <- @example_prompts do %>
                        <button
                          type="button"
                          phx-click="load_example"
                          phx-value-example={example.name}
                          phx-target={@myself}
                          class="w-full text-left px-3 py-2 text-sm bg-white border border-blue-200 rounded hover:bg-blue-50 transition"
                        >
                          <div class="font-medium text-blue-900"><%= example.name %></div>
                          <div class="text-xs text-blue-700"><%= example.description %></div>
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>

                <!-- Right: Documentation -->
                <div>
                  <h4 class="text-sm font-semibold text-gray-900 mb-3">Available Variables</h4>
                  <p class="text-xs text-gray-600 mb-4">
                    Use these placeholders in your prompt. They will be replaced with actual data when generating the cover letter.
                  </p>

                  <div class="space-y-3 max-h-96 overflow-y-auto">
                    <%= for variable <- @available_variables do %>
                      <div class="border border-gray-200 rounded-lg p-3 bg-gray-50">
                        <div class="flex items-start justify-between">
                          <code class="text-sm font-mono text-blue-600"><%= variable.name %></code>
                          <button
                            type="button"
                            phx-click="copy_variable"
                            phx-value-variable={variable.name}
                            phx-target={@myself}
                            class="text-gray-400 hover:text-gray-600"
                            title="Copy to clipboard"
                          >
                            <.icon name="hero-clipboard" class="w-4 h-4" />
                          </button>
                        </div>
                        <p class="text-xs text-gray-700 mt-1"><%= variable.description %></p>
                        <p class="text-xs text-gray-500 mt-1 italic">Example: <%= variable.example %></p>
                      </div>
                    <% end %>
                  </div>

                  <!-- Important Notice -->
                  <div class="mt-4 bg-yellow-50 border border-yellow-200 rounded-lg p-3">
                    <div class="flex">
                      <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-yellow-400 mr-2" />
                      <div class="text-xs text-yellow-800">
                        <p class="font-semibold">Required:</p>
                        <p class="mt-1">Your prompt must include <code class="font-mono">{"{{JOB_DESCRIPTION}}"}</code> to generate relevant cover letters.</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Footer -->
            <div class="bg-gray-50 px-6 py-4 border-t border-gray-200 flex justify-between">
              <button
                type="button"
                phx-click="use_default"
                phx-target={@myself}
                class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Use Default Prompt
              </button>

              <div class="flex gap-3">
                <button
                  type="button"
                  phx-click="close"
                  phx-target={@myself}
                  class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="save"
                  phx-target={@myself}
                  class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700"
                >
                  Save Custom Prompt
                </button>
              </div>
            </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show, fn -> false end)
     |> assign_new(:custom_prompt, fn -> "" end)
     |> assign_new(:validation_errors, fn -> [] end)
     |> assign_new(:available_variables, fn -> PromptTemplates.get_available_variables() end)
     |> assign_new(:example_prompts, fn -> get_example_prompts() end)}
  end

  @impl true
  def handle_event("validate", %{"custom_prompt" => prompt}, socket) do
    case validate_prompt(prompt) do
      {:ok, _} ->
        {:noreply, assign(socket, custom_prompt: prompt, validation_errors: [])}

      {:error, errors} ->
        {:noreply, assign(socket, custom_prompt: prompt, validation_errors: errors)}
    end
  end

  @impl true
  def handle_event("save", _params, socket) do
    prompt = socket.assigns.custom_prompt

    case validate_prompt(prompt) do
      {:ok, _} ->
        notify_parent({:custom_prompt_updated, prompt})
        {:noreply, assign(socket, show: false, validation_errors: [])}

      {:error, errors} ->
        {:noreply, assign(socket, validation_errors: errors)}
    end
  end

  @impl true
  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, show: false, validation_errors: [])}
  end

  @impl true
  def handle_event("use_default", _params, socket) do
    notify_parent({:custom_prompt_updated, nil})
    {:noreply, assign(socket, show: false, custom_prompt: "", validation_errors: [])}
  end

  @impl true
  def handle_event("load_example", %{"example" => example_name}, socket) do
    example = Enum.find(socket.assigns.example_prompts, &(&1.name == example_name))

    if example do
      {:noreply, assign(socket, custom_prompt: example.prompt, validation_errors: [])}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("copy_variable", %{"variable" => variable}, socket) do
    # Variable copied - this would typically trigger a JS hook for clipboard
    # For now, just acknowledge
    {:noreply, socket}
  end

  # Private functions

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp character_count(nil), do: 0
  defp character_count(str), do: String.length(str)

  defp validate_prompt(""), do: {:ok, ""}
  defp validate_prompt(nil), do: {:ok, nil}

  defp validate_prompt(prompt) when is_binary(prompt) do
    errors = []

    errors =
      if String.length(prompt) < 50 do
        ["Prompt must be at least 50 characters" | errors]
      else
        errors
      end

    errors =
      if String.length(prompt) > 4000 do
        ["Prompt must not exceed 4000 characters" | errors]
      else
        errors
      end

    errors =
      unless String.contains?(prompt, "{{JOB_DESCRIPTION}}") do
        ["Prompt must contain {{JOB_DESCRIPTION}} variable" | errors]
      else
        errors
      end

    # Check for injection patterns
    injection_patterns = [
      ~r/ignore\s+(previous|above|all)\s+instructions/i,
      ~r/disregard\s+(previous|all)/i,
      ~r/forget\s+(everything|all)/i,
      ~r/you\s+are\s+now/i,
      ~r/system\s*:/i
    ]

    errors =
      if Enum.any?(injection_patterns, &Regex.match?(&1, prompt)) do
        ["Prompt contains potentially unsafe instructions" | errors]
      else
        errors
      end

    if Enum.empty?(errors) do
      {:ok, prompt}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp get_example_prompts do
    [
      %{
        name: "Concise & Direct",
        description: "Short, punchy cover letters (2-3 paragraphs)",
        prompt: """
        Generate a concise, direct cover letter for {{POSITION_TITLE}} at {{COMPANY_NAME}}.

        Job Requirements:
        {{JOB_DESCRIPTION}}

        Candidate: {{CANDIDATE_NAME}}
        Experience: {{RESUME_TEXT}}

        Instructions:
        - Maximum 3 paragraphs
        - Focus on top 3 relevant skills only
        - Use active voice and confident tone
        - Skip generic statements
        - End with specific call to action

        Return ONLY the cover letter text.
        """
      },
      %{
        name: "Story-Driven",
        description: "Narrative approach highlighting career journey",
        prompt: """
        Write a compelling, story-driven cover letter for {{CANDIDATE_NAME}} applying to {{POSITION_TITLE}} at {{COMPANY_NAME}}.

        Job Description:
        {{JOB_DESCRIPTION}}

        Candidate Background:
        {{RESUME_TEXT}}

        Structure:
        1. Opening Hook: Start with a relevant professional story or achievement
        2. Connection: Explain why this role aligns with career trajectory
        3. Value Proposition: Highlight 2-3 key skills from job requirements
        4. Enthusiasm: Show genuine interest in company/role
        5. Call to Action: Request interview

        Tone: Authentic, enthusiastic, professional
        Length: 300-350 words

        Return ONLY the cover letter text.
        """
      },
      %{
        name: "Technical Focus",
        description: "For engineering/technical roles with skill emphasis",
        prompt: """
        Create a technical cover letter for {{POSITION_TITLE}} at {{COMPANY_NAME}}.

        Job Requirements:
        {{JOB_DESCRIPTION}}

        Candidate: {{CANDIDATE_NAME}}
        Technical Background: {{RESUME_TEXT}}

        Requirements:
        - Lead with strongest technical achievement
        - Map 3-4 key technical skills to job requirements
        - Include specific technologies, frameworks, methodologies
        - Mention relevant projects or contributions
        - Show problem-solving approach
        - Keep to 4 paragraphs max

        Avoid: Generic statements, soft skills focus, excessive jargon

        Return ONLY the cover letter text.
        """
      }
    ]
  end
end
