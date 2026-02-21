defmodule ClientatsWeb.DashboardLive do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.Feedback
  alias Clientats.LLMConfig
  alias Phoenix.LiveView.JS

  import ClientatsWeb.FeedbackComponents

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
        <!-- LLM Setup Banner -->
        <%= if !@has_configured_providers do %>
          <div class="alert alert-info mb-8">
            <div>
              <h3 class="font-semibold">Get started with AI features</h3>
              <p class="text-sm">
                Configure an LLM provider to unlock AI-powered features like job analysis and auto-fill.
              </p>
            </div>
            <div class="flex gap-2">
              <.link navigate={~p"/dashboard/llm-setup"} class="btn btn-sm btn-primary">
                Get Started →
              </.link>
            </div>
          </div>
        <% end %>

        <div class="mb-8 flex gap-4">
          <.link navigate={~p"/dashboard/resumes"} class="btn btn-outline">
            <.icon name="hero-document-text" class="w-5 h-5" /> Manage Resumes
          </.link>
          <.link navigate={~p"/dashboard/cover-letters"} class="btn btn-outline">
            <.icon name="hero-document-duplicate" class="w-5 h-5" /> Cover Letter Templates
          </.link>
          <.link navigate={~p"/dashboard/llm-config"} class="btn btn-outline">
            <.icon name="hero-cog-6-tooth" class="w-5 h-5" /> LLM Configuration
          </.link>
        </div>

        <div class="grid md:grid-cols-2 gap-8">
          <div class="bg-white rounded-lg shadow p-6">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-semibold text-gray-900">Job Interests</h2>
              <div class="flex items-center gap-3">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    class="toggle toggle-sm"
                    phx-click="toggle_not_interested"
                    checked={@show_not_interested}
                  />
                  <span class="text-xs text-gray-600">Show Not Interested</span>
                </label>
                <.link navigate={~p"/dashboard/job-interests/new"} class="btn btn-primary btn-sm">
                  <.icon name="hero-plus" class="w-5 h-5" /> Add Interest
                </.link>
              </div>
            </div>

            <%= if @job_interests == [] do %>
              <div class="text-center py-12 text-gray-500">
                No job interests yet. Start tracking opportunities!
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for interest <- @job_interests do %>
                  <div
                    class="border rounded-lg p-4 hover:bg-gray-50 cursor-pointer"
                    phx-click="select_interest"
                    phx-value-id={interest.id}
                  >
                    <div class="flex justify-between items-start">
                      <div class="flex-1">
                        <h3 class="font-semibold text-gray-900">{interest.position_title}</h3>
                        <p class="text-sm text-gray-600">{interest.company_name}</p>
                        <%= if interest.location do %>
                          <p class="text-sm text-gray-500">{interest.location}</p>
                        <% end %>
                      </div>
                      <div class="flex flex-col items-end gap-2">
                        <span class={"badge badge-sm " <> status_color(interest.status)}>
                          {format_status(interest.status)}
                        </span>
                        <span class={"badge badge-sm badge-outline " <> priority_color(interest.priority)}>
                          {String.capitalize(interest.priority)}
                        </span>
                      </div>
                    </div>
                    <div class="mt-2 pt-2 border-t border-gray-100" phx-click={%JS{}}>
                      <.feedback_buttons
                        job_interest_id={interest.id}
                        thumbs={feedback_thumbs(@feedback_states, interest.id)}
                        bookmarked={feedback_bookmarked(@feedback_states, interest.id)}
                      />
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
                        <h3 class="font-semibold text-gray-900">{application.position_title}</h3>
                        <p class="text-sm text-gray-600">{application.company_name}</p>
                        <p class="text-xs text-gray-500 mt-1">
                          Applied {Calendar.strftime(application.application_date, "%b %d, %Y")}
                        </p>
                      </div>
                      <span class={"badge badge-sm " <> app_status_color(application.status)}>
                        {format_status(application.status)}
                      </span>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <.why_modal show={@show_why_modal} />
      <.block_company_modal show={@show_block_modal} company_name={@block_company_name} />
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    all_interests = Jobs.list_job_interests(user_id)
    filtered_interests = filter_interests(all_interests, false)
    all_applications = Jobs.list_job_applications(user_id)
    filtered_applications = filter_applications(all_applications, false)

    # Check if user has configured any LLM providers
    has_configured_providers =
      LLMConfig.get_provider_status(user_id)
      |> Enum.any?(fn status -> status.status != "unconfigured" end)

    # Load feedback states for all job interests
    job_ids = Enum.map(all_interests, & &1.id)
    feedback_states = Feedback.get_feedback_states(user_id, job_ids)

    {:ok,
     socket
     |> assign(:show_not_interested, false)
     |> assign(:all_interests, all_interests)
     |> assign(:job_interests, filtered_interests)
     |> assign(:show_closed, false)
     |> assign(:all_applications, all_applications)
     |> assign(:job_applications, filtered_applications)
     |> assign(:has_configured_providers, has_configured_providers)
     |> assign(:feedback_states, feedback_states)
     |> assign(:show_why_modal, false)
     |> assign(:show_block_modal, false)
     |> assign(:block_company_name, "")
     |> assign(:last_rated_job_id, nil)
     |> stream(:job_interests, filtered_interests)
     |> stream(:job_applications, filtered_applications)}
  end

  def handle_event("select_interest", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard/job-interests/#{id}")}
  end

  def handle_event("toggle_not_interested", _params, socket) do
    show_not_interested = !socket.assigns.show_not_interested
    filtered_interests = filter_interests(socket.assigns.all_interests, show_not_interested)

    {:noreply,
     socket
     |> assign(:show_not_interested, show_not_interested)
     |> assign(:job_interests, filtered_interests)
     |> stream(:job_interests, filtered_interests, reset: true)}
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

  def handle_event("block_company", %{"job-id" => job_id_str}, socket) do
    job_id = String.to_integer(job_id_str)
    interest = Enum.find(socket.assigns.all_interests, &(&1.id == job_id))
    company_name = if interest, do: interest.company_name, else: ""

    {:noreply,
     socket
     |> assign(:show_block_modal, true)
     |> assign(:block_company_name, company_name)
     |> assign(:last_rated_job_id, job_id)}
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

    # Use custom reason if the chip reason is empty and custom text was provided
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

  # --- Feedback helpers ---

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

  defp filter_interests(interests, show_not_interested) do
    if show_not_interested do
      interests
    else
      Enum.reject(interests, &(&1.status == "not_a_fit"))
    end
  end
end
