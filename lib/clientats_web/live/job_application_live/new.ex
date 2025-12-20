defmodule ClientatsWeb.JobApplicationLive.New do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.Documents
  alias Clientats.Jobs.JobApplication

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(params, _session, socket) do
    job_interest =
      case params["from_interest"] do
        nil -> nil
        id -> Jobs.get_job_interest!(id)
      end

    resumes = Documents.list_resumes(socket.assigns.current_user.id)
    cover_letters = Documents.list_cover_letter_templates(socket.assigns.current_user.id)

    attrs =
      if job_interest do
        %{
          "job_interest_id" => job_interest.id,
          "company_name" => job_interest.company_name,
          "position_title" => job_interest.position_title,
          "job_description" => job_interest.job_description,
          "job_url" => job_interest.job_url,
          "location" => job_interest.location,
          "work_model" => job_interest.work_model,
          "salary_min" => job_interest.salary_min,
          "salary_max" => job_interest.salary_max,
          "application_date" => Date.utc_today()
        }
      else
        %{"application_date" => Date.utc_today()}
      end

    changeset = Jobs.change_job_application(%JobApplication{}, attrs)

    {:ok,
     socket
     |> assign(:page_title, "New Job Application")
     |> assign(:job_interest, job_interest)
     |> assign(:resumes, resumes)
     |> assign(:cover_letters, cover_letters)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"job_application" => app_params}, socket) do
    changeset =
      %JobApplication{}
      |> Jobs.change_job_application(app_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"job_application" => app_params}, socket) do
    app_params = Map.put(app_params, "user_id", socket.assigns.current_user.id)

    case Jobs.create_job_application(app_params) do
      {:ok, application} ->
        if socket.assigns.job_interest do
          Jobs.delete_job_interest(socket.assigns.job_interest)
        end

        {:noreply,
         socket
         |> put_flash(:info, "Job application created successfully!")
         |> push_navigate(to: ~p"/dashboard/applications/#{application}")}

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
            <h2 class="text-2xl font-bold text-gray-900">New Job Application</h2>
            <p class="text-sm text-gray-600 mt-1">Record your job application details</p>
            <%= if @job_interest do %>
              <div class="mt-3 p-3 bg-blue-50 rounded-lg">
                <p class="text-sm text-blue-800">
                  <.icon name="hero-information-circle" class="w-5 h-5 inline" />
                  Converting job interest to application:
                  <strong>{@job_interest.position_title}</strong>
                  at <strong>{@job_interest.company_name}</strong>
                </p>
                <p class="text-xs text-blue-700 mt-1">
                  The original job interest will be removed when you save this application.
                </p>
              </div>
            <% end %>
          </div>

          <.form
            for={@form}
            id="application-form"
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
                <.input
                  field={@form[:application_date]}
                  type="date"
                  label="Application Date"
                  required
                />
              </div>
            </div>

            <div class="border-t pt-4">
              <p class="text-sm font-semibold text-gray-700 mb-3">Documents</p>
              <div class="space-y-4">
                <%= if @resumes == [] do %>
                  <div class="p-4 bg-yellow-50 rounded-lg">
                    <p class="text-sm text-yellow-800">
                      No resumes uploaded yet.
                      <.link navigate={~p"/dashboard/resumes/new"} class="underline font-medium">
                        Upload one now
                      </.link>
                    </p>
                  </div>
                <% else %>
                  <.input
                    field={@form[:resume_path]}
                    type="select"
                    label="Resume"
                    prompt="Select resume (optional)"
                    options={Enum.map(@resumes, &{resume_label(&1), &1.file_path})}
                  />
                <% end %>

                <%= if @cover_letters == [] do %>
                  <div class="p-4 bg-yellow-50 rounded-lg">
                    <p class="text-sm text-yellow-800">
                      No cover letter templates created.
                      <.link navigate={~p"/dashboard/cover-letters/new"} class="underline font-medium">
                        Create one now
                      </.link>
                    </p>
                  </div>
                <% else %>
                  <.input
                    field={@form[:cover_letter_path]}
                    type="select"
                    label="Cover Letter Template"
                    prompt="Select template (optional)"
                    options={Enum.map(@cover_letters, &{cover_letter_label(&1), to_string(&1.id)})}
                  />
                <% end %>
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

                <.input
                  field={@form[:status]}
                  type="select"
                  label="Status"
                  options={[
                    {"Applied", "applied"},
                    {"Phone Screen", "phone_screen"},
                    {"Interview Scheduled", "interview_scheduled"},
                    {"Interviewed", "interviewed"},
                    {"Offer Received", "offer_received"},
                    {"Offer Accepted", "offer_accepted"},
                    {"Rejected", "rejected"},
                    {"Withdrawn", "withdrawn"}
                  ]}
                />

                <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />
              </div>
            </div>

            <input
              type="hidden"
              name="job_application[job_interest_id]"
              value={@job_interest && @job_interest.id}
            />

            <div>
              <.button phx-disable-with="Saving..." class="w-full">Create Application</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp resume_label(resume) do
    if resume.is_default do
      "#{resume.name} (Default)"
    else
      resume.name
    end
  end

  defp cover_letter_label(template) do
    if template.is_default do
      "#{template.name} (Default)"
    else
      template.name
    end
  end
end
