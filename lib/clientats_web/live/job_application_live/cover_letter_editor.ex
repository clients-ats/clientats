defmodule ClientatsWeb.JobApplicationLive.CoverLetterEditor do
  use ClientatsWeb, :live_component
  alias Clientats.Jobs
  alias Clientats.LLMConfig
  alias Clientats.Documents

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity z-40"></div>
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-4xl">
            <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
              <div class="sm:flex sm:items-start">
                <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left w-full">
                  <div class="flex justify-between items-center mb-4">
                    <h3 class="text-xl font-semibold leading-6 text-gray-900" id="modal-title">
                      Edit Cover Letter
                    </h3>
                    <div class="flex gap-2">
                      <button
                        type="button"
                        phx-click="toggle_preview"
                        phx-target={@myself}
                        class="btn btn-sm btn-outline"
                      >
                        <.icon
                          name={if @preview_mode, do: "hero-pencil", else: "hero-eye"}
                          class="w-4 h-4 mr-2"
                        />
                        {if @preview_mode, do: "Edit", else: "Preview"}
                      </button>
                      <%= if @llm_available do %>
                        <button
                          type="button"
                          phx-click="open_custom_prompt"
                          phx-target={@myself}
                          class="btn btn-sm btn-outline"
                          title="Customize AI prompt"
                        >
                          <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                        </button>
                        <button
                          type="button"
                          phx-click="generate_ai"
                          phx-target={@myself}
                          disabled={@generating}
                          class={"btn btn-sm #{if @generating, do: "btn-disabled loading", else: "btn-primary"}"}
                        >
                          <%= if @generating do %>
                            <span class="loading loading-spinner loading-xs mr-2"></span>
                            Generating...
                          <% else %>
                            <.icon name="hero-sparkles" class="w-4 h-4 mr-2" /> Generate with AI
                            <%= if @custom_prompt do %>
                              <span class="ml-2 px-2 py-0.5 bg-blue-100 text-blue-700 text-xs rounded">Custom</span>
                            <% end %>
                          <% end %>
                        </button>
                        <%= if @has_generated_content do %>
                          <button
                            type="button"
                            phx-click="regenerate_ai"
                            phx-target={@myself}
                            disabled={@generating}
                            class={"btn btn-sm btn-outline #{if @generating, do: "btn-disabled", else: ""}"}
                          >
                            <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Regenerate
                          </button>
                        <% end %>
                      <% else %>
                        <div
                          class="tooltip"
                          data-tip="Configure an LLM provider in settings to use AI generation"
                        >
                          <button
                            type="button"
                            disabled
                            class="btn btn-sm btn-disabled"
                          >
                            <.icon name="hero-sparkles" class="w-4 h-4 mr-2" /> Generate with AI
                          </button>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <%= if @regenerating do %>
                    <div class="alert alert-warning mb-4">
                      <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                      <div class="flex-1">
                        <p class="font-semibold">
                          Replace current content with a new AI-generated version?
                        </p>
                        <p class="text-sm mt-1">
                          Your previous version will be saved, allowing you to revert if needed.
                        </p>
                        <div class="flex gap-2 mt-2">
                          <button
                            type="button"
                            phx-click="confirm_regenerate"
                            phx-target={@myself}
                            class="btn btn-sm btn-warning"
                          >
                            Yes, Regenerate
                          </button>
                          <button
                            type="button"
                            phx-click="cancel_regenerate"
                            phx-target={@myself}
                            class="btn btn-sm btn-ghost"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>

                  <%= if @generating do %>
                    <div class="alert alert-info mb-4">
                      <span class="loading loading-spinner loading-sm"></span>
                      <span>
                        Generating your personalized cover letter... This may take up to 60 seconds.
                      </span>
                    </div>
                  <% end %>

                  <%= if @previous_content do %>
                    <div class="alert alert-info mb-4">
                      <.icon name="hero-information-circle" class="w-5 h-5" />
                      <div class="flex-1">
                        <span>Previous version saved.</span>
                        <button
                          type="button"
                          phx-click="revert_to_previous"
                          phx-target={@myself}
                          class="btn btn-xs btn-ghost ml-2 underline"
                        >
                          Revert to previous version
                        </button>
                      </div>
                    </div>
                  <% end %>

                  <%= if @error do %>
                    <div class="alert alert-error mb-4">
                      <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                      <span>
                        {@error}
                        <%= if String.contains?(@error, "No resume found") do %>
                          <.link
                            navigate={~p"/dashboard/resumes/new"}
                            class="underline font-medium ml-1"
                          >
                            Upload one here
                          </.link>
                        <% end %>
                      </span>
                    </div>
                  <% end %>

                  <%= if @save_template_mode do %>
                    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                      <h4 class="font-semibold text-blue-900 mb-3">Save as Template</h4>
                      <form phx-submit="save_as_template" phx-target={@myself}>
                        <div class="mb-3">
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Template Name
                          </label>
                          <input
                            type="text"
                            name="template_name"
                            required
                            class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                            placeholder="e.g., Software Engineer Template"
                          />
                        </div>
                        <div class="mb-3">
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Description (optional)
                          </label>
                          <input
                            type="text"
                            name="template_description"
                            class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                            placeholder="e.g., For software engineering positions"
                          />
                        </div>
                        <div class="flex gap-2">
                          <button type="submit" class="btn btn-sm btn-primary">Save Template</button>
                          <button
                            type="button"
                            phx-click="cancel_save_template"
                            phx-target={@myself}
                            class="btn btn-sm btn-ghost"
                          >
                            Cancel
                          </button>
                        </div>
                      </form>
                    </div>
                  <% end %>

                  <div class="mt-2">
                    <%= if not @preview_mode do %>
                      <div class="mb-4 p-3 bg-gray-50 rounded-lg border border-gray-200">
                        <label class="block text-sm font-medium text-gray-700 mb-2">
                          <.icon name="hero-document-text" class="w-4 h-4 inline" />
                          Templates
                        </label>
                        <div class="flex gap-2">
                          <select
                            phx-change="select_template"
                            phx-target={@myself}
                            name="template_id"
                            class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm bg-white"
                          >
                            <option value="">Select a template...</option>
                            <%= for template <- @templates do %>
                              <option value={template.id} selected={@selected_template_id == template.id}>
                                {template.name}
                                <%= if template.is_default do %> (Default)<% end %>
                              </option>
                            <% end %>
                          </select>
                          <%= if @selected_template_id do %>
                            <button
                              type="button"
                              phx-click="load_template"
                              phx-target={@myself}
                              class="btn btn-sm btn-primary"
                            >
                              <.icon name="hero-arrow-down-tray" class="w-4 h-4 mr-1" />
                              Load
                            </button>
                          <% end %>
                        </div>
                        <%= if @selected_template_id && @selected_template_description do %>
                          <p class="mt-1 text-xs text-gray-500 italic">{@selected_template_description}</p>
                        <% end %>
                        <%= if @loaded_template_name do %>
                          <div class="mt-2 text-sm text-blue-600">
                            <.icon name="hero-check-circle" class="w-4 h-4 inline" />
                            Content loaded from: {@loaded_template_name}
                          </div>
                        <% end %>
                      </div>
                    <% end %>

                    <.form
                      for={@form}
                      id="cover-letter-form"
                      phx-target={@myself}
                      phx-change="validate"
                      phx-submit="save"
                    >
                      <%= if @preview_mode do %>
                        <div class="mb-4">
                          <label class="block text-sm font-medium leading-6 text-gray-900 mb-2">
                            Preview
                          </label>
                          <div
                            class="border rounded-lg p-8 bg-white shadow-sm"
                            style="font-family: serif; line-height: 1.6; color: #333; max-width: 800px; min-height: 24rem;"
                          >
                            <div class="mb-10">
                              <strong>{@current_user.first_name} {@current_user.last_name}</strong>
                              <br />
                              {@current_user.email}
                            </div>

                            <div class="mb-5">
                              {Date.utc_today() |> Calendar.strftime("%B %d, %Y")}
                            </div>

                            <div style="white-space: pre-wrap;">
                              {@form[:cover_letter_content].value || "No content provided."}
                            </div>
                          </div>
                        </div>
                      <% else %>
                        <.input
                          field={@form[:cover_letter_content]}
                          type="textarea"
                          label="Content"
                          class="h-96 font-mono text-sm"
                          rows="20"
                          placeholder="Your cover letter will appear here..."
                          phx-hook="CoverLetterAutoSave"
                          data-job-application-id={@job_application.id}
                        />
                      <% end %>
                      <div class="mt-2 text-sm text-gray-600">
                        {count_stats(@form[:cover_letter_content].value)}
                        <span class="text-gray-400 ml-2">• Recommended: 250-400 words</span>
                      </div>
                      <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse gap-2">
                        <.button phx-disable-with="Saving..." class="w-full sm:w-auto">
                          Save
                        </.button>
                        <%= if not is_nil(@form[:cover_letter_content].value) and String.trim(@form[:cover_letter_content].value || "") != "" do %>
                          <button
                            type="button"
                            phx-click="show_save_template"
                            phx-target={@myself}
                            class="btn btn-sm btn-outline w-full sm:w-auto"
                          >
                            <.icon name="hero-bookmark" class="w-4 h-4 mr-1" />
                            Save as Template
                          </button>
                        <% end %>
                        <button
                          type="button"
                          class="inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:w-auto"
                          phx-click="cancel"
                          phx-target={@myself}
                        >
                          Cancel
                        </button>
                      </div>
                    </.form>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Custom Prompt Modal -->
      <.live_component
        :if={@show_custom_prompt_modal}
        module={ClientatsWeb.JobApplicationLive.CustomPromptModal}
        id="custom-prompt-modal"
        show={@show_custom_prompt_modal}
        custom_prompt={@custom_prompt}
      />
    </div>
    """
  end

  @impl true
  def update(%{generated_content: content} = _assigns, socket) do
    # Store current content as previous before updating
    current_content = socket.assigns.form[:cover_letter_content].value

    previous_content =
      if current_content && String.trim(current_content) != "",
        do: current_content,
        else: socket.assigns.previous_content

    # Update the form with the generated content
    changeset =
      socket.assigns.job_application
      |> Jobs.change_job_application(%{cover_letter_content: content})

    {:ok,
     socket
     |> assign(:generating, false)
     |> assign(:regenerating, false)
     |> assign(:has_generated_content, true)
     |> assign(:previous_content, previous_content)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def update(%{generation_error: error} = _assigns, socket) do
    {:ok,
     socket
     |> assign(:generating, false)
     |> assign(:error, error)}
  end

  @impl true
  def update(%{job_application: job_application} = assigns, socket) do
    changeset = Jobs.change_job_application(job_application)

    # Check if user has any enabled LLM providers
    llm_available =
      case assigns[:current_user] do
        nil ->
          false

        user ->
          enabled_providers = LLMConfig.get_enabled_providers(user.id)
          length(enabled_providers) > 0
      end

    # Load templates for the current user
    templates =
      case assigns[:current_user] do
        nil -> []
        user -> Documents.list_cover_letter_templates(user.id)
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:generating, false)
     |> assign(:regenerating, false)
     |> assign(:error, nil)
     |> assign(:preview_mode, false)
     |> assign(:save_template_mode, false)
     |> assign(:templates, templates)
     |> assign(:selected_template_id, nil)
     |> assign(:selected_template_description, nil)
     |> assign(:loaded_template_name, nil)
     |> assign(:llm_available, llm_available)
     |> assign(:has_generated_content, false)
     |> assign(:previous_content, nil)
     |> assign(:custom_prompt, nil)
     |> assign(:show_custom_prompt_modal, false)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"job_application" => params}, socket) do
    changeset =
      socket.assigns.job_application
      |> Jobs.change_job_application(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"job_application" => params}, socket) do
    case Jobs.update_job_application(socket.assigns.job_application, params) do
      {:ok, job_application} ->
        notify_parent({:saved, job_application})

        {:noreply,
         socket
         |> push_event("draft_saved_to_server", %{})}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("generate_ai", _, socket) do
    job_desc = socket.assigns.job_application.job_description
    user = socket.assigns.current_user

    cond do
      is_nil(job_desc) || String.trim(job_desc) == "" ->
        {:noreply,
         assign(
           socket,
           :error,
           "Job description is required for AI generation. Please add a job description to the application first."
         )}

      is_nil(Documents.get_default_resume(user.id)) ->
        {:noreply,
         assign(
           socket,
           :error,
           "No resume found. Upload one in Settings to enable AI generation."
         )}

      true ->
        # Notify parent to start generation with custom prompt
        notify_parent({:generate_cover_letter, job_desc, socket.assigns.custom_prompt})
        {:noreply, assign(socket, :generating, true)}
    end
  end

  def handle_event("cancel", _, socket) do
    notify_parent(:cancel_edit)
    {:noreply, socket}
  end

  def handle_event("toggle_preview", _, socket) do
    {:noreply, assign(socket, :preview_mode, !socket.assigns.preview_mode)}
  end

  def handle_event("regenerate_ai", _, socket) do
    # Show confirmation dialog
    {:noreply, assign(socket, :regenerating, true)}
  end

  def handle_event("confirm_regenerate", _, socket) do
    job_desc = socket.assigns.job_application.job_description
    user = socket.assigns.current_user

    cond do
      is_nil(job_desc) || String.trim(job_desc) == "" ->
        {:noreply,
         socket
         |> assign(:regenerating, false)
         |> assign(
           :error,
           "Job description is required for AI generation. Please add a job description to the application first."
         )}

      is_nil(Documents.get_default_resume(user.id)) ->
        {:noreply,
         socket
         |> assign(:regenerating, false)
         |> assign(:error, "No resume found. Upload one in Settings to enable AI generation.")}

      true ->
        # Store current content as previous before regenerating
        current_content = socket.assigns.form[:cover_letter_content].value

        socket =
          if current_content && String.trim(current_content) != "" do
            assign(socket, :previous_content, current_content)
          else
            socket
          end

        # Notify parent to start generation with custom prompt
        notify_parent({:generate_cover_letter, job_desc, socket.assigns.custom_prompt})

        {:noreply,
         socket
         |> assign(:generating, true)
         |> assign(:regenerating, false)}
    end
  end

  def handle_event("cancel_regenerate", _, socket) do
    {:noreply, assign(socket, :regenerating, false)}
  end

  def handle_event("revert_to_previous", _, socket) do
    case socket.assigns.previous_content do
      nil ->
        {:noreply, socket}

      previous_content ->
        # Swap current and previous content
        current_content = socket.assigns.form[:cover_letter_content].value

        changeset =
          socket.assigns.job_application
          |> Jobs.change_job_application(%{cover_letter_content: previous_content})

        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:previous_content, current_content)}
    end
  end

  def handle_event("select_template", %{"template_id" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:selected_template_id, nil)
     |> assign(:selected_template_description, nil)}
  end

  def handle_event("select_template", %{"template_id" => template_id}, socket) do
    template = Enum.find(socket.assigns.templates, &(&1.id == String.to_integer(template_id)))

    {:noreply,
     socket
     |> assign(:selected_template_id, String.to_integer(template_id))
     |> assign(:selected_template_description, template && template.description)}
  end

  def handle_event("load_template", _, socket) do
    case socket.assigns.selected_template_id do
      nil ->
        {:noreply, assign(socket, :error, "Please select a template first")}

      template_id ->
        template = Documents.get_cover_letter_template!(template_id)

        changeset =
          socket.assigns.job_application
          |> Jobs.change_job_application(%{cover_letter_content: template.content})

        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:loaded_template_name, template.name)
         |> assign(:error, nil)}
    end
  end

  def handle_event("show_save_template", _, socket) do
    {:noreply, assign(socket, :save_template_mode, true)}
  end

  def handle_event("cancel_save_template", _, socket) do
    {:noreply, assign(socket, :save_template_mode, false)}
  end

  def handle_event("save_as_template", params, socket) do
    content = socket.assigns.form[:cover_letter_content].value

    template_attrs = %{
      user_id: socket.assigns.current_user.id,
      name: params["template_name"],
      description: params["template_description"],
      content: content,
      is_default: false
    }

    case Documents.create_cover_letter_template(template_attrs) do
      {:ok, _template} ->
        # Reload templates
        templates = Documents.list_cover_letter_templates(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:save_template_mode, false)
         |> assign(:templates, templates)
         |> assign(:error, nil)}

      {:error, _changeset} ->
        {:noreply, assign(socket, :error, "Failed to save template. Please try again.")}
    end
  end

  def handle_event("open_custom_prompt", _, socket) do
    {:noreply, assign(socket, :show_custom_prompt_modal, true)}
  end

  # Handle updates from CustomPromptModal
  @impl true
  def handle_info({ClientatsWeb.JobApplicationLive.CustomPromptModal, {:custom_prompt_updated, prompt}}, socket) do
    {:noreply, assign(socket, custom_prompt: prompt, show_custom_prompt_modal: false)}
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp count_stats(nil), do: "0 characters • 0 words"

  defp count_stats(content) when is_binary(content) do
    char_count = String.length(content)
    word_count = content |> String.split(~r/\s+/, trim: true) |> length()
    "#{char_count} characters • #{word_count} words"
  end

  defp count_stats(_), do: "0 characters • 0 words"
end
