defmodule ClientatsWeb.CoverLetterLive.Index do
  use ClientatsWeb, :live_view

  alias Clientats.Documents

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Cover Letter Templates")
     |> assign(
       :cover_letters,
       Documents.list_cover_letter_templates(socket.assigns.current_user.id)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    template = Documents.get_cover_letter_template!(id)
    {:ok, _} = Documents.delete_cover_letter_template(template)

    {:noreply,
     socket
     |> put_flash(:info, "Cover letter template deleted successfully")
     |> assign(
       :cover_letters,
       Documents.list_cover_letter_templates(socket.assigns.current_user.id)
     )}
  end

  def handle_event("set_default", %{"id" => id}, socket) do
    template = Documents.get_cover_letter_template!(id)
    {:ok, _} = Documents.set_default_cover_letter_template(template)

    {:noreply,
     socket
     |> put_flash(:info, "Default cover letter template updated")
     |> assign(
       :cover_letters,
       Documents.list_cover_letter_templates(socket.assigns.current_user.id)
     )}
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
          <.link navigate={~p"/dashboard/cover-letters/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-5 h-5" /> New Template
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-gray-900">Cover Letter Templates</h1>
          <p class="text-sm text-gray-600 mt-1">Manage reusable cover letter templates</p>
        </div>

        <%= if @cover_letters == [] do %>
          <div class="bg-white rounded-lg shadow p-12 text-center">
            <.icon name="hero-document-duplicate" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
            <p class="text-gray-500 mb-4">No cover letter templates yet</p>
            <.link navigate={~p"/dashboard/cover-letters/new"} class="btn btn-primary">
              Create Your First Template
            </.link>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for template <- @cover_letters do %>
              <div class="bg-white rounded-lg shadow p-6">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2">
                      <h3 class="text-lg font-semibold text-gray-900">{template.name}</h3>
                      <%= if template.is_default do %>
                        <span class="badge badge-primary badge-sm">Default</span>
                      <% end %>
                    </div>
                    <%= if template.description do %>
                      <p class="text-sm text-gray-600 mt-1">{template.description}</p>
                    <% end %>
                    <p class="text-sm text-gray-500 mt-2">
                      Created {Calendar.strftime(template.inserted_at, "%b %d, %Y")}
                    </p>
                  </div>
                  <div class="flex gap-2">
                    <%= if !template.is_default do %>
                      <.button
                        phx-click="set_default"
                        phx-value-id={template.id}
                        class="btn btn-sm btn-outline"
                      >
                        Set as Default
                      </.button>
                    <% end %>
                    <.link navigate={~p"/dashboard/cover-letters/#{template}/edit"} class="btn btn-sm">
                      Edit
                    </.link>
                    <.button
                      phx-click="delete"
                      phx-value-id={template.id}
                      data-confirm="Are you sure you want to delete this template?"
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
end
