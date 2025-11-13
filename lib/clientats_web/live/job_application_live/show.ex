defmodule ClientatsWeb.JobApplicationLive.Show do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    application = Jobs.get_job_application!(id)

    {:noreply,
     socket
     |> assign(:page_title, application.position_title)
     |> assign(:application, application)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Jobs.delete_job_application(socket.assigns.application)

    {:noreply,
     socket
     |> put_flash(:info, "Application deleted successfully")
     |> push_navigate(to: ~p"/dashboard")}
  end

  def handle_event("convert_to_interest", _params, socket) do
    application = socket.assigns.application

    interest_attrs = %{
      user_id: application.user_id,
      company_name: application.company_name,
      position_title: application.position_title,
      job_description: application.job_description,
      job_url: application.job_url,
      location: application.location,
      work_model: application.work_model,
      salary_min: application.salary_min,
      salary_max: application.salary_max,
      status: "interested",
      priority: "medium"
    }

    case Jobs.create_job_interest(interest_attrs) do
      {:ok, interest} ->
        Jobs.delete_job_application(application)

        {:noreply,
         socket
         |> put_flash(:info, "Application converted back to job interest")
         |> push_navigate(to: ~p"/dashboard/job-interests/#{interest}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to convert application to interest")}
    end
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
            <.button
              phx-click="convert_to_interest"
              data-confirm="Convert this application back to a job interest?"
              class="btn btn-sm btn-warning"
            >
              <.icon name="hero-arrow-uturn-left" class="w-4 h-4" /> Convert to Interest
            </.button>
            <.button
              phx-click="delete"
              data-confirm="Are you sure you want to delete this application?"
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
            <h1 class="text-3xl font-bold text-gray-900"><%= @application.position_title %></h1>
            <h2 class="text-xl text-gray-600 mt-2"><%= @application.company_name %></h2>
            <%= if @application.job_interest do %>
              <div class="mt-3">
                <.link
                  navigate={~p"/dashboard/job-interests/#{@application.job_interest}"}
                  class="text-sm text-blue-600 hover:underline"
                >
                  <.icon name="hero-arrow-right" class="w-4 h-4 inline" /> View related job interest
                </.link>
              </div>
            <% end %>
          </div>

          <div class="grid md:grid-cols-2 gap-6">
            <div>
              <h3 class="font-semibold text-gray-900 mb-2">Application Details</h3>
              <dl class="space-y-2">
                <div>
                  <dt class="text-sm text-gray-500">Application Date</dt>
                  <dd class="text-sm text-gray-900">
                    <%= Calendar.strftime(@application.application_date, "%B %d, %Y") %>
                  </dd>
                </div>
                <div>
                  <dt class="text-sm text-gray-500">Status</dt>
                  <dd class="text-sm">
                    <span class="badge"><%= format_status(@application.status) %></span>
                  </dd>
                </div>
                <%= if @application.location do %>
                  <div>
                    <dt class="text-sm text-gray-500">Location</dt>
                    <dd class="text-sm text-gray-900"><%= @application.location %></dd>
                  </div>
                <% end %>
                <%= if @application.work_model do %>
                  <div>
                    <dt class="text-sm text-gray-500">Work Model</dt>
                    <dd class="text-sm text-gray-900"><%= format_work_model(@application.work_model) %></dd>
                  </div>
                <% end %>
                <%= if @application.job_url do %>
                  <div>
                    <dt class="text-sm text-gray-500">Job Posting</dt>
                    <dd class="text-sm">
                      <a href={@application.job_url} target="_blank" class="text-blue-600 hover:underline">
                        View Posting <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 inline" />
                      </a>
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>

            <div>
              <h3 class="font-semibold text-gray-900 mb-2">Documents</h3>
              <dl class="space-y-2">
                <%= if @application.resume_path do %>
                  <div>
                    <dt class="text-sm text-gray-500">Resume</dt>
                    <dd class="text-sm">
                      <a href={@application.resume_path} target="_blank" class="text-blue-600 hover:underline">
                        View Resume <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 inline" />
                      </a>
                    </dd>
                  </div>
                <% else %>
                  <div>
                    <dt class="text-sm text-gray-500">Resume</dt>
                    <dd class="text-sm text-gray-400">Not specified</dd>
                  </div>
                <% end %>
                <%= if @application.cover_letter_path do %>
                  <div>
                    <dt class="text-sm text-gray-500">Cover Letter</dt>
                    <dd class="text-sm text-gray-900">Template #<%= @application.cover_letter_path %></dd>
                  </div>
                <% else %>
                  <div>
                    <dt class="text-sm text-gray-500">Cover Letter</dt>
                    <dd class="text-sm text-gray-400">Not specified</dd>
                  </div>
                <% end %>
              </dl>
            </div>
          </div>

          <%= if @application.salary_min || @application.salary_max do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Compensation</h3>
              <p class="text-sm text-gray-700"><%= format_salary_range(@application) %></p>
            </div>
          <% end %>

          <%= if @application.job_description do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Job Description</h3>
              <p class="text-sm text-gray-700 whitespace-pre-wrap"><%= @application.job_description %></p>
            </div>
          <% end %>

          <%= if @application.notes do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Notes</h3>
              <p class="text-sm text-gray-700 whitespace-pre-wrap"><%= @application.notes %></p>
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
  defp format_salary_range(%{salary_min: nil, salary_max: max}), do: "Up to $#{format_number(max)}"

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
