defmodule ClientatsWeb.JobApplicationLive.ResumeSelector do
  use ClientatsWeb, :live_component

  alias Clientats.Documents

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    resumes = Documents.list_resumes(assigns.current_user.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:resumes, resumes)
     |> assign(:selected_resume_id, assigns.application.resume_id)}
  end

  @impl true
  def handle_event("select_resume", %{"resume_id" => resume_id}, socket) do
    {:noreply, assign(socket, :selected_resume_id, String.to_integer(resume_id))}
  end

  def handle_event("save", _params, socket) do
    send(self(), {:resume_selector, {:save, socket.assigns.selected_resume_id}})
    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {:resume_selector, :cancel})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div class="p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Change Resume</h3>

          <%= if @resumes == [] do %>
            <div class="p-4 bg-yellow-50 rounded-lg mb-4">
              <p class="text-sm text-yellow-800">
                No resumes available. Please upload a resume first.
              </p>
            </div>
          <% else %>
            <div class="space-y-2 mb-6">
              <%= for resume <- @resumes do %>
                <label class="flex items-center p-3 border rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
                  <input
                    type="radio"
                    name="resume_selection"
                    value={resume.id}
                    checked={@selected_resume_id == resume.id}
                    phx-click="select_resume"
                    phx-value-resume_id={resume.id}
                    phx-target={@myself}
                    class="radio radio-primary"
                  />
                  <div class="ml-3 flex-1">
                    <p class="font-medium text-gray-900">{resume.name}</p>
                    <%= if resume.description do %>
                      <p class="text-sm text-gray-600">{resume.description}</p>
                    <% end %>
                    <%= if resume.is_default do %>
                      <span class="inline-block mt-1 px-2 py-0.5 text-xs font-medium bg-blue-100 text-blue-800 rounded">
                        Default
                      </span>
                    <% end %>
                  </div>
                </label>
              <% end %>
            </div>
          <% end %>

          <div class="flex gap-3 justify-end">
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              class="btn btn-secondary btn-sm"
            >
              Cancel
            </button>
            <%= if @resumes != [] do %>
              <button
                type="button"
                phx-click="save"
                phx-target={@myself}
                class="btn btn-primary btn-sm"
              >
                Save
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
