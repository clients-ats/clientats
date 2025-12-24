defmodule ClientatsWeb.JobApplicationLive.CoverLetterEditor do
  use ClientatsWeb, :live_component
  alias Clientats.Jobs

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
                    <h3 class="text-xl font-semibold leading-6 text-gray-900" id="modal-title">Edit Cover Letter</h3>
                    <button
                      type="button"
                      phx-click="generate_ai"
                      phx-target={@myself}
                      phx-disable-with="Generating..."
                      disabled={@generating}
                      class="btn btn-sm btn-primary"
                    >
                      <.icon name="hero-sparkles" class="w-4 h-4 mr-2" />
                      Generate with AI
                    </button>
                  </div>
                  
                  <%= if @error do %>
                    <div class="alert alert-error mb-4">
                      <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                      <span>{@error}</span>
                    </div>
                  <% end %>

                  <div class="mt-2">
                    <.form
                      for={@form}
                      id="cover-letter-form"
                      phx-target={@myself}
                      phx-change="validate"
                      phx-submit="save"
                    >
                      <.input
                        field={@form[:cover_letter_content]}
                        type="textarea"
                        label="Content"
                        class="h-96 font-mono text-sm"
                        rows="20"
                        placeholder="Your cover letter will appear here..."
                      />
                      <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
                        <.button phx-disable-with="Saving..." class="w-full sm:ml-3 sm:w-auto">Save</.button>
                        <button
                          type="button"
                          class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto"
                          phx-click="cancel"
                          phx-target={@myself}
                        >Cancel</button>
                      </div>
                    </.form>
                  </div>
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
  def update(%{generated_content: content} = _assigns, socket) do
    # Update the form with the generated content
    changeset = 
      socket.assigns.job_application
      |> Jobs.change_job_application(%{cover_letter_content: content})
    
    {:ok,
     socket
     |> assign(:generating, false)
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

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:generating, false)
     |> assign(:error, nil)
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
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("generate_ai", _, socket) do
    job_desc = socket.assigns.job_application.job_description

    if is_nil(job_desc) || String.trim(job_desc) == "" do
      {:noreply, assign(socket, :error, "Job description is missing. Cannot generate cover letter.")}
    else
      # Notify parent to start generation
      notify_parent({:generate_cover_letter, job_desc})
      {:noreply, assign(socket, :generating, true)}
    end
  end

  def handle_event("cancel", _, socket) do
    notify_parent(:cancel_edit)
    {:noreply, socket}
  end

  # Handle the result of the async task (Standard LiveView behavior for Task.async)
  # But wait, `handle_info` is on the LiveView, not the Component?
  # No, Components *can* handle info if they target themselves... but Task.async sends to the PID of the LiveView process.
  # So the `handle_info` needs to be in the parent LiveView, which then updates the component?
  # OR, we use `assign_async`? `assign_async` is available in newer LiveView versions.
  # Let's check `mix.lock` for `phoenix_live_view` version.
  
  # For now, I'll assume standard `handle_info` in parent.
  # If I spawn a Task from the component, the message goes to the LiveView process.
  # The LiveView needs to receive it and send_update to the component.
  # This makes the component coupled to the parent.
  
  # Alternative: Use `send_update` from the task?
  # `send_update(ClientatsWeb.JobApplicationLive.CoverLetterEditor, id: "cover-letter-editor", generated_content: content)`
  
  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
