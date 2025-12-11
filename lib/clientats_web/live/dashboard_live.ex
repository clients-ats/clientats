defmodule ClientatsWeb.DashboardLive do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4 flex justify-between items-center">
          <h1 class="text-2xl font-bold text-gray-900">Clientats Dashboard</h1>
          <div class="flex items-center gap-4">
            <span class="text-gray-700">
              {@current_user.first_name} {@current_user.last_name}
            </span>
            <.link
              href={~p"/logout"}
              method="delete"
              class="text-sm text-gray-600 hover:text-gray-900"
            >
              Logout
            </.link>
          </div>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8">
        <div class="mb-8 flex gap-4">
          <.link navigate={~p"/dashboard/resumes"} class="btn btn-outline">
            <.icon name="hero-document-text" class="w-5 h-5" /> Manage Resumes
          </.link>
          <.link navigate={~p"/dashboard/cover-letters"} class="btn btn-outline">
            <.icon name="hero-document-duplicate" class="w-5 h-5" /> Cover Letter Templates
          </.link>
        </div>

        <div class="grid md:grid-cols-2 gap-8">
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-semibold text-gray-900">Job Interests</h2>
              <.link navigate={~p"/dashboard/job-interests/new"} class="btn btn-primary btn-sm">
                <.icon name="hero-plus" class="w-5 h-5" /> Add Interest
              </.link>
            </div>

            <%= if @job_interests == [] do %>
              <div class="text-center py-12 text-gray-500">
                No job interests yet. Start tracking opportunities!
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for interest <- @job_interests do %>
                  <div class="border rounded-lg p-4 hover:bg-gray-50 cursor-pointer" phx-click="select_interest" phx-value-id={interest.id}>
                    <div class="flex justify-between items-start">
                      <div class="flex-1">
                        <h3 class="font-semibold text-gray-900"><%= interest.position_title %></h3>
                        <p class="text-sm text-gray-600"><%= interest.company_name %></p>
                        <%= if interest.location do %>
                          <p class="text-sm text-gray-500"><%= interest.location %></p>
                        <% end %>
                      </div>
                      <div class="flex flex-col items-end gap-2">
                        <span class={"badge badge-sm " <> status_color(interest.status)}>
                          <%= format_status(interest.status) %>
                        </span>
                        <span class={"badge badge-sm badge-outline " <> priority_color(interest.priority)}>
                          <%= String.capitalize(interest.priority) %>
                        </span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-semibold text-gray-900">Applications</h2>
              <div class="flex items-center gap-3">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    class="toggle toggle-sm"
                    phx-click="toggle_closed"
                    checked={@show_closed}
                  />
                  <span class="text-xs text-gray-600">Show Closed</span>
                </label>
                <.link navigate={~p"/dashboard/applications/new"} class="btn btn-primary btn-sm">
                  <.icon name="hero-plus" class="w-5 h-5" /> Add Application
                </.link>
              </div>
            </div>

            <%= if @job_applications == [] do %>
              <div class="text-center py-12 text-gray-500">
                No applications yet. Convert your interests into applications!
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for application <- @job_applications do %>
                  <.link
                    navigate={~p"/dashboard/applications/#{application}"}
                    class="block border rounded-lg p-4 hover:bg-gray-50"
                  >
                    <div class="flex justify-between items-start">
                      <div class="flex-1">
                        <h3 class="font-semibold text-gray-900"><%= application.position_title %></h3>
                        <p class="text-sm text-gray-600"><%= application.company_name %></p>
                        <p class="text-xs text-gray-500 mt-1">
                          Applied <%= Calendar.strftime(application.application_date, "%b %d, %Y") %>
                        </p>
                      </div>
                      <span class={"badge badge-sm " <> app_status_color(application.status)}>
                        <%= format_status(application.status) %>
                      </span>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    job_interests = Jobs.list_job_interests(socket.assigns.current_user.id)
    all_applications = Jobs.list_job_applications(socket.assigns.current_user.id)
    filtered_applications = filter_applications(all_applications, false)

    {:ok,
     socket
     |> assign(:job_interests, job_interests)
     |> assign(:show_closed, false)
     |> assign(:all_applications, all_applications)
     |> assign(:job_applications, filtered_applications)
     |> stream(:job_interests, job_interests)
     |> stream(:job_applications, filtered_applications)}
  end

  def handle_event("select_interest", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard/job-interests/#{id}")}
  end

  def handle_event("toggle_closed", _params, socket) do
    show_closed = !socket.assigns.show_closed
    filtered_applications = filter_applications(socket.assigns.all_applications, show_closed)

    {:noreply,
     socket
     |> assign(:show_closed, show_closed)
     |> assign(:job_applications, filtered_applications)
     |> stream(:job_applications, filtered_applications, reset: true)}
  end

  defp status_color("interested"), do: "badge-info"
  defp status_color("researching"), do: "badge-warning"
  defp status_color("not_a_fit"), do: "badge-error"
  defp status_color("ready_to_apply"), do: "badge-success"
  defp status_color("applied"), do: "badge-primary"
  defp status_color(_), do: "badge-ghost"

  defp priority_color("high"), do: "text-red-600"
  defp priority_color("medium"), do: "text-yellow-600"
  defp priority_color("low"), do: "text-gray-600"
  defp priority_color(_), do: "text-gray-600"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp app_status_color("applied"), do: "badge-info"
  defp app_status_color("phone_screen"), do: "badge-primary"
  defp app_status_color("interview_scheduled"), do: "badge-warning"
  defp app_status_color("interviewed"), do: "badge-warning"
  defp app_status_color("offer_received"), do: "badge-success"
  defp app_status_color("offer_accepted"), do: "badge-success"
  defp app_status_color("rejected"), do: "badge-error"
  defp app_status_color("withdrawn"), do: "badge-ghost"
  defp app_status_color(_), do: "badge-ghost"

  defp filter_applications(applications, show_closed) do
    if show_closed do
      applications
    else
      Enum.reject(applications, &(&1.status in ["rejected", "withdrawn", "offer_accepted"]))
    end
  end
end
