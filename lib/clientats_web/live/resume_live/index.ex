defmodule ClientatsWeb.ResumeLive.Index do
  use ClientatsWeb, :live_view

  alias Clientats.Documents

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My Resumes")
     |> assign(:resumes, Documents.list_resumes(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    resume = Documents.get_resume!(id)
    {:ok, _} = Documents.delete_resume(resume)

    {:noreply,
     socket
     |> put_flash(:info, "Resume deleted successfully")
     |> assign(:resumes, Documents.list_resumes(socket.assigns.current_user.id))}
  end

  def handle_event("set_default", %{"id" => id}, socket) do
    resume = Documents.get_resume!(id)
    {:ok, _} = Documents.set_default_resume(resume)

    {:noreply,
     socket
     |> put_flash(:info, "Default resume updated")
     |> assign(:resumes, Documents.list_resumes(socket.assigns.current_user.id))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4 flex justify-between items-center">
          <.link navigate={~p"/dashboard"} class="text-blue-600 hover:text-blue-800">
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Dashboard
          </.link>
          <.link navigate={~p"/dashboard/resumes/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-5 h-5" /> Upload Resume
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-gray-900">My Resumes</h1>
          <p class="text-sm text-gray-600 mt-1">Manage your resume versions</p>
        </div>

        <%= if @resumes == [] do %>
          <div class="bg-white rounded-lg shadow p-12 text-center">
            <.icon name="hero-document-text" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
            <p class="text-gray-500 mb-4">No resumes uploaded yet</p>
            <.link navigate={~p"/dashboard/resumes/new"} class="btn btn-primary">
              Upload Your First Resume
            </.link>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for resume <- @resumes do %>
              <div class="bg-white rounded-lg shadow p-6">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2">
                      <h3 class="text-lg font-semibold text-gray-900">{resume.name}</h3>
                      <%= if resume.is_default do %>
                        <span class="badge badge-primary badge-sm">Default</span>
                      <% end %>
                    </div>
                    <%= if resume.description do %>
                      <p class="text-sm text-gray-600 mt-1">{resume.description}</p>
                    <% end %>
                    <div class="flex items-center gap-4 mt-2 text-sm text-gray-500">
                      <span>{resume.original_filename}</span>
                      <%= if resume.file_size do %>
                        <span>{format_file_size(resume.file_size)}</span>
                      <% end %>
                      <span>Uploaded {Calendar.strftime(resume.inserted_at, "%b %d, %Y")}</span>
                    </div>
                  </div>
                  <div class="flex gap-2">
                    <%= if !resume.is_default do %>
                      <.button
                        phx-click="set_default"
                        phx-value-id={resume.id}
                        class="btn btn-sm btn-outline"
                      >
                        Set as Default
                      </.button>
                    <% end %>
                    <.link navigate={~p"/dashboard/resumes/#{resume}/edit"} class="btn btn-sm">
                      Edit
                    </.link>
                    <.button
                      phx-click="delete"
                      phx-value-id={resume.id}
                      data-confirm="Are you sure you want to delete this resume?"
                      class="btn btn-sm btn-error"
                    >
                      Delete
                    </.button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_file_size(bytes),
    do: "#{Float.round(bytes / 1024 / 1024, 1)} MB"
end
