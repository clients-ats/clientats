defmodule ClientatsWeb.JobInterestLive.Show do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.Feedback

  import ClientatsWeb.FeedbackComponents

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    user_id = socket.assigns.current_user.id
    job_interest = Jobs.get_job_interest!(id)

    # Record click-through
    Feedback.record_click(user_id, job_interest.id)

    # Load feedback state
    feedback_states = Feedback.get_feedback_states(user_id, [job_interest.id])

    {:noreply,
     socket
     |> assign(:page_title, job_interest.position_title)
     |> assign(:job_interest, job_interest)
     |> assign(:feedback_states, feedback_states)
     |> assign(:show_why_modal, false)
     |> assign(:show_block_modal, false)
     |> assign(:block_company_name, "")
     |> assign(:last_rated_job_id, nil)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Jobs.delete_job_interest(socket.assigns.job_interest)

    {:noreply,
     socket
     |> put_flash(:info, "Job interest deleted successfully")
     |> push_navigate(to: ~p"/dashboard")}
  end

  # --- Dwell time tracking ---

  def handle_event("record_dwell", %{"job_id" => job_id_str, "seconds" => seconds}, socket) do
    user_id = socket.assigns.current_user.id
    job_id = String.to_integer(job_id_str)
    Feedback.record_dwell(user_id, job_id, seconds)
    {:noreply, socket}
  end

  # --- Feedback event handlers ---

  def handle_event("thumbs_up", %{"job-id" => job_id_str}, socket) do
    user_id = socket.assigns.current_user.id
    job_id = String.to_integer(job_id_str)
    {:ok, _} = Feedback.thumbs_up(user_id, job_id)

    socket =
      socket
      |> update_feedback_state(job_id, :thumbs, :up)
      |> assign(:last_rated_job_id, job_id)
      |> maybe_show_why_modal(user_id)

    {:noreply, socket}
  end

  def handle_event("thumbs_down", %{"job-id" => job_id_str}, socket) do
    user_id = socket.assigns.current_user.id
    job_id = String.to_integer(job_id_str)
    {:ok, _} = Feedback.thumbs_down(user_id, job_id)

    socket =
      socket
      |> update_feedback_state(job_id, :thumbs, :down)
      |> assign(:last_rated_job_id, job_id)
      |> maybe_show_why_modal(user_id)

    {:noreply, socket}
  end

  def handle_event("toggle_bookmark", %{"job-id" => job_id_str}, socket) do
    user_id = socket.assigns.current_user.id
    job_id = String.to_integer(job_id_str)
    currently_bookmarked = feedback_bookmarked(socket.assigns.feedback_states, job_id)

    if currently_bookmarked do
      Feedback.unbookmark(user_id, job_id)
      {:noreply, update_feedback_state(socket, job_id, :bookmarked, false)}
    else
      {:ok, _} = Feedback.bookmark(user_id, job_id)
      {:noreply, update_feedback_state(socket, job_id, :bookmarked, true)}
    end
  end

  def handle_event("block_company", %{"job-id" => _job_id_str}, socket) do
    company_name = socket.assigns.job_interest.company_name

    {:noreply,
     socket
     |> assign(:show_block_modal, true)
     |> assign(:block_company_name, company_name)
     |> assign(:last_rated_job_id, socket.assigns.job_interest.id)}
  end

  def handle_event("confirm_block_company", %{"reason" => reason}, socket) do
    user_id = socket.assigns.current_user.id
    company_name = socket.assigns.block_company_name
    reason = if reason == "", do: nil, else: reason

    {:ok, _} = Feedback.block_company(user_id, company_name, reason)

    {:noreply,
     socket
     |> assign(:show_block_modal, false)
     |> assign(:block_company_name, "")}
  end

  def handle_event("cancel_block", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_block_modal, false)
     |> assign(:block_company_name, "")}
  end

  def handle_event("submit_why", %{"reason" => reason} = params, socket) do
    user_id = socket.assigns.current_user.id
    job_id = socket.assigns.last_rated_job_id

    final_reason =
      case {reason, Map.get(params, "reason_custom", "")} do
        {"", custom} when custom != "" -> custom
        {chip, _} when chip != "" -> chip
        _ -> "unspecified"
      end

    if job_id, do: Feedback.record_why(user_id, job_id, final_reason)

    {:noreply, assign(socket, :show_why_modal, false)}
  end

  def handle_event("dismiss_why", _params, socket) do
    {:noreply, assign(socket, :show_why_modal, false)}
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

      <div
        id="job-detail"
        class="container mx-auto px-4 py-8"
        phx-hook="DwellTracker"
        data-job-id={@job_interest.id}
      >
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h1 class="text-3xl font-bold text-gray-900">{@job_interest.position_title}</h1>
            <h2 class="text-xl text-gray-600 mt-2">{@job_interest.company_name}</h2>
          </div>

          <%!-- Feedback Buttons --%>
          <div class="mb-6 pb-4 border-b border-gray-200">
            <.feedback_buttons
              job_interest_id={@job_interest.id}
              thumbs={feedback_thumbs(@feedback_states, @job_interest.id)}
              bookmarked={feedback_bookmarked(@feedback_states, @job_interest.id)}
            />
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

      <.why_modal show={@show_why_modal} />
      <.block_company_modal show={@show_block_modal} company_name={@block_company_name} />
    </div>
    """
  end

  # --- Private helpers ---

  defp update_feedback_state(socket, job_id, key, value) do
    states = socket.assigns.feedback_states
    current = Map.get(states, job_id, %{thumbs: nil, bookmarked: false})
    updated = Map.put(current, key, value)
    assign(socket, :feedback_states, Map.put(states, job_id, updated))
  end

  defp maybe_show_why_modal(socket, user_id) do
    if Feedback.should_prompt_why?(user_id) do
      assign(socket, :show_why_modal, true)
    else
      socket
    end
  end

  defp feedback_thumbs(states, job_id) do
    case Map.get(states, job_id) do
      %{thumbs: thumbs} -> thumbs
      _ -> nil
    end
  end

  defp feedback_bookmarked(states, job_id) do
    case Map.get(states, job_id) do
      %{bookmarked: bookmarked} -> bookmarked
      _ -> false
    end
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
