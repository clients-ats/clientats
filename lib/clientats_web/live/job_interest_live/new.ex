defmodule ClientatsWeb.JobInterestLive.New do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.Jobs.JobInterest

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Jobs.change_job_interest(%JobInterest{})

    {:ok,
     socket
     |> assign(:page_title, "New Job Interest")
     |> assign(:job_interest, %JobInterest{})
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"job_interest" => job_interest_params}, socket) do
    changeset =
      %JobInterest{}
      |> Jobs.change_job_interest(job_interest_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"job_interest" => job_interest_params}, socket) do
    job_interest_params = Map.put(job_interest_params, "user_id", socket.assigns.current_user.id)

    case Jobs.create_job_interest(job_interest_params) do
      {:ok, job_interest} ->
        {:noreply,
         socket
         |> put_flash(:info, "Job interest created successfully")
         |> push_navigate(to: ~p"/dashboard/job-interests/#{job_interest}")}

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
          <.link navigate={~p"/dashboard"} class="text-blue-600 hover:text-blue-800">
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Dashboard
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-2xl">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-gray-900">New Job Interest</h2>
            <p class="text-sm text-gray-600 mt-1">Track jobs you're interested in applying to</p>
          </div>

          <.form
            for={@form}
            id="job-interest-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:job_url]}
              type="url"
              label="Job Posting URL"
              placeholder="https://example.com/careers/job-posting"
            />

            <div class="border-t pt-4">
              <p class="text-sm font-semibold text-gray-700 mb-3">Required Information</p>
              <div class="space-y-4">
                <.input field={@form[:company_name]} type="text" label="Company Name" required />
                <.input field={@form[:position_title]} type="text" label="Position Title" required />
              </div>
            </div>

            <div class="border-t pt-4">
              <p class="text-sm font-semibold text-gray-700 mb-3">Additional Details (Optional)</p>
              <div class="space-y-4">
                <div class="grid grid-cols-2 gap-4">
                  <.input
                    field={@form[:location]}
                    type="text"
                    label="Location"
                    placeholder="Remote, City, etc."
                  />
                  <.input
                    field={@form[:work_model]}
                    type="select"
                    label="Work Model"
                    prompt="Choose work model"
                    options={[{"Remote", "remote"}, {"Hybrid", "hybrid"}, {"On-site", "on_site"}]}
                  />
                </div>

                <.input field={@form[:job_description]} type="textarea" label="Job Description" rows="4" />

                <div class="grid grid-cols-2 gap-4">
                  <.input
                    field={@form[:salary_min]}
                    type="number"
                    label="Minimum Salary"
                    placeholder="50000"
                  />
                  <.input
                    field={@form[:salary_max]}
                    type="number"
                    label="Maximum Salary"
                    placeholder="80000"
                  />
                </div>

                <div class="grid grid-cols-2 gap-4">
                  <.input
                    field={@form[:status]}
                    type="select"
                    label="Status"
                    options={[
                      {"Interested", "interested"},
                      {"Researching", "researching"},
                      {"Not a Fit", "not_a_fit"},
                      {"Ready to Apply", "ready_to_apply"},
                      {"Applied", "applied"}
                    ]}
                  />
                  <.input
                    field={@form[:priority]}
                    type="select"
                    label="Priority"
                    options={[{"High", "high"}, {"Medium", "medium"}, {"Low", "low"}]}
                  />
                </div>

                <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
              </div>
            </div>

            <div>
              <.button phx-disable-with="Saving..." class="w-full">Save Job Interest</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
