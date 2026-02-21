defmodule ClientatsWeb.FeedbackHistoryLive do
  use ClientatsWeb, :live_view

  alias Clientats.Feedback
  alias Clientats.Feedback.RankingModel

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    feedback_count = Feedback.feedback_count(user_id)
    feedback_history = Feedback.list_feedback_history(user_id)
    blocked = Feedback.blocked_companies(user_id)
    {model_info, training_phase} = load_model_info(user_id, feedback_count)

    {:ok,
     socket
     |> assign(:page_title, "Feedback History")
     |> assign(:feedback_count, feedback_count)
     |> assign(:feedback_history, feedback_history)
     |> assign(:blocked_companies, blocked)
     |> assign(:training_phase, training_phase)
     |> assign(:model_info, model_info)
     |> assign(:filter, :all)
     |> assign(:training, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4 flex justify-between items-center">
          <div class="flex items-center gap-4">
            <.link navigate={~p"/dashboard"} class="text-gray-500 hover:text-gray-700">
              <.icon name="hero-arrow-left" class="w-5 h-5" />
            </.link>
            <h1 class="text-2xl font-bold text-gray-900">Feedback History</h1>
          </div>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-3xl space-y-6">
        <%!-- Training Status --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Training Status</h2>

          <%!-- Phase Progress Bar --%>
          <div class="mb-4">
            <div class="flex justify-between text-xs text-gray-500 mb-1">
              <span>LLM Proxy</span>
              <span>Simple Model (30)</span>
              <span>Full Model (100)</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-3">
              <div
                class={["h-3 rounded-full transition-all", phase_bar_color(@training_phase)]}
                style={"width: #{phase_progress(@feedback_count)}%"}
              >
              </div>
            </div>
            <p class="text-sm text-gray-600 mt-2">{phase_description(@training_phase, @feedback_count)}</p>
          </div>

          <%!-- Stats Grid --%>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
            <div class="text-center p-3 bg-gray-50 rounded-lg">
              <div class="text-2xl font-bold text-gray-900">{@feedback_count}</div>
              <div class="text-xs text-gray-500">Total Signals</div>
            </div>
            <div :if={@model_info} class="text-center p-3 bg-gray-50 rounded-lg">
              <div class="text-2xl font-bold text-gray-900">{@model_info.training_examples}</div>
              <div class="text-xs text-gray-500">Training Examples</div>
            </div>
            <div :if={@model_info && @model_info.metrics["accuracy"]} class="text-center p-3 bg-gray-50 rounded-lg">
              <div class="text-2xl font-bold text-green-600">
                {Float.round(@model_info.metrics["accuracy"] * 100, 1)}%
              </div>
              <div class="text-xs text-gray-500">Accuracy</div>
            </div>
            <div :if={@model_info && @model_info.metrics["auc"]} class="text-center p-3 bg-gray-50 rounded-lg">
              <div class="text-2xl font-bold text-blue-600">
                {Float.round(@model_info.metrics["auc"], 3)}
              </div>
              <div class="text-xs text-gray-500">AUC</div>
            </div>
          </div>

          <div class="flex items-center gap-4">
            <button
              phx-click="retrain_model"
              disabled={@feedback_count < 10 || @training}
              class="btn btn-sm btn-primary"
            >
              <%= if @training do %>
                <span class="loading loading-spinner loading-xs"></span> Training...
              <% else %>
                Retrain Model
              <% end %>
            </button>
            <span :if={@model_info} class="text-xs text-gray-500">
              Last trained: {Calendar.strftime(@model_info.updated_at, "%b %d, %Y %H:%M")}
            </span>
          </div>
        </div>

        <%!-- Feedback Timeline --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Feedback Timeline</h2>

          <%!-- Filter Tabs --%>
          <div class="flex gap-1 mb-4">
            <%= for {label, filter_val} <- [{"All", :all}, {"Positive", :positive}, {"Negative", :negative}, {"Implicit", :implicit}] do %>
              <button
                phx-click="set_filter"
                phx-value-filter={filter_val}
                class={[
                  "px-3 py-1.5 text-sm rounded-lg transition-colors",
                  @filter == filter_val && "bg-blue-600 text-white",
                  @filter != filter_val && "bg-gray-100 text-gray-700 hover:bg-gray-200"
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <%= if @feedback_history == [] do %>
            <div class="text-center py-8 text-gray-500">
              <.icon name="hero-chat-bubble-left-right" class="w-8 h-8 mx-auto mb-2 text-gray-300" />
              <p>No feedback recorded yet.</p>
              <p class="text-sm mt-1">Rate jobs on the dashboard or discover page to start building your model.</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for fb <- @feedback_history do %>
                <div class="flex items-start gap-3 p-3 rounded-lg hover:bg-gray-50">
                  <span class={["mt-0.5", feedback_icon_color(fb.feedback_type)]}>
                    {feedback_icon(fb.feedback_type)}
                  </span>
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2">
                      <span class="text-sm font-medium text-gray-900">
                        {feedback_type_label(fb.feedback_type)}
                      </span>
                      <span class="text-xs text-gray-400">
                        {format_timestamp(fb.inserted_at)}
                      </span>
                    </div>
                    <p :if={fb.job_interest} class="text-sm text-gray-600 truncate">
                      {fb.job_interest.position_title}
                      <span :if={fb.job_interest.company_name} class="text-gray-400">
                        at {fb.job_interest.company_name}
                      </span>
                    </p>
                    <p :if={fb.feedback_type == "dwell"} class="text-xs text-gray-500">
                      {format_dwell(fb.value)}
                    </p>
                    <p :if={fb.feedback_type == "why_prompt" && fb.metadata["reason"]} class="text-xs text-gray-500 italic">
                      "{fb.metadata["reason"]}"
                    </p>
                  </div>
                  <button
                    :if={fb.feedback_type in ["thumbs_up", "thumbs_down", "bookmark"]}
                    phx-click="undo_feedback"
                    phx-value-id={fb.id}
                    class="btn btn-xs btn-ghost text-gray-400 hover:text-red-500"
                    title="Undo"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%!-- Blocked Companies --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Blocked Companies</h2>
          <div class="space-y-2">
            <%= for block <- @blocked_companies do %>
              <div class="flex items-center justify-between bg-red-50 rounded-lg px-3 py-2">
                <div>
                  <span class="text-sm font-medium text-gray-900">{block.company_name}</span>
                  <span :if={block.reason} class="text-xs text-gray-500 ml-2">
                    ({block.reason})
                  </span>
                </div>
                <button
                  phx-click="unblock_company"
                  phx-value-name={block.company_name}
                  class="btn btn-xs btn-ghost text-red-600"
                >
                  Unblock
                </button>
              </div>
            <% end %>
            <p :if={@blocked_companies == []} class="text-sm text-gray-400">
              No companies blocked
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("set_filter", %{"filter" => filter}, socket) do
    user_id = socket.assigns.current_user.id
    filter = String.to_existing_atom(filter)

    type_opt = if filter == :all, do: [], else: [type: filter]
    feedback_history = Feedback.list_feedback_history(user_id, type_opt)

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:feedback_history, feedback_history)}
  end

  def handle_event("undo_feedback", %{"id" => id_str}, socket) do
    feedback_id = String.to_integer(id_str)

    case Feedback.delete_feedback(feedback_id) do
      {:ok, _} ->
        user_id = socket.assigns.current_user.id
        type_opt = if socket.assigns.filter == :all, do: [], else: [type: socket.assigns.filter]
        feedback_history = Feedback.list_feedback_history(user_id, type_opt)
        feedback_count = Feedback.feedback_count(user_id)

        {:noreply,
         socket
         |> assign(:feedback_history, feedback_history)
         |> assign(:feedback_count, feedback_count)
         |> put_flash(:info, "Feedback removed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove feedback")}
    end
  end

  def handle_event("unblock_company", %{"name" => name}, socket) do
    user_id = socket.assigns.current_user.id
    Feedback.unblock_company(user_id, name)
    blocked = Feedback.blocked_companies(user_id)

    {:noreply,
     socket
     |> assign(:blocked_companies, blocked)
     |> put_flash(:info, "Company unblocked")}
  end

  def handle_event("retrain_model", _params, socket) do
    user_id = socket.assigns.current_user.id
    pid = self()

    spawn(fn ->
      result = Feedback.train_model(user_id)
      send(pid, {:train_result, result})
    end)

    {:noreply, assign(socket, :training, true)}
  end

  @impl true
  def handle_info({:train_result, result}, socket) do
    user_id = socket.assigns.current_user.id
    feedback_count = Feedback.feedback_count(user_id)
    {model_info, training_phase} = load_model_info(user_id, feedback_count)

    socket =
      case result do
        {:ok, _} ->
          socket
          |> assign(:model_info, model_info)
          |> assign(:training_phase, training_phase)
          |> put_flash(:info, "Model retrained successfully")

        {:error, reason} ->
          put_flash(socket, :error, "Training failed: #{inspect(reason)}")
      end

    {:noreply, assign(socket, :training, false)}
  end

  # --- Private helpers ---

  defp load_model_info(user_id, feedback_count) do
    case Feedback.get_ranking_model(user_id) do
      {:ok, _booster, model} ->
        {model, model.phase}

      {:error, :no_model} ->
        {nil, RankingModel.phase_for_count(feedback_count)}
    end
  end

  defp phase_progress(count) do
    cond do
      count >= 100 -> 100
      count >= 30 -> 30 + (count - 30) / 70 * 70
      true -> count / 30 * 30
    end
    |> round()
    |> min(100)
  end

  defp phase_bar_color("llm_proxy"), do: "bg-yellow-400"
  defp phase_bar_color("simple_model"), do: "bg-blue-500"
  defp phase_bar_color("full_model"), do: "bg-green-500"
  defp phase_bar_color(_), do: "bg-gray-400"

  defp phase_description("llm_proxy", count) do
    remaining = max(0, 30 - count)
    "LLM Proxy: Using AI to score jobs directly. #{remaining} more ratings needed for Simple Model."
  end

  defp phase_description("simple_model", count) do
    remaining = max(0, 100 - count)
    "Simple Model: Learning from your ratings. #{remaining} more for Full Model."
  end

  defp phase_description("full_model", count) do
    "Full Model: Personalized ranking active with #{count} training signals."
  end

  defp phase_description(_, _), do: ""

  defp feedback_type_label("thumbs_up"), do: "Thumbs Up"
  defp feedback_type_label("thumbs_down"), do: "Thumbs Down"
  defp feedback_type_label("bookmark"), do: "Bookmarked"
  defp feedback_type_label("company_block"), do: "Blocked Company"
  defp feedback_type_label("click"), do: "Viewed"
  defp feedback_type_label("dwell"), do: "Read Time"
  defp feedback_type_label("why_prompt"), do: "Why Feedback"
  defp feedback_type_label(other), do: other

  defp feedback_icon("thumbs_up"), do: "👍"
  defp feedback_icon("thumbs_down"), do: "👎"
  defp feedback_icon("bookmark"), do: "🔖"
  defp feedback_icon("company_block"), do: "🚫"
  defp feedback_icon("click"), do: "👆"
  defp feedback_icon("dwell"), do: "⏱"
  defp feedback_icon("why_prompt"), do: "💬"
  defp feedback_icon(_), do: "•"

  defp feedback_icon_color("thumbs_up"), do: "text-green-500"
  defp feedback_icon_color("thumbs_down"), do: "text-red-500"
  defp feedback_icon_color("bookmark"), do: "text-yellow-500"
  defp feedback_icon_color("company_block"), do: "text-red-600"
  defp feedback_icon_color(_), do: "text-gray-400"

  defp format_dwell(nil), do: ""

  defp format_dwell(seconds) when is_float(seconds) or is_integer(seconds) do
    seconds = round(seconds)

    cond do
      seconds >= 120 -> "#{div(seconds, 60)} minutes"
      seconds >= 60 -> "1 minute"
      true -> "#{seconds} seconds"
    end
  end

  defp format_dwell(_), do: ""

  defp format_timestamp(nil), do: ""

  defp format_timestamp(dt) do
    Calendar.strftime(dt, "%b %d, %H:%M")
  end
end
