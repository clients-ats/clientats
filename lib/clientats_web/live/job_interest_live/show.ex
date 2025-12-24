defmodule ClientatsWeb.JobInterestLive.Show do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    job_interest = Jobs.get_job_interest!(id)

    {:noreply,
     socket
     |> assign(:page_title, job_interest.position_title)
     |> assign(:job_interest, job_interest)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Jobs.delete_job_interest(socket.assigns.job_interest)

    {:noreply,
     socket
     |> put_flash(:info, "Job interest deleted successfully")
     |> push_navigate(to: ~p"/dashboard")}
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
          <div class="flex gap-2">
            <.link
              navigate={~p"/dashboard/applications/convert/#{@job_interest.id}"}
              class="btn btn-sm btn-primary"
            >
              <.icon name="hero-paper-airplane" class="w-4 h-4" /> Apply for Job
            </.link>
            <.link navigate={~p"/dashboard/job-interests/#{@job_interest}/edit"} class="btn btn-sm">
              <.icon name="hero-pencil" class="w-4 h-4" /> Edit
            </.link>
            <.button
              phx-click="delete"
              data-confirm="Are you sure you want to delete this job interest?"
              class="btn btn-sm btn-error"
            >
              <.icon name="hero-trash" class="w-4 h-4" /> Delete
            </.button>
          </div>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h1 class="text-3xl font-bold text-gray-900">{@job_interest.position_title}</h1>
            <h2 class="text-xl text-gray-600 mt-2">{@job_interest.company_name}</h2>
          </div>

          <div class="grid md:grid-cols-2 gap-6">
            <div>
              <h3 class="font-semibold text-gray-900 mb-2">Details</h3>
              <dl class="space-y-2">
                <%= if @job_interest.location do %>
                  <div>
                    <dt class="text-sm text-gray-500">Location</dt>
                    <dd class="text-sm text-gray-900">{@job_interest.location}</dd>
                  </div>
                <% end %>
                <%= if @job_interest.work_model do %>
                  <div>
                    <dt class="text-sm text-gray-500">Work Model</dt>
                    <dd class="text-sm text-gray-900">
                      {format_work_model(@job_interest.work_model)}
                    </dd>
                  </div>
                <% end %>
                <%= if @job_interest.salary_min || @job_interest.salary_max do %>
                  <div>
                    <dt class="text-sm text-gray-500">Salary Range</dt>
                    <dd class="text-sm text-gray-900">{format_salary_range(@job_interest)}</dd>
                  </div>
                <% end %>
                <%= if @job_interest.job_url do %>
                  <div>
                    <dt class="text-sm text-gray-500">Job Posting</dt>
                    <dd class="text-sm">
                      <a
                        href={@job_interest.job_url}
                        target="_blank"
                        class="text-blue-600 hover:underline"
                      >
                        View Posting
                        <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 inline" />
                      </a>
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>

            <div>
              <h3 class="font-semibold text-gray-900 mb-2">Status</h3>
              <dl class="space-y-2">
                <div>
                  <dt class="text-sm text-gray-500">Current Status</dt>
                  <dd class="text-sm">
                    <span class="badge">{format_status(@job_interest.status)}</span>
                  </dd>
                </div>
                <div>
                  <dt class="text-sm text-gray-500">Priority</dt>
                  <dd class="text-sm">
                    <span class="badge badge-outline">
                      {String.capitalize(@job_interest.priority)}
                    </span>
                  </dd>
                </div>
              </dl>
            </div>
          </div>

          <%= if @job_interest.job_description do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Job Description</h3>
              <p class="text-sm text-gray-700 whitespace-pre-wrap">{@job_interest.job_description}</p>
            </div>
          <% end %>

          <%= if @job_interest.notes do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Notes</h3>
              <p class="text-sm text-gray-700 whitespace-pre-wrap">{@job_interest.notes}</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp format_work_model("on_site"), do: "On-site"
  defp format_work_model(model), do: String.capitalize(model)

  defp format_salary_range(%{salary_min: nil, salary_max: nil}), do: "Not specified"
  defp format_salary_range(%{salary_min: min, salary_max: nil}), do: "$#{format_number(min)}+"

  defp format_salary_range(%{salary_min: nil, salary_max: max}),
    do: "Up to $#{format_number(max)}"

  defp format_salary_range(%{salary_min: min, salary_max: max}),
    do: "$#{format_number(min)} - $#{format_number(max)}"

  defp format_number(num) do
    num
    |> to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
