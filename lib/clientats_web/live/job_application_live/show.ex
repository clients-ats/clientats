defmodule ClientatsWeb.JobApplicationLive.Show do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.LLM.Service
  alias Clientats.Documents

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form_open, false)
     |> assign(:editing_cover_letter, false)
     |> assign(:editing_event_id, nil)
     |> assign(:changeset, nil)}
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

  def handle_event("toggle_form", _params, socket) do
    form_open = !socket.assigns.form_open

    changeset =
      if form_open,
        do: Jobs.change_application_event(%Clientats.Jobs.ApplicationEvent{}),
        else: nil

    {:noreply,
     socket
     |> assign(:form_open, form_open)
     |> assign(:editing_event_id, nil)
     |> assign(:changeset, changeset)}
  end

  def handle_event("save_event", params, socket) do
    case socket.assigns.editing_event_id do
      nil ->
        # Creating new event
        event_params = Map.put(params, "job_application_id", socket.assigns.application.id)

        case Jobs.create_application_event(event_params) do
          {:ok, _event} ->
            application = Jobs.get_job_application!(socket.assigns.application.id)

            {:noreply,
             socket
             |> assign(:application, application)
             |> assign(:form_open, false)
             |> assign(:changeset, nil)
             |> put_flash(:info, "Activity added successfully")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:changeset, changeset)
             |> put_flash(:error, "Failed to save activity")}
        end

      event_id ->
        # Updating existing event
        event = Jobs.get_application_event!(event_id)

        case Jobs.update_application_event(event, params) do
          {:ok, _event} ->
            application = Jobs.get_job_application!(socket.assigns.application.id)

            {:noreply,
             socket
             |> assign(:application, application)
             |> assign(:form_open, false)
             |> assign(:editing_event_id, nil)
             |> assign(:changeset, nil)
             |> put_flash(:info, "Activity updated successfully")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:changeset, changeset)
             |> put_flash(:error, "Failed to save activity")}
        end
    end
  end

  def handle_event("edit_event", %{"id" => event_id}, socket) do
    event = Jobs.get_application_event!(event_id)
    changeset = Jobs.change_application_event(event)

    {:noreply,
     socket
     |> assign(:form_open, true)
     |> assign(:editing_event_id, event_id)
     |> assign(:changeset, changeset)}
  end

  def handle_event("delete_event", %{"id" => event_id}, socket) do
    event = Jobs.get_application_event!(event_id)
    {:ok, _} = Jobs.delete_application_event(event)
    application = Jobs.get_job_application!(socket.assigns.application.id)

    {:noreply,
     socket
     |> assign(:application, application)
     |> put_flash(:info, "Activity deleted successfully")}
  end

  def handle_event("edit_cover_letter", _params, socket) do
    {:noreply, assign(socket, :editing_cover_letter, true)}
  end

  @impl true
  def handle_info({ClientatsWeb.JobApplicationLive.CoverLetterEditor, {:saved, application}}, socket) do
    {:noreply,
     socket
     |> assign(:application, application)
     |> assign(:editing_cover_letter, false)
     |> put_flash(:info, "Cover letter updated successfully")}
  end

  def handle_info({ClientatsWeb.JobApplicationLive.CoverLetterEditor, :cancel_edit}, socket) do
    {:noreply, assign(socket, :editing_cover_letter, false)}
  end

  def handle_info({ClientatsWeb.JobApplicationLive.CoverLetterEditor, {:generate_cover_letter, job_desc, custom_prompt}}, socket) do
    user = socket.assigns.current_user

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

    # Set a timeout of 60 seconds for the generation
    Process.send_after(self(), {:generation_timeout, :generate_cover_letter}, 60_000)

    socket =
      socket
      |> assign(:generation_start_time, System.monotonic_time(:millisecond))
      |> start_async(:generate_cover_letter, fn ->
        Service.generate_cover_letter(job_desc, user_context, user_id: user.id, custom_prompt: custom_prompt)
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_async(:generate_cover_letter, {:ok, {:ok, content}}, socket) do
    send_update(ClientatsWeb.JobApplicationLive.CoverLetterEditor, id: "cover-letter-editor", generated_content: content)
    {:noreply, assign(socket, :generation_start_time, nil)}
  end

  def handle_async(:generate_cover_letter, {:ok, {:error, reason}}, socket) do
    error_msg = case reason do
      :unsupported_provider -> "Selected LLM provider is not supported. Please configure a supported provider in Settings."
      :invalid_content -> "Job description is invalid or too short for AI generation."
      msg -> "Generation failed: #{inspect(msg)}"
    end
    send_update(ClientatsWeb.JobApplicationLive.CoverLetterEditor, id: "cover-letter-editor", generation_error: error_msg)
    {:noreply, assign(socket, :generation_start_time, nil)}
  end

  def handle_async(:generate_cover_letter, {:exit, reason}, socket) do
    send_update(ClientatsWeb.JobApplicationLive.CoverLetterEditor, id: "cover-letter-editor", generation_error: "Generation crashed: #{inspect(reason)}")
    {:noreply, assign(socket, :generation_start_time, nil)}
  end

  def handle_info({:generation_timeout, :generate_cover_letter}, socket) do
    # Check if generation is still in progress
    if Map.has_key?(socket.assigns, :generation_start_time) do
      send_update(ClientatsWeb.JobApplicationLive.CoverLetterEditor, id: "cover-letter-editor", generation_error: "Generation timed out after 60 seconds. Please try again.")
      {:noreply, assign(socket, :generation_start_time, nil)}
    else
      # Generation already completed, ignore timeout
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Flash Messages -->
      <div id="flash" aria-live="polite">
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />
      </div>

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
            <h1 class="text-3xl font-bold text-gray-900">{@application.position_title}</h1>
            <h2 class="text-xl text-gray-600 mt-2">{@application.company_name}</h2>
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
                    {Calendar.strftime(@application.application_date, "%B %d, %Y")}
                  </dd>
                </div>
                <div>
                  <dt class="text-sm text-gray-500">Status</dt>
                  <dd class="text-sm">
                    <span class="badge">{format_status(@application.status)}</span>
                  </dd>
                </div>
                <%= if @application.location do %>
                  <div>
                    <dt class="text-sm text-gray-500">Location</dt>
                    <dd class="text-sm text-gray-900">{@application.location}</dd>
                  </div>
                <% end %>
                <%= if @application.work_model do %>
                  <div>
                    <dt class="text-sm text-gray-500">Work Model</dt>
                    <dd class="text-sm text-gray-900">
                      {format_work_model(@application.work_model)}
                    </dd>
                  </div>
                <% end %>
                <%= if @application.job_url do %>
                  <div>
                    <dt class="text-sm text-gray-500">Job Posting</dt>
                    <dd class="text-sm">
                      <a
                        href={@application.job_url}
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
              <h3 class="font-semibold text-gray-900 mb-2">Documents</h3>
              <dl class="space-y-2">
                <%= if @application.resume_path do %>
                  <div>
                    <dt class="text-sm text-gray-500">Resume</dt>
                    <dd class="text-sm">
                      <a
                        href={@application.resume_path}
                        target="_blank"
                        class="text-blue-600 hover:underline"
                      >
                        View Resume
                        <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4 inline" />
                      </a>
                    </dd>
                  </div>
                <% else %>
                  <div>
                    <dt class="text-sm text-gray-500">Resume</dt>
                    <dd class="text-sm text-gray-400">Not specified</dd>
                  </div>
                <% end %>
                <div>
                  <dt class="text-sm text-gray-500 flex justify-between items-center">
                    Cover Letter
                    <div class="flex gap-1">
                      <%= if @application.cover_letter_content do %>
                        <.link
                          href={~p"/dashboard/applications/#{@application.id}/download-cover-letter"}
                          class="btn btn-xs btn-primary"
                        >
                          <.icon name="hero-document-arrow-down" class="w-3 h-3 mr-1" /> PDF
                        </.link>
                      <% end %>
                      <button id="edit-cover-letter-btn" phx-click="edit_cover_letter" class="btn btn-xs btn-outline">
                        <.icon name="hero-pencil" class="w-3 h-3 mr-1" /> Edit
                      </button>
                    </div>
                  </dt>
                  <%= if @application.cover_letter_content do %>
                    <dd class="text-sm text-gray-900 mt-1 whitespace-pre-wrap line-clamp-3">{@application.cover_letter_content}</dd>
                  <% else %>
                    <%= if @application.cover_letter_path do %>
                      <dd class="text-sm text-gray-900 mt-1">Template: {@application.cover_letter_path}</dd>
                    <% else %>
                      <dd class="text-sm text-gray-400 mt-1">Not specified</dd>
                    <% end %>
                  <% end %>
                </div>
              </dl>
            </div>
          </div>

          <%= if @application.salary_min || @application.salary_max do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Compensation</h3>
              <p class="text-sm text-gray-700">{format_salary_range(@application)}</p>
            </div>
          <% end %>

          <%= if @application.job_description do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Job Description</h3>
              <p class="text-sm text-gray-700 whitespace-pre-wrap">{@application.job_description}</p>
            </div>
          <% end %>

          <%= if @application.notes do %>
            <div class="mt-6">
              <h3 class="font-semibold text-gray-900 mb-2">Notes</h3>
              <p class="text-sm text-gray-700 whitespace-pre-wrap">{@application.notes}</p>
            </div>
          <% end %>
        </div>
        
    <!-- Activity Timeline Section -->
        <div class="bg-white rounded-lg shadow p-6 mt-6">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Activity Timeline</h2>
            <%= if !@form_open do %>
              <.button phx-click="toggle_form" class="btn btn-primary btn-sm">
                Add Activity
              </.button>
            <% end %>
          </div>
          
    <!-- Activity Form -->
          <%= if @form_open do %>
            <div class="bg-gray-50 rounded-lg p-6 mb-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">
                {if @editing_event_id, do: "Update Activity", else: "Add Activity"}
              </h3>
              <form phx-submit="save_event">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Event Type</label>
                    <select
                      name="event_type"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    >
                      <option value="">Select event type...</option>
                      <option value="applied">Applied</option>
                      <option value="contact">Contact</option>
                      <option value="phone_screen">Phone Screen</option>
                      <option value="technical_screen">Technical Screen</option>
                      <option value="interview_onsite">Onsite Interview</option>
                      <option value="offer">Offer</option>
                      <option value="rejection">Rejection</option>
                      <option value="withdrawn">Withdrawn</option>
                      <option value="follow_up">Follow-up</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Event Date</label>
                    <input
                      type="date"
                      name="event_date"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Contact Person</label>
                    <input
                      type="text"
                      name="contact_person"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Contact Email</label>
                    <input
                      type="email"
                      name="contact_email"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    />
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Contact Phone</label>
                    <input
                      type="tel"
                      name="contact_phone"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Follow-up Date</label>
                    <input
                      type="date"
                      name="follow_up_date"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    />
                  </div>
                </div>

                <div class="mb-4">
                  <label class="block text-sm font-medium text-gray-700 mb-2">Notes</label>
                  <textarea
                    name="notes"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    rows="3"
                  ></textarea>
                </div>

                <div class="flex gap-2">
                  <button type="submit" class="btn btn-primary btn-sm">Save Activity</button>
                  <button type="button" phx-click="toggle_form" class="btn btn-secondary btn-sm">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          <% end %>
          
    <!-- Events List -->
          <%= if Enum.empty?(@application.events) do %>
            <div class="text-center py-12">
              <p class="text-gray-500 mb-2">No activities yet</p>
              <p class="text-gray-400 text-sm">Track emails, interviews, and other interactions</p>
            </div>
          <% else %>
            <div class="space-y-4">
              <%= for event <- Enum.sort_by(@application.events, & &1.event_date, :desc) do %>
                <div class="border border-gray-200 rounded-lg p-4">
                  <div class="flex justify-between items-start mb-2">
                    <div>
                      <h4 class="font-semibold text-gray-900">
                        {format_event_type(event.event_type)}
                      </h4>
                      <p class="text-sm text-gray-600">{format_date(event.event_date)}</p>
                      <%= if event.updated_at != event.inserted_at do %>
                        <p class="text-xs text-gray-400">
                          Last updated {format_date(event.updated_at)}
                        </p>
                      <% end %>
                    </div>
                    <div class="flex gap-2">
                      <button
                        phx-click="edit_event"
                        phx-value-id={event.id}
                        class="btn btn-xs btn-ghost"
                      >
                        <.icon name="hero-pencil" class="w-4 h-4" />
                      </button>
                      <button
                        phx-click="delete_event"
                        phx-value-id={event.id}
                        data-confirm="Delete this activity?"
                        class="btn btn-xs btn-ghost text-error"
                      >
                        <.icon name="hero-trash" class="w-4 h-4" />
                      </button>
                    </div>
                  </div>

                  <%= if event.contact_person do %>
                    <p class="text-sm text-gray-700">
                      <strong>Contact:</strong> {event.contact_person}
                    </p>
                  <% end %>
                  <%= if event.contact_email do %>
                    <p class="text-sm text-gray-700"><strong>Email:</strong> {event.contact_email}</p>
                  <% end %>
                  <%= if event.contact_phone do %>
                    <p class="text-sm text-gray-700"><strong>Phone:</strong> {event.contact_phone}</p>
                  <% end %>
                  <%= if event.notes do %>
                    <p class="text-sm text-gray-700 mt-2"><strong>Notes:</strong> {event.notes}</p>
                  <% end %>
                  <%= if event.follow_up_date do %>
                    <p class="text-sm text-gray-700 mt-2">
                      <span class="text-blue-600">
                        Follow-up: {format_date_short(event.follow_up_date)}
                      </span>
                    </p>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%= if @editing_cover_letter do %>
        <.live_component
          module={ClientatsWeb.JobApplicationLive.CoverLetterEditor}
          id="cover-letter-editor"
          job_application={@application}
          current_user={@current_user}
        />
      <% end %>
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

  defp format_event_type("applied"), do: "Applied"
  defp format_event_type("contact"), do: "Contact"
  defp format_event_type("phone_screen"), do: "Phone Screen"
  defp format_event_type("technical_screen"), do: "Technical Screen"
  defp format_event_type("interview_onsite"), do: "Onsite Interview"
  defp format_event_type("follow_up"), do: "Follow-up"
  defp format_event_type("offer"), do: "Offer"
  defp format_event_type("rejection"), do: "Rejection"
  defp format_event_type("withdrawn"), do: "Withdrawn"
  defp format_event_type(type), do: String.capitalize(String.replace(type, "_", " "))

  defp format_date(nil), do: ""

  defp format_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> format_date(parsed_date)
      {:error, _} -> date
    end
  end

  defp format_date(%Date{month: month, day: day, year: year}) do
    months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ]

    month_name = Enum.at(months, month - 1)
    "#{month_name} #{day}, #{year}"
  end

  defp format_date(%DateTime{} = datetime) do
    date = DateTime.to_date(datetime)
    format_date(date)
  end

  defp format_date(value) do
    # Fallback for any other type
    inspect(value)
  end

  defp format_date_short(nil), do: ""

  defp format_date_short(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> format_date_short(parsed_date)
      {:error, _} -> date
    end
  end

  defp format_date_short(%Date{month: month, day: day, year: year}) do
    months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ]

    month_name = Enum.at(months, month - 1)
    "#{month_name} #{String.pad_leading(to_string(day), 2, "0")}, #{year}"
  end

  defp format_date_short(%DateTime{} = datetime) do
    date = DateTime.to_date(datetime)
    format_date_short(date)
  end

  defp format_date_short(value) do
    # Fallback for any other type
    inspect(value)
  end
end
