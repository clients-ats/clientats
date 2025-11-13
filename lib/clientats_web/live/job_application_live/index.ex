defmodule ClientatsWeb.JobApplicationLive.Index do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My Applications")
     |> assign(:applications, Jobs.list_job_applications(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    application = Jobs.get_job_application!(id)
    {:ok, _} = Jobs.delete_job_application(application)

    {:noreply,
     socket
     |> put_flash(:info, "Application deleted successfully")
     |> assign(:applications, Jobs.list_job_applications(socket.assigns.current_user.id))}
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
          <.link navigate={~p"/dashboard/applications/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-5 h-5" /> New Application
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-6xl">
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-gray-900">My Job Applications</h1>
          <p class="text-sm text-gray-600 mt-1">Track all your job applications</p>
        </div>

        <%= if @applications == [] do %>
          <div class="bg-white rounded-lg shadow p-12 text-center">
            <.icon name="hero-document-text" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
            <p class="text-gray-500 mb-4">No applications yet</p>
            <.link navigate={~p"/dashboard/applications/new"} class="btn btn-primary">
              Record Your First Application
            </.link>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for application <- @applications do %>
              <div class="bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow cursor-pointer" phx-click="select" phx-value-id={application.id}>
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-gray-900"><%= application.position_title %></h3>
                    <p class="text-md text-gray-600"><%= application.company_name %></p>
                    <%= if application.location do %>
                      <p class="text-sm text-gray-500 mt-1"><%= application.location %></p>
                    <% end %>
                    <div class="flex items-center gap-3 mt-2">
                      <span class="text-sm text-gray-500">
                        Applied <%= Calendar.strftime(application.application_date, "%b %d, %Y") %>
                      </span>
                      <%= if application.job_interest do %>
                        <span class="badge badge-sm badge-outline">
                          From Interest
                        </span>
                      <% end %>
                    </div>
                  </div>
                  <div class="flex flex-col items-end gap-2">
                    <span class={"badge " <> status_color(application.status)}>
                      <%= format_status(application.status) %>
                    </span>
                    <.link navigate={~p"/dashboard/applications/#{application}"} class="btn btn-xs">
                      View Details
                    </.link>
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

  defp status_color("applied"), do: "badge-info"
  defp status_color("phone_screen"), do: "badge-primary"
  defp status_color("interview_scheduled"), do: "badge-warning"
  defp status_color("interviewed"), do: "badge-warning"
  defp status_color("offer_received"), do: "badge-success"
  defp status_color("offer_accepted"), do: "badge-success"
  defp status_color("rejected"), do: "badge-error"
  defp status_color("withdrawn"), do: "badge-ghost"
  defp status_color(_), do: "badge-ghost"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
