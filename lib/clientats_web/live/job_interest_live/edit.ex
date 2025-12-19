defmodule ClientatsWeb.JobInterestLive.Edit do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    job_interest = Jobs.get_job_interest!(id)
    changeset = Jobs.change_job_interest(job_interest)

    {:ok,
     socket
     |> assign(:page_title, "Edit Job Interest")
     |> assign(:job_interest, job_interest)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"job_interest" => job_interest_params}, socket) do
    changeset =
      socket.assigns.job_interest
      |> Jobs.change_job_interest(job_interest_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"job_interest" => job_interest_params}, socket) do
    case Jobs.update_job_interest(socket.assigns.job_interest, job_interest_params) do
      {:ok, job_interest} ->
        {:noreply,
         socket
         |> put_flash(:info, "Job interest updated successfully")
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
          <.link
            navigate={~p"/dashboard/job-interests/#{@job_interest}"}
            class="text-blue-600 hover:text-blue-800"
          >
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Job Interest
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-2xl">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Edit Job Interest</h2>
            <p class="text-sm text-gray-600 mt-1">Update your job interest details</p>
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

                <.input
                  field={@form[:job_description]}
                  type="textarea"
                  label="Job Description"
                  rows="4"
                />

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
              <.button phx-disable-with="Saving..." class="w-full">Update Job Interest</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
