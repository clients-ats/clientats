defmodule ClientatsWeb.JobApplicationLive.New do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.Documents
  alias Clientats.Jobs.JobApplication
  alias Clientats.LLM.Service
  alias Clientats.LLMConfig
  alias Clientats.Browser

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

    # Check if user has any enabled LLM providers
    llm_available =
      enabled_providers = LLMConfig.get_enabled_providers(socket.assigns.current_user.id)
      length(enabled_providers) > 0

    {:ok,
     socket
     |> assign(:page_title, "New Job Application")
     |> assign(:job_interest, job_interest)
     |> assign(:resumes, resumes)
     |> assign(:cover_letters, cover_letters)
     |> assign(:llm_available, llm_available)
     |> assign(:generate_cover_letter, false)
     |> assign(:generating, false)
     |> assign(:generated_content, nil)
     |> assign(:generation_error, nil)
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

  def handle_event("toggle_generate_cover_letter", _, socket) do
    {:noreply, assign(socket, :generate_cover_letter, !socket.assigns.generate_cover_letter)}
  end

  def handle_event("update_generated_content", %{"generated_cover_letter" => content}, socket) do
    {:noreply, assign(socket, :generated_content, content)}
  end

  def handle_event("generate_ai_cover_letter", _, socket) do
    # Get job description from form
    job_desc = Phoenix.HTML.Form.input_value(socket.assigns.form, :job_description)
    user = socket.assigns.current_user

    cond do
      is_nil(job_desc) || String.trim(job_desc) == "" ->
        {:noreply, assign(socket, :generation_error, "Job description is required for AI generation. Please add a job description above.")}

      is_nil(Documents.get_default_resume(user.id)) ->
        {:noreply, assign(socket, :generation_error, "No resume found. Upload one in Settings to enable AI generation.")}

      true ->
        # Try to get default resume and extract text
        resume_text =
          case Documents.get_default_resume(user.id) do
            nil -> nil
            resume ->
              case Documents.extract_resume_text(resume) do
                {:ok, text} -> text
                _ -> nil
              end
          end

        user_context = %{
          first_name: user.first_name,
          last_name: user.last_name,
          resume_text: resume_text
        }

        # Start async generation
        socket =
          socket
          |> assign(:generating, true)
          |> assign(:generation_error, nil)
          |> start_async(:generate_cover_letter, fn ->
            Service.generate_cover_letter(job_desc, user_context, user_id: user.id)
          end)

        {:noreply, socket}
    end
  end

  def handle_event("save", %{"job_application" => app_params}, socket) do
    app_params =
      app_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> maybe_add_generated_content(socket)

    case Jobs.create_job_application(app_params) do
      {:ok, application} ->
        # If converting from interest, generate and attach PDFs
        application =
          if socket.assigns.job_interest do
            application = generate_and_attach_pdfs(application, socket.assigns.current_user)
            Jobs.delete_job_interest(socket.assigns.job_interest)
            application
          else
            application
          end

        {:noreply,
         socket
         |> put_flash(:info, "Job application created successfully!")
         |> push_navigate(to: ~p"/dashboard/applications/#{application}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp maybe_add_generated_content(params, socket) do
    if socket.assigns.generate_cover_letter && socket.assigns.generated_content do
      Map.put(params, "cover_letter_content", socket.assigns.generated_content)
    else
      params
    end
  end

  defp generate_and_attach_pdfs(application, user) do
    require Logger

    # Generate cover letter PDF if there's content
    cover_letter_pdf_path =
      if application.cover_letter_content do
        generate_cover_letter_pdf(application, user)
      else
        nil
      end

    # Generate resume PDF if there's a resume
    resume_pdf_path =
      if application.resume_path do
        generate_resume_pdf(application.resume_path)
      else
        nil
      end

    # Update application with PDF paths
    attrs = %{}
    attrs = if cover_letter_pdf_path, do: Map.put(attrs, :cover_letter_pdf_path, cover_letter_pdf_path), else: attrs
    attrs = if resume_pdf_path, do: Map.put(attrs, :resume_pdf_path, resume_pdf_path), else: attrs

    case Jobs.update_job_application(application, attrs) do
      {:ok, updated_application} -> updated_application
      {:error, _changeset} ->
        Logger.error("Failed to update application with PDF paths")
        application
    end
  end

  defp generate_cover_letter_pdf(application, user) do
    # Create HTML for cover letter
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body {
          font-family: serif;
          line-height: 1.6;
          color: #333;
          max-width: 800px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          margin-bottom: 40px;
        }
        .date {
          margin-bottom: 20px;
        }
        .content {
          white-space: pre-wrap;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <strong>#{user.first_name} #{user.last_name}</strong><br>
        #{user.email}
      </div>

      <div class="date">
        #{Date.utc_today() |> Calendar.strftime("%B %d, %Y")}
      </div>

      <div class="content">
        #{application.cover_letter_content}
      </div>
    </body>
    </html>
    """

    case Browser.generate_pdf(html) do
      {:ok, temp_path} ->
        # Move to permanent location
        permanent_path = "/tmp/clientats_cover_letter_#{application.id}_#{System.unique_integer([:positive])}.pdf"
        File.cp!(temp_path, permanent_path)
        permanent_path

      {:error, reason} ->
        require Logger
        Logger.error("Failed to generate cover letter PDF: #{inspect(reason)}")
        nil
    end
  end

  defp generate_resume_pdf(resume_path) do
    # If resume is already a PDF, copy it
    if String.ends_with?(resume_path, ".pdf") do
      permanent_path = "/tmp/clientats_resume_#{System.unique_integer([:positive])}.pdf"
      File.cp!(resume_path, permanent_path)
      permanent_path
    else
      # For non-PDF resumes, we would need to implement conversion
      # For now, just return nil
      require Logger
      Logger.warning("Resume is not a PDF, skipping PDF generation: #{resume_path}")
      nil
    end
  end

  @impl true
  def handle_async(:generate_cover_letter, {:ok, {:ok, content}}, socket) do
    {:noreply,
     socket
     |> assign(:generating, false)
     |> assign(:generated_content, content)
     |> assign(:generation_error, nil)}
  end

  def handle_async(:generate_cover_letter, {:ok, {:error, reason}}, socket) do
    error_msg =
      case reason do
        :unsupported_provider -> "Selected LLM provider is not supported. Please configure a supported provider in Settings."
        :invalid_content -> "Job description is invalid or too short for AI generation."
        msg -> "Generation failed: #{inspect(msg)}"
      end

    {:noreply,
     socket
     |> assign(:generating, false)
     |> assign(:generation_error, error_msg)}
  end

  def handle_async(:generate_cover_letter, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:generating, false)
     |> assign(:generation_error, "Generation crashed: #{inspect(reason)}")}
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
                    disabled={@generate_cover_letter}
                  />
                <% end %>
              </div>
            </div>

            <%= if @llm_available do %>
              <div class="border-t pt-4">
                <div class="flex items-center justify-between mb-3">
                  <p class="text-sm font-semibold text-gray-700">AI-Generated Cover Letter</p>
                  <label class="flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      phx-click="toggle_generate_cover_letter"
                      checked={@generate_cover_letter}
                      class="checkbox checkbox-primary checkbox-sm"
                    />
                    <span class="ml-2 text-sm text-gray-600">Generate with AI</span>
                  </label>
                </div>

                <%= if @generate_cover_letter do %>
                  <div class="space-y-4 p-4 bg-blue-50 rounded-lg">
                    <p class="text-sm text-blue-800">
                      <.icon name="hero-information-circle" class="w-5 h-5 inline" />
                      Generate a personalized cover letter using the job description and your resume.
                    </p>

                    <%= if @generating do %>
                      <div class="alert alert-info">
                        <span class="loading loading-spinner loading-sm"></span>
                        <span>Generating your cover letter... This may take up to 60 seconds.</span>
                      </div>
                    <% end %>

                    <%= if @generation_error do %>
                      <div class="alert alert-error">
                        <.icon name="hero-exclamation-circle" class="w-5 h-5" />
                        <span>
                          {@generation_error}
                          <%= if String.contains?(@generation_error, "No resume found") do %>
                            <.link navigate={~p"/dashboard/resumes/new"} class="underline font-medium ml-1">
                              Upload one here
                            </.link>
                          <% end %>
                        </span>
                      </div>
                    <% end %>

                    <%= if @generated_content do %>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-2">
                          Generated Cover Letter (review and edit as needed)
                        </label>
                        <textarea
                          name="generated_cover_letter"
                          value={@generated_content}
                          phx-change="update_generated_content"
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg font-mono text-sm"
                          rows="12"
                        >{@generated_content}</textarea>
                      </div>
                    <% else %>
                      <button
                        type="button"
                        phx-click="generate_ai_cover_letter"
                        disabled={@generating}
                        class={"btn btn-sm #{if @generating, do: "btn-disabled loading", else: "btn-primary"}"}
                      >
                        <%= if @generating do %>
                          <span class="loading loading-spinner loading-xs mr-2"></span>
                          Generating...
                        <% else %>
                          <.icon name="hero-sparkles" class="w-4 h-4 mr-2" />
                          Generate Cover Letter
                        <% end %>
                      </button>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>

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
