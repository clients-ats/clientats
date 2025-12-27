defmodule ClientatsWeb.JobApplicationLive.ConversionWizard do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.Documents
  alias Clientats.LLM.Service
  alias Clientats.Browser

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(%{"interest_id" => interest_id}, _session, socket) do
    interest = Jobs.get_job_interest!(interest_id)
    user = socket.assigns.current_user

    # Load user's resumes for Step 2
    resumes = Documents.list_resumes(user.id)

    # Initialize form data from interest
    initial_attrs = %{
      "job_interest_id" => interest.id,
      "company_name" => interest.company_name,
      "position_title" => interest.position_title,
      "job_description" => interest.job_description,
      "job_url" => interest.job_url,
      "location" => interest.location,
      "work_model" => interest.work_model,
      "salary_min" => interest.salary_min,
      "salary_max" => interest.salary_max,
      "application_date" => Date.utc_today() |> Date.to_iso8601(),
      "status" => "applied"
    }

    {:ok,
     socket
     |> assign(:page_title, "Convert Interest to Application")
     |> assign(:current_step, 1)
     |> assign(:interest, interest)
     |> assign(:form_data, initial_attrs)
     |> assign(:resumes, resumes)
     |> assign(:selected_resume, nil)
     |> assign(:cover_letter_content, nil)
     |> assign(:generating_cover_letter, false)
     |> assign(:errors, %{})}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <!-- Progress Steps -->
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <%= for step <- 1..4 do %>
            <div class="flex items-center flex-1">
              <div class={[
                "flex items-center justify-center w-10 h-10 rounded-full border-2",
                if(@current_step > step, do: "bg-green-500 border-green-500 text-white", else: ""),
                if(@current_step == step, do: "bg-blue-500 border-blue-500 text-white", else: ""),
                if(@current_step < step, do: "bg-gray-200 border-gray-300 text-gray-500", else: "")
              ]}>
                <%= if @current_step > step do %>
                  <.icon name="hero-check" class="w-6 h-6" />
                <% else %>
                  <span class="font-semibold">{step}</span>
                <% end %>
              </div>
              <%= if step < 4 do %>
                <div class={[
                  "flex-1 h-1 mx-2",
                  if(@current_step > step, do: "bg-green-500", else: "bg-gray-300")
                ]}>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
        <div class="flex justify-between mt-2">
          <span class="text-xs text-gray-600">Job Details</span>
          <span class="text-xs text-gray-600">Resume</span>
          <span class="text-xs text-gray-600">Cover Letter</span>
          <span class="text-xs text-gray-600">Review</span>
        </div>
      </div>
      
    <!-- Step Content -->
      <div class="bg-white shadow-md rounded-lg p-6">
        <%= case @current_step do %>
          <% 1 -> %>
            {render_step_1(assigns)}
          <% 2 -> %>
            {render_step_2(assigns)}
          <% 3 -> %>
            {render_step_3(assigns)}
          <% 4 -> %>
            {render_step_4(assigns)}
        <% end %>
      </div>
      
    <!-- Navigation Buttons -->
      <div class="mt-6 flex justify-between">
        <button
          :if={@current_step > 1}
          phx-click="prev_step"
          class="px-6 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
        >
          ← Previous
        </button>
        <div :if={@current_step == 1}></div>

        <div class="flex gap-3">
          <.link
            navigate={~p"/dashboard/job-interests/#{@interest}"}
            class="px-6 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
          >
            Cancel
          </.link>

          <button
            :if={@current_step < 4}
            phx-click="next_step"
            class="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Next →
          </button>

          <button
            :if={@current_step == 4}
            phx-click="finalize"
            class="px-6 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
          >
            Create Application
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Step 1: Review/Edit Application Details
  defp render_step_1(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-4">Step 1: Review Application Details</h2>
      <p class="text-gray-600 mb-6">Review and edit the job details from your interest.</p>

      <.form for={%{}} phx-change="update_step_1" phx-submit="next_step">
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Company Name *</label>
            <input
              type="text"
              name="company_name"
              value={@form_data["company_name"]}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Position Title *</label>
            <input
              type="text"
              name="position_title"
              value={@form_data["position_title"]}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Job Description</label>
            <textarea
              name="job_description"
              rows="6"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            ><%= @form_data["job_description"] %></textarea>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Location</label>
              <input
                type="text"
                name="location"
                value={@form_data["location"]}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Work Model</label>
              <select
                name="work_model"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              >
                <option value="">Select...</option>
                <option value="remote" selected={@form_data["work_model"] == "remote"}>Remote</option>
                <option value="hybrid" selected={@form_data["work_model"] == "hybrid"}>Hybrid</option>
                <option value="on_site" selected={@form_data["work_model"] == "on_site"}>
                  On Site
                </option>
              </select>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Salary Min</label>
              <input
                type="number"
                name="salary_min"
                value={@form_data["salary_min"]}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Salary Max</label>
              <input
                type="number"
                name="salary_max"
                value={@form_data["salary_max"]}
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Job URL</label>
            <input
              type="url"
              name="job_url"
              value={@form_data["job_url"]}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Application Date</label>
            <input
              type="date"
              name="application_date"
              value={@form_data["application_date"]}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700">Notes</label>
            <textarea
              name="notes"
              rows="3"
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            ><%= @form_data["notes"] %></textarea>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  # Step 2: Select/Upload Resume
  defp render_step_2(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-4">Step 2: Select Resume</h2>
      <p class="text-gray-600 mb-6">Choose a resume to use for this application.</p>

      <div class="space-y-4">
        <%= if Enum.empty?(@resumes) do %>
          <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <p class="text-yellow-800">
              You don't have any resumes uploaded yet.
              <.link navigate={~p"/dashboard/resumes/new"} class="underline font-medium">
                Upload a resume
              </.link>
              first, or continue without selecting one.
            </p>
          </div>
        <% else %>
          <div class="space-y-2">
            <%= for resume <- @resumes do %>
              <div
                phx-click="select_resume"
                phx-value-id={resume.id}
                class={[
                  "border rounded-lg p-4 cursor-pointer transition relative group",
                  if(@selected_resume && @selected_resume.id == resume.id,
                    do: "border-blue-500 bg-blue-50",
                    else: "border-gray-300 hover:border-gray-400"
                  )
                ]}
              >
                <div class="flex items-center justify-between">
                  <div>
                    <div class="flex items-center gap-2">
                      <h3 class="font-medium text-gray-900">{resume.name}</h3>
                      <%= if !resume.is_valid do %>
                        <span class="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded">
                          Invalid File
                        </span>
                      <% end %>
                    </div>
                    <p class="text-sm text-gray-600">
                      {if resume.is_default, do: "Default Resume", else: ""}
                      <%= if resume.file_path do %>
                        · {Path.basename(resume.file_path)}
                      <% end %>
                    </p>
                  </div>
                  <div class="flex items-center gap-3">
                    <%= if resume.is_valid do %>
                      <a
                        href={~p"/dashboard/resumes/#{resume}/download"}
                        target="_blank"
                        class="p-2 text-gray-400 hover:text-blue-600 rounded-full hover:bg-white transition-colors z-10"
                        title="Download Resume"
                        onclick="event.stopPropagation()"
                      >
                        <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
                      </a>
                    <% end %>

                    <%= if @selected_resume && @selected_resume.id == resume.id do %>
                      <.icon name="hero-check-circle" class="w-6 h-6 text-blue-500" />
                    <% else %>
                      <div class="w-6 h-6 rounded-full border-2 border-gray-300 group-hover:border-gray-400">
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <%= if @selected_resume do %>
          <div class="mt-6 bg-gray-50 rounded-lg p-4">
            <h3 class="font-medium text-gray-900 mb-2">Selected Resume</h3>
            <div class="text-sm text-gray-700">
              <p class="font-medium">{@selected_resume.name}</p>
              <%= if @selected_resume.description do %>
                <p class="text-gray-600 mt-1">{@selected_resume.description}</p>
              <% end %>
              <p class="text-gray-600 mt-1">{@selected_resume.original_filename}</p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Step 3: Generate/Edit Cover Letter
  defp render_step_3(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-4">Step 3: Cover Letter</h2>
      <p class="text-gray-600 mb-6">Generate a custom cover letter using AI or write your own.</p>

      <div class="space-y-4">
        <div class="flex gap-3">
          <button
            phx-click="generate_cover_letter"
            disabled={@generating_cover_letter}
            class="px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 disabled:bg-gray-400"
          >
            <%= if @generating_cover_letter do %>
              <.icon name="hero-arrow-path" class="animate-spin w-4 h-4 inline mr-2" /> Generating...
            <% else %>
              <.icon name="hero-sparkles" class="w-4 h-4 inline mr-2" /> Generate with AI
            <% end %>
          </button>

          <button
            :if={@cover_letter_content}
            phx-click="clear_cover_letter"
            class="px-4 py-2 border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50"
          >
            Clear
          </button>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Cover Letter Content</label>
          <textarea
            phx-change="update_cover_letter"
            name="cover_letter_content"
            rows="16"
            class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 font-mono text-sm"
            placeholder="Click 'Generate with AI' or write your cover letter here..."
          ><%= @cover_letter_content %></textarea>
        </div>

        <%= if @cover_letter_content do %>
          <div class="text-sm text-gray-600">
            {String.length(@cover_letter_content)} characters
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Step 4: Review and Finalize
  defp render_step_4(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-4">Step 4: Review & Finalize</h2>
      <p class="text-gray-600 mb-6">Review all details before creating your application.</p>

      <div class="space-y-6">
        <!-- Job Details Summary -->
        <div class="bg-gray-50 rounded-lg p-4">
          <h3 class="font-semibold text-gray-900 mb-3">Job Details</h3>
          <dl class="grid grid-cols-2 gap-3 text-sm">
            <div>
              <dt class="font-medium text-gray-700">Company</dt>
              <dd class="text-gray-900">{@form_data["company_name"]}</dd>
            </div>
            <div>
              <dt class="font-medium text-gray-700">Position</dt>
              <dd class="text-gray-900">{@form_data["position_title"]}</dd>
            </div>
            <div>
              <dt class="font-medium text-gray-700">Location</dt>
              <dd class="text-gray-900">{@form_data["location"] || "N/A"}</dd>
            </div>
            <div>
              <dt class="font-medium text-gray-700">Work Model</dt>
              <dd class="text-gray-900">{format_work_model(@form_data["work_model"])}</dd>
            </div>
            <div>
              <dt class="font-medium text-gray-700">Application Date</dt>
              <dd class="text-gray-900">{@form_data["application_date"]}</dd>
            </div>
            <%= if @form_data["salary_min"] || @form_data["salary_max"] do %>
              <div>
                <dt class="font-medium text-gray-700">Salary Range</dt>
                <dd class="text-gray-900">
                  {format_salary_range(@form_data["salary_min"], @form_data["salary_max"])}
                </dd>
              </div>
            <% end %>
          </dl>
        </div>
        
    <!-- Resume Summary -->
        <div class="bg-gray-50 rounded-lg p-4">
          <h3 class="font-semibold text-gray-900 mb-3">Resume</h3>
          <%= if @selected_resume do %>
            <p class="text-sm text-gray-900">{@selected_resume.name}</p>
            <p class="text-xs text-gray-600">
              <%= if @selected_resume.file_path do %>
                {Path.basename(@selected_resume.file_path)}
              <% else %>
                Text-based resume
              <% end %>
            </p>
          <% else %>
            <p class="text-sm text-gray-600">No resume selected</p>
          <% end %>
        </div>
        
    <!-- Cover Letter Summary -->
        <div class="bg-gray-50 rounded-lg p-4">
          <h3 class="font-semibold text-gray-900 mb-3">Cover Letter</h3>
          <%= if @cover_letter_content do %>
            <div class="text-sm text-gray-700 whitespace-pre-wrap max-h-40 overflow-y-auto border border-gray-300 rounded p-2 bg-white">
              {@cover_letter_content}
            </div>
            <p class="text-xs text-gray-600 mt-2">
              {String.length(@cover_letter_content)} characters
            </p>
          <% else %>
            <p class="text-sm text-gray-600">No cover letter provided</p>
          <% end %>
        </div>

        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-information-circle" class="w-5 h-5 text-blue-500 mr-3 flex-shrink-0" />
            <div class="text-sm text-blue-800">
              <p class="font-medium mb-1">Ready to finalize?</p>
              <p>
                Clicking "Create Application" will:
              </p>
              <ul class="list-disc ml-5 mt-2 space-y-1">
                <li>Create your job application with all the details above</li>
                <li>Generate PDF snapshots of your resume and cover letter</li>
                <li>Remove this job from your interests list</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_work_model(nil), do: "N/A"
  defp format_work_model("remote"), do: "Remote"
  defp format_work_model("hybrid"), do: "Hybrid"
  defp format_work_model("on_site"), do: "On Site"
  defp format_work_model(other), do: other

  defp format_salary_range(nil, nil), do: "N/A"

  defp format_salary_range(min, nil) when is_integer(min),
    do: "$#{format_number(min)}+"

  defp format_salary_range(nil, max) when is_integer(max),
    do: "Up to $#{format_number(max)}"

  defp format_salary_range(min, max) when is_integer(min) and is_integer(max),
    do: "$#{format_number(min)} - $#{format_number(max)}"

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  # Event Handlers

  @impl true
  def handle_event("update_step_1", params, socket) do
    form_data = Map.merge(socket.assigns.form_data, params)
    {:noreply, assign(socket, :form_data, form_data)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step

    # Validate current step before proceeding
    case validate_step(current_step, socket.assigns) do
      :ok ->
        {:noreply, assign(socket, :current_step, current_step + 1)}

      {:error, errors} ->
        {:noreply, put_flash(socket, :error, errors)}
    end
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.current_step
    {:noreply, assign(socket, :current_step, max(1, current_step - 1))}
  end

  @impl true
  def handle_event("select_resume", %{"id" => resume_id}, socket) do
    resume = Enum.find(socket.assigns.resumes, &(&1.id == String.to_integer(resume_id)))
    {:noreply, assign(socket, :selected_resume, resume)}
  end

  @impl true
  def handle_event("generate_cover_letter", _params, socket) do
    user = socket.assigns.current_user
    job_description = socket.assigns.form_data["job_description"] || ""

    # Try to extract resume text if a resume is selected
    {resume_text, resume_data, extraction_error} =
      case socket.assigns.selected_resume do
        nil ->
          {"", nil, nil}

        resume ->
          case Documents.extract_resume_text(resume) do
            {:ok, text} -> {text, nil, nil}
            {:error, reason} -> {"", resume.data, reason}
          end
      end

    # Provide feedback if extraction failed
    socket =
      if extraction_error do
        msg =
          case extraction_error do
            :pdftotext_missing ->
              "Local PDF tools missing. Attempting direct file analysis with AI..."

            _ ->
              "Could not read resume text (#{inspect(extraction_error)}). Attempting direct file analysis with AI..."
          end

        put_flash(socket, :info, msg)
      else
        socket
      end

    socket = assign(socket, :generating_cover_letter, true)

    resume_mime =
      if socket.assigns.selected_resume do
        MIME.from_path(socket.assigns.selected_resume.original_filename)
      else
        nil
      end

    # Start async task to generate cover letter
    socket =
      start_async(socket, :generate_cover_letter, fn ->
        user_context = %{
          first_name: user.first_name || "",
          last_name: user.last_name || "",
          resume_text: resume_text,
          resume_data: resume_data,
          resume_mime: resume_mime
        }

        # Pass user_id to service to ensure it uses the user's configured provider
        Service.generate_cover_letter(job_description, user_context, user_id: user.id)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_cover_letter", %{"cover_letter_content" => content}, socket) do
    {:noreply, assign(socket, :cover_letter_content, content)}
  end

  @impl true
  def handle_event("clear_cover_letter", _params, socket) do
    {:noreply, assign(socket, :cover_letter_content, nil)}
  end

  @impl true
  def handle_event("finalize", _params, socket) do
    user = socket.assigns.current_user
    interest = socket.assigns.interest

    # Prepare final application attributes
    attrs =
      socket.assigns.form_data
      |> Map.put("user_id", user.id)
      |> Map.put("cover_letter_content", socket.assigns.cover_letter_content)
      |> Map.put("resume_path", get_resume_path(socket.assigns.selected_resume))

    case Jobs.create_job_application(attrs) do
      {:ok, application} ->
        # Generate and attach PDFs
        application = generate_and_attach_pdfs(application, socket.assigns)

        # Delete the original interest
        Jobs.delete_job_interest(interest)

        {:noreply,
         socket
         |> put_flash(:info, "Application created successfully!")
         |> push_navigate(to: ~p"/dashboard/applications/#{application}")}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)

        {:noreply,
         socket
         |> put_flash(:error, "Failed to create application: #{errors}")}
    end
  end

  @impl true
  def handle_async(:generate_cover_letter, {:ok, {:ok, content}}, socket) do
    {:noreply,
     socket
     |> assign(:cover_letter_content, content)
     |> assign(:generating_cover_letter, false)
     |> put_flash(:info, "Cover letter generated successfully!")}
  end

  @impl true
  def handle_async(:generate_cover_letter, {:ok, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:generating_cover_letter, false)
     |> put_flash(:error, "Failed to generate cover letter: #{inspect(reason)}")}
  end

  @impl true
  def handle_async(:generate_cover_letter, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:generating_cover_letter, false)
     |> put_flash(:error, "Cover letter generation timed out or failed: #{inspect(reason)}")}
  end

  # Private helper functions

  defp validate_step(1, assigns) do
    # Step 1: Validate required fields
    form_data = assigns.form_data

    errors =
      []
      |> validate_required(form_data, "company_name", "Company name")
      |> validate_required(form_data, "position_title", "Position title")

    if Enum.empty?(errors), do: :ok, else: {:error, Enum.join(errors, ", ")}
  end

  defp validate_step(2, _assigns) do
    # Step 2: Resume selection is optional
    :ok
  end

  defp validate_step(3, _assigns) do
    # Step 3: Cover letter is optional
    :ok
  end

  defp validate_step(4, _assigns) do
    # Step 4: Final review, no additional validation
    :ok
  end

  defp validate_required(errors, data, field, label) do
    if is_nil(data[field]) or String.trim(data[field] || "") == "" do
      ["#{label} is required" | errors]
    else
      errors
    end
  end

  defp get_resume_path(nil), do: nil
  defp get_resume_path(resume), do: resume.file_path

  defp generate_and_attach_pdfs(application, assigns) do
    user = assigns.current_user
    selected_resume = assigns.selected_resume
    cover_letter_content = assigns.cover_letter_content

    # Generate cover letter PDF
    application =
      if cover_letter_content do
        case generate_cover_letter_pdf(application, cover_letter_content, user) do
          {:ok, pdf_path} ->
            {:ok, updated} =
              Jobs.update_job_application(application, %{cover_letter_pdf_path: pdf_path})

            updated

          {:error, _reason} ->
            application
        end
      else
        application
      end

    # Generate resume PDF
    application =
      if selected_resume && selected_resume.file_path do
        case generate_resume_pdf(application, selected_resume.file_path) do
          {:ok, pdf_path} ->
            {:ok, updated} =
              Jobs.update_job_application(application, %{resume_pdf_path: pdf_path})

            updated

          {:error, _reason} ->
            application
        end
      else
        application
      end

    application
  end

  defp generate_cover_letter_pdf(application, content, user) do
    # Format HTML for PDF
    html = """
    <div style="font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px;">
      <div style="margin-bottom: 30px;">
        <div style="font-size: 14px;">
          #{user.first_name} #{user.last_name}<br>
          #{user.email}
        </div>
      </div>

      <div style="margin-bottom: 20px;">
        <div style="font-size: 14px;">
          #{Date.utc_today() |> Calendar.strftime("%B %d, %Y")}
        </div>
      </div>

      <div style="margin-bottom: 20px;">
        <div style="font-size: 14px;">
          #{application.company_name}<br>
          Re: #{application.position_title}
        </div>
      </div>

      <div style="font-size: 14px; line-height: 1.6; white-space: pre-wrap;">
    #{content}
      </div>
    </div>
    """

    case Browser.generate_pdf(html) do
      {:ok, temp_path} ->
        # Move to permanent location
        permanent_path =
          "/tmp/clientats_cover_letter_#{application.id}_#{System.unique_integer([:positive])}.pdf"

        File.cp!(temp_path, permanent_path)
        File.rm!(temp_path)
        {:ok, permanent_path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_resume_pdf(application, resume_path) do
    # If resume is already a PDF, copy it
    if String.ends_with?(resume_path, ".pdf") do
      if File.exists?(resume_path) do
        permanent_path =
          "/tmp/clientats_resume_#{application.id}_#{System.unique_integer([:positive])}.pdf"

        File.cp!(resume_path, permanent_path)
        {:ok, permanent_path}
      else
        {:error, :file_not_found}
      end
    else
      # For non-PDF resumes, we'd need conversion logic
      # For now, skip PDF generation
      {:error, :not_pdf}
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
