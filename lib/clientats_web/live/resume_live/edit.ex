defmodule ClientatsWeb.ResumeLive.Edit do
  use ClientatsWeb, :live_view

  alias Clientats.Documents

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    resume = Documents.get_resume!(id)
    changeset = Documents.change_resume(resume)

    {:ok,
     socket
     |> assign(:page_title, "Edit Resume")
     |> assign(:resume, resume)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"resume" => resume_params}, socket) do
    changeset =
      socket.assigns.resume
      |> Documents.change_resume(resume_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"resume" => resume_params}, socket) do
    case Documents.update_resume(socket.assigns.resume, resume_params) do
      {:ok, _resume} ->
        {:noreply,
         socket
         |> put_flash(:info, "Resume updated successfully")
         |> push_navigate(to: ~p"/dashboard/resumes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4">
          <.link navigate={~p"/dashboard/resumes"} class="text-blue-600 hover:text-blue-800">
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Resumes
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-2xl">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Edit Resume</h2>
            <p class="text-sm text-gray-600 mt-1">Update resume details</p>
          </div>

          <.form for={@form} id="resume-form" phx-change="validate" phx-submit="save" class="space-y-4">
            <.input
              field={@form[:name]}
              type="text"
              label="Resume Name"
              placeholder="e.g., Software Engineer 2024"
              required
            />

            <.input
              field={@form[:description]}
              type="textarea"
              label="Description (Optional)"
              placeholder="e.g., Tailored for backend positions"
              rows="2"
            />

            <div class="p-4 bg-gray-50 rounded-lg">
              <p class="text-sm font-medium text-gray-700">Current File</p>
              <p class="text-sm text-gray-600 mt-1"><%= @resume.original_filename %></p>
              <p class="text-xs text-gray-500 mt-1">
                To change the file, delete this resume and upload a new one
              </p>
            </div>

            <.input field={@form[:is_default]} type="checkbox" label="Set as default resume" />

            <div>
              <.button phx-disable-with="Saving..." class="w-full">Update Resume</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
