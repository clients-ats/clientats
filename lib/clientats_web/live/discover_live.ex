defmodule ClientatsWeb.DiscoverLive do
  use ClientatsWeb, :live_view

  alias Clientats.{Jobs, Feedback, Embedding, VectorStore, LinkedIn, JobExtractor, LLMConfig}
  alias Clientats.Ranker
  alias Clientats.Ranker.FeatureExtractor
  alias Clientats.Feedback.{UserPreference, RankingModel}

  import ClientatsWeb.FeedbackComponents

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    # Load user context
    feedback_count = Feedback.feedback_count(user_id)
    preferences = Feedback.get_all_preferences(user_id)
    user_prefs = UserPreference.to_feature_prefs(preferences)
    blocked = Feedback.blocked_companies(user_id) |> Enum.map(& &1.company_name)

    # Try to load trained model
    {booster, training_phase} =
      case Feedback.get_ranking_model(user_id) do
        {:ok, booster, %{phase: phase}} -> {booster, phase}
        {:error, :no_model} -> {nil, RankingModel.phase_for_count(feedback_count)}
      end

    # Check LLM availability
    has_llm =
      LLMConfig.get_provider_status(user_id)
      |> Enum.any?(fn status -> status.status != "unconfigured" end)

    {:ok,
     socket
     |> assign(:page_title, "Discover Jobs")
     |> assign(:search_mode, :saved)
     |> assign(:query, "")
     |> assign(:filter_remote, false)
     |> assign(:filter_location, "United States")
     |> assign(:filter_experience, "any")
     |> assign(:filter_time_posted, :month)
     |> assign(:searching, false)
     |> assign(:results, [])
     |> assign(:expanded_why, MapSet.new())
     |> assign(:expanded_detail, MapSet.new())
     |> assign(:phases, [])
     |> assign(:error, nil)
     |> assign(:feedback_states, %{})
     |> assign(:feedback_count, feedback_count)
     |> assign(:training_phase, training_phase)
     |> assign(:booster, booster)
     |> assign(:user_prefs, user_prefs)
     |> assign(:blocked_companies, blocked)
     |> assign(:has_llm, has_llm)
     |> assign(:show_why_modal, false)
     |> assign(:show_block_modal, false)
     |> assign(:block_company_name, "")
     |> assign(:last_rated_job_id, nil)
     |> assign(:show_why_for, nil)}
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
            <h1 class="text-2xl font-bold text-gray-900">Discover Jobs</h1>
          </div>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <%!-- Search Bar --%>
        <div class="bg-white rounded-lg shadow p-6 mb-6">
          <%!-- Mode Toggle --%>
          <div class="flex gap-2 mb-4">
            <button
              phx-click="set_mode"
              phx-value-mode="saved"
              class={[
                "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                @search_mode == :saved && "bg-blue-600 text-white",
                @search_mode != :saved && "bg-gray-100 text-gray-700 hover:bg-gray-200"
              ]}
            >
              Search Saved Jobs
            </button>
            <button
              phx-click="set_mode"
              phx-value-mode="linkedin"
              class={[
                "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
                @search_mode == :linkedin && "bg-blue-600 text-white",
                @search_mode != :linkedin && "bg-gray-100 text-gray-700 hover:bg-gray-200",
                !@has_llm && "opacity-50 cursor-not-allowed"
              ]}
              disabled={!@has_llm}
            >
              LinkedIn Search
            </button>
          </div>

          <%!-- Search Input --%>
          <form phx-submit="search" class="flex gap-2">
            <input
              type="text"
              name="query"
              value={@query}
              phx-change="update_query"
              placeholder="e.g. Senior Elixir Developer, Java Backend, ML Engineer..."
              class="flex-1 input input-bordered"
              disabled={@searching}
            />
            <button
              type="submit"
              class="btn btn-primary"
              disabled={@searching || @query == ""}
            >
              <%= if @searching, do: "Searching...", else: "Search" %>
            </button>
          </form>

          <%!-- Filters (LinkedIn mode) --%>
          <div :if={@search_mode == :linkedin} class="flex flex-wrap items-end gap-4 mt-3">
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                class="checkbox checkbox-sm"
                phx-click="toggle_remote"
                checked={@filter_remote}
              />
              <span class="text-sm">Remote only</span>
            </label>

            <div :if={!@filter_remote}>
              <label class="text-xs text-gray-500">Location</label>
              <input
                type="text"
                value={@filter_location}
                phx-change="set_location"
                phx-debounce="300"
                name="location"
                placeholder="e.g. New York, San Francisco..."
                class="input input-sm input-bordered w-48"
              />
            </div>

            <select
              class="select select-sm select-bordered"
              phx-change="set_experience"
              name="level"
            >
              <option value="any" selected={@filter_experience == "any"}>Any Experience</option>
              <option value="entry_level" selected={@filter_experience == "entry_level"}>
                Entry Level
              </option>
              <option value="mid_senior" selected={@filter_experience == "mid_senior"}>
                Mid-Senior
              </option>
              <option value="director" selected={@filter_experience == "director"}>Director</option>
              <option value="executive" selected={@filter_experience == "executive"}>
                Executive
              </option>
            </select>

            <select
              class="select select-sm select-bordered"
              phx-change="set_time_posted"
              name="time"
            >
              <option value="day" selected={@filter_time_posted == :day}>Past 24 hours</option>
              <option value="week" selected={@filter_time_posted == :week}>Past week</option>
              <option value="month" selected={@filter_time_posted == :month}>Past month</option>
            </select>
          </div>

          <p :if={@search_mode == :linkedin && !@has_llm} class="text-sm text-amber-600 mt-2">
            LinkedIn search requires an LLM provider.
            <.link navigate={~p"/dashboard/llm-setup"} class="underline">Configure one</.link>.
          </p>

          <p :if={@search_mode == :linkedin && @has_llm} class="text-xs text-gray-500 mt-2">
            Requires Chrome running with --remote-debugging-port=9222
          </p>
        </div>

        <%!-- Status Bar --%>
        <div class="flex items-center justify-between bg-blue-50 rounded-lg p-3 mb-4">
          <div class="flex items-center gap-4 text-sm">
            <span class="font-medium">Model:</span>
            <span class={[
              "badge badge-sm",
              phase_badge(@training_phase)
            ]}>
              {format_training_phase(@training_phase)}
            </span>
            <span class="text-gray-400">|</span>
            <span class="text-gray-600">{@feedback_count} feedback signals</span>
          </div>
          <div :if={@training_phase == "llm_proxy"} class="text-xs text-gray-500">
            Rate more jobs to build your model (need 30)
          </div>
        </div>

        <%!-- Phase Progress --%>
        <div :if={@searching && @phases != []} class="bg-white rounded-lg shadow p-4 mb-4">
          <div class="space-y-2">
            <%= for phase <- @phases do %>
              <div class="flex items-center gap-3">
                <span :if={phase.status == :pending} class="text-gray-300">
                  <.icon name="hero-ellipsis-horizontal-circle" class="w-5 h-5" />
                </span>
                <span
                  :if={phase.status == :in_progress}
                  class="text-blue-500 animate-spin"
                >
                  <.icon name="hero-arrow-path" class="w-5 h-5" />
                </span>
                <span :if={phase.status == :complete} class="text-green-500">
                  <.icon name="hero-check-circle" class="w-5 h-5" />
                </span>
                <span :if={phase.status == :error} class="text-red-500">
                  <.icon name="hero-x-circle" class="w-5 h-5" />
                </span>
                <span class={[
                  "text-sm",
                  phase.status == :pending && "text-gray-400",
                  phase.status == :in_progress && "text-blue-700 font-medium",
                  phase.status == :complete && "text-green-700",
                  phase.status == :error && "text-red-700"
                ]}>
                  {phase.label}
                </span>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Error --%>
        <div :if={@error} class="alert alert-error mb-4">
          <.icon name="hero-exclamation-circle" class="w-5 h-5" />
          <span>{@error}</span>
        </div>

        <%!-- Results --%>
        <div :if={@results != []} class="space-y-4">
          <p class="text-sm text-gray-500 mb-2">{length(@results)} results</p>
          <%= for {result, idx} <- Enum.with_index(@results) do %>
            <div class="bg-white rounded-lg shadow p-4 hover:shadow-md transition">
              <%!-- Clickable header --%>
              <div
                class="flex justify-between items-start cursor-pointer"
                phx-click={if result.source == :saved, do: "view_job", else: "toggle_detail"}
                phx-value-id={result[:saved_interest_id] || result[:id]}
                phx-value-idx={idx}
              >
                <div class="flex-1">
                  <h3 class="font-semibold text-gray-900 hover:text-blue-600">{result.title}</h3>
                  <p class="text-sm text-gray-600">{result.company}</p>
                  <p :if={result.location} class="text-sm text-gray-500">{result.location}</p>
                  <div class="flex items-center gap-2 mt-1">
                    <span :if={result[:work_model]} class="badge badge-xs badge-outline">
                      {result.work_model}
                    </span>
                    <span :if={result[:salary_range]} class="text-xs text-gray-500">
                      {result.salary_range}
                    </span>
                  </div>
                </div>
                <div class="flex flex-col items-end gap-2">
                  <span class={["badge", score_badge(result.score)]}>
                    {format_score(result.score)}
                  </span>
                  <span class="text-xs text-gray-400">
                    <%= if result.source == :saved, do: "Click to view", else: if(MapSet.member?(@expanded_detail, idx), do: "Hide details", else: "Show details") %>
                  </span>
                </div>
              </div>

              <%!-- Inline detail panel (LinkedIn results) --%>
              <div
                :if={result.source == :linkedin && MapSet.member?(@expanded_detail, idx)}
                class="mt-3 p-4 bg-gray-50 rounded-lg border border-gray-200"
              >
                <div :if={result[:extracted]} class="space-y-3">
                  <%!-- Skills --%>
                  <div :if={skills_list(result.extracted) != []}>
                    <h4 class="text-xs font-semibold text-gray-700 mb-1">Skills</h4>
                    <div class="flex flex-wrap gap-1">
                      <%= for skill <- skills_list(result.extracted) do %>
                        <span class="badge badge-xs badge-outline">{skill}</span>
                      <% end %>
                    </div>
                  </div>
                  <%!-- Details grid --%>
                  <div class="grid grid-cols-2 gap-2 text-xs">
                    <div :if={result.extracted[:seniority_level]}>
                      <span class="text-gray-500">Seniority:</span>
                      <span class="ml-1 font-medium">{result.extracted[:seniority_level]}</span>
                    </div>
                    <div :if={result.extracted[:employment_type]}>
                      <span class="text-gray-500">Type:</span>
                      <span class="ml-1 font-medium">{result.extracted[:employment_type]}</span>
                    </div>
                    <div :if={result.extracted[:education_requirement]}>
                      <span class="text-gray-500">Education:</span>
                      <span class="ml-1 font-medium">{result.extracted[:education_requirement]}</span>
                    </div>
                    <div :if={result.extracted[:industry]}>
                      <span class="text-gray-500">Industry:</span>
                      <span class="ml-1 font-medium">{result.extracted[:industry]}</span>
                    </div>
                  </div>
                  <%!-- Description excerpt --%>
                  <div :if={result.extracted[:description]}>
                    <h4 class="text-xs font-semibold text-gray-700 mb-1">Description</h4>
                    <p class="text-xs text-gray-600 whitespace-pre-wrap line-clamp-6">
                      {result.extracted[:description]}
                    </p>
                  </div>
                  <%!-- External link --%>
                  <a
                    :if={result[:url]}
                    href={result.url}
                    target="_blank"
                    class="text-xs text-blue-600 hover:underline inline-flex items-center gap-1"
                  >
                    View on LinkedIn <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
                  </a>
                </div>
              </div>

              <%!-- Actions bar --%>
              <div class="mt-2 pt-2 border-t border-gray-100 flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <%!-- Feedback buttons --%>
                  <div :if={result.saved_interest_id}>
                    <.feedback_buttons
                      job_interest_id={result.saved_interest_id}
                      thumbs={feedback_thumbs(@feedback_states, result.saved_interest_id)}
                      bookmarked={feedback_bookmarked(@feedback_states, result.saved_interest_id)}
                    />
                  </div>
                  <%!-- Rate buttons for unsaved LinkedIn results (auto-saves on click) --%>
                  <div :if={result.source == :linkedin && !result.saved_interest_id} class="flex items-center gap-1">
                    <button
                      phx-click="rate_and_save"
                      phx-value-idx={idx}
                      phx-value-rating="up"
                      class="btn btn-xs btn-ghost"
                      title="Like (auto-saves)"
                    >
                      <.icon name="hero-hand-thumb-up" class="w-4 h-4" />
                    </button>
                    <button
                      phx-click="rate_and_save"
                      phx-value-idx={idx}
                      phx-value-rating="down"
                      class="btn btn-xs btn-ghost"
                      title="Dislike (auto-saves)"
                    >
                      <.icon name="hero-hand-thumb-down" class="w-4 h-4" />
                    </button>
                    <button
                      phx-click="save_as_interest"
                      phx-value-idx={idx}
                      class="btn btn-xs btn-outline btn-primary ml-1"
                    >
                      Save
                    </button>
                  </div>
                  <span
                    :if={result.source == :linkedin && result.saved_interest_id}
                    class="text-xs text-green-600 flex items-center gap-1"
                  >
                    <.icon name="hero-check" class="w-3 h-3" /> Saved
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <button
                    :if={result[:features]}
                    phx-click="toggle_why_match"
                    phx-value-idx={idx}
                    class="text-xs text-blue-600 hover:underline"
                  >
                    <%= if MapSet.member?(@expanded_why, idx), do: "Hide match", else: "Why this match?" %>
                  </button>
                </div>
              </div>

              <%!-- Inline reason chips (shown after rating) --%>
              <div
                :if={@show_why_for == result[:saved_interest_id] && @show_why_for != nil}
                class="mt-2 p-3 bg-blue-50 rounded-lg"
              >
                <p class="text-xs text-gray-600 mb-2">What drove your rating?</p>
                <div class="flex flex-wrap gap-1.5">
                  <%= for reason <- ~w(salary skills company location seniority) do %>
                    <button
                      phx-click="quick_why"
                      phx-value-reason={reason}
                      class="px-2.5 py-1 text-xs rounded-full border border-blue-300 hover:bg-blue-100 transition-colors"
                    >
                      {String.capitalize(reason)}
                    </button>
                  <% end %>
                  <button
                    phx-click="dismiss_inline_why"
                    class="px-2.5 py-1 text-xs rounded-full text-gray-400 hover:text-gray-600"
                  >
                    Skip
                  </button>
                </div>
              </div>

              <%!-- Why this match breakdown --%>
              <div
                :if={result[:features] && MapSet.member?(@expanded_why, idx)}
                class="mt-3 p-3 bg-gray-50 rounded-lg"
              >
                <h4 class="text-xs font-semibold mb-2 text-gray-700">Match Breakdown</h4>
                <div class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
                  <%= for {name, value} <- Enum.zip(FeatureExtractor.feature_names(), result.features) do %>
                    <div class="flex justify-between">
                      <span class="text-gray-600">{format_feature_name(name)}</span>
                      <span class={["font-mono", feature_color(value)]}>
                        {Float.round(value * 1.0, 2)}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Empty state --%>
        <div
          :if={!@searching && @results == [] && @query != "" && @error == nil}
          class="text-center py-12 text-gray-500"
        >
          No results found. Try different keywords.
        </div>

        <%!-- Initial state --%>
        <div :if={@results == [] && @query == "" && !@searching} class="text-center py-12">
          <.icon name="hero-magnifying-glass" class="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p class="text-gray-500">Enter keywords to discover jobs matching your preferences.</p>
        </div>
      </div>

      <.why_modal show={@show_why_modal} />
      <.block_company_modal show={@show_block_modal} company_name={@block_company_name} />
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("update_query", %{"query" => query}, socket) do
    {:noreply, assign(socket, :query, query)}
  end

  def handle_event("update_query", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_mode", %{"mode" => mode}, socket) do
    mode = String.to_existing_atom(mode)
    {:noreply, assign(socket, search_mode: mode, results: [], error: nil, phases: [])}
  end

  def handle_event("toggle_remote", _params, socket) do
    {:noreply, assign(socket, :filter_remote, !socket.assigns.filter_remote)}
  end

  def handle_event("set_experience", %{"level" => level}, socket) do
    {:noreply, assign(socket, :filter_experience, level)}
  end

  def handle_event("set_location", %{"location" => location}, socket) do
    {:noreply, assign(socket, :filter_location, location)}
  end

  def handle_event("set_time_posted", %{"time" => time}, socket) do
    {:noreply, assign(socket, :filter_time_posted, String.to_existing_atom(time))}
  end

  def handle_event("view_job", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/dashboard/job-interests/#{id}")}
  end

  def handle_event("toggle_detail", %{"idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)

    expanded =
      if MapSet.member?(socket.assigns.expanded_detail, idx) do
        MapSet.delete(socket.assigns.expanded_detail, idx)
      else
        MapSet.put(socket.assigns.expanded_detail, idx)
      end

    {:noreply, assign(socket, :expanded_detail, expanded)}
  end

  # --- Search: Saved Jobs Mode ---

  def handle_event("search", _params, %{assigns: %{search_mode: :saved}} = socket) do
    query = String.trim(socket.assigns.query)

    if query == "" do
      {:noreply, assign(socket, :error, "Please enter search keywords")}
    else
      pid = self()
      user_id = socket.assigns.current_user.id

      phases = [
        %{id: :embedding, label: "Embedding query", status: :in_progress},
        %{id: :searching, label: "Searching vector store", status: :pending},
        %{id: :ranking, label: "Ranking results", status: :pending}
      ]

      spawn(fn ->
        with {:ok, vecs} <- Embedding.embed_batch([query, query], user_id: user_id) do
          [title_vec, desc_vec] = vecs
          send(pid, {:saved_phase, :searching})

          results = VectorStore.search_multi_vector(title_vec, desc_vec, 30)
          job_ids = Enum.map(results, fn {id, _, _, _} -> id end)
          jobs = Jobs.get_job_interests_by_ids(job_ids)

          send(pid, {:saved_results, results, jobs})
        else
          {:error, reason} ->
            send(pid, {:search_error, "Embedding failed: #{inspect(reason)}"})
        end
      end)

      {:noreply,
       assign(socket,
         searching: true,
         results: [],
         phases: phases,
         error: nil,
         expanded_why: MapSet.new()
       )}
    end
  end

  # --- Search: LinkedIn Mode ---

  def handle_event("search", _params, %{assigns: %{search_mode: :linkedin}} = socket) do
    query = String.trim(socket.assigns.query)

    if query == "" do
      {:noreply, assign(socket, :error, "Please enter search keywords")}
    else
      pid = self()
      user_id = socket.assigns.current_user.id
      filter_experience = socket.assigns.filter_experience

      opts =
        [
          max_jobs: 25,
          time_posted: socket.assigns.filter_time_posted,
          location: socket.assigns.filter_location
        ]
        |> maybe_add_remote(socket.assigns.filter_remote)
        |> maybe_add_experience(filter_experience)

      phases = [
        %{id: :searching, label: "Searching LinkedIn", status: :in_progress},
        %{id: :details, label: "Loading job details", status: :pending},
        %{id: :extracting, label: "Extracting structured data", status: :pending},
        %{id: :ranking, label: "Ranking results", status: :pending}
      ]

      spawn(fn ->
        case LinkedIn.search_jobs(query, opts) do
          {:ok, jobs} ->
            send(pid, {:linkedin_jobs_found, length(jobs)})

            Enum.each(jobs, fn job ->
              with {:ok, detail} <- LinkedIn.job_detail(job.linkedin_job_id),
                   description_text = detail[:description_text] || "",
                   {:ok, raw_extracted} <- JobExtractor.extract(description_text, user_id: user_id),
                   {:ok, extracted} <- JobExtractor.validate(raw_extracted),
                   texts = JobExtractor.vector_texts(extracted),
                   {:ok, embeddings} <-
                     Embedding.embed_batch([texts.title, texts.description], user_id: user_id) do
                send(pid, {
                  :linkedin_job_ready,
                  %{
                    raw: job,
                    detail: detail,
                    extracted: extracted,
                    title_embedding: Enum.at(embeddings, 0),
                    desc_embedding: Enum.at(embeddings, 1)
                  }
                })
              else
                error ->
                  send(pid, {:linkedin_job_error, job[:linkedin_job_id], error})
              end
            end)

            send(pid, :linkedin_pipeline_complete)

          {:error, reason} ->
            send(pid, {:search_error, "LinkedIn search failed: #{inspect(reason)}"})
        end
      end)

      {:noreply,
       assign(socket,
         searching: true,
         results: [],
         phases: phases,
         error: nil,
         expanded_why: MapSet.new()
       )}
    end
  end

  # --- Save as Interest ---

  def handle_event("save_as_interest", %{"idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    result = Enum.at(socket.assigns.results, idx)

    if result && !result.saved_interest_id do
      extracted = result[:extracted] || %{}

      params = %{
        user_id: socket.assigns.current_user.id,
        position_title: result.title,
        company_name: result.company,
        location: result.location,
        job_url: result[:url],
        job_description: extracted[:description] || "",
        status: "interested",
        priority: "medium",
        work_model: format_work_model(extracted[:remote_policy])
      }

      case Jobs.create_job_interest(params) do
        {:ok, interest} ->
          results =
            List.update_at(socket.assigns.results, idx, fn r ->
              Map.put(r, :saved_interest_id, interest.id)
            end)

          {:noreply,
           socket
           |> assign(:results, results)
           |> put_flash(:info, "Saved as job interest")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save job interest")}
      end
    else
      {:noreply, socket}
    end
  end

  # --- Rate and auto-save (LinkedIn results) ---

  def handle_event("rate_and_save", %{"idx" => idx_str, "rating" => rating}, socket) do
    idx = String.to_integer(idx_str)
    result = Enum.at(socket.assigns.results, idx)

    if result && !result.saved_interest_id do
      user_id = socket.assigns.current_user.id
      extracted = result[:extracted] || %{}

      params = %{
        user_id: user_id,
        position_title: result.title,
        company_name: result.company,
        location: result.location,
        job_url: result[:url],
        job_description: extracted[:description] || "",
        status: "interested",
        priority: "medium",
        work_model: format_work_model(extracted[:remote_policy])
      }

      case Jobs.create_job_interest(params) do
        {:ok, interest} ->
          # Apply rating
          case rating do
            "up" -> Feedback.thumbs_up(user_id, interest.id)
            "down" -> Feedback.thumbs_down(user_id, interest.id)
          end

          # Update results list
          results =
            List.update_at(socket.assigns.results, idx, fn r ->
              Map.put(r, :saved_interest_id, interest.id)
            end)

          thumbs_state = if rating == "up", do: :up, else: :down

          {:noreply,
           socket
           |> assign(:results, results)
           |> update_feedback_state(interest.id, :thumbs, thumbs_state)
           |> update(:feedback_count, &(&1 + 1))
           |> assign(:show_why_for, interest.id)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save job interest")}
      end
    else
      {:noreply, socket}
    end
  end

  # --- Why this match? ---

  def handle_event("toggle_why_match", %{"idx" => idx_str}, socket) do
    idx = String.to_integer(idx_str)

    expanded =
      if MapSet.member?(socket.assigns.expanded_why, idx) do
        MapSet.delete(socket.assigns.expanded_why, idx)
      else
        MapSet.put(socket.assigns.expanded_why, idx)
      end

    {:noreply, assign(socket, :expanded_why, expanded)}
  end

  # --- Feedback event handlers (same pattern as DashboardLive) ---

  def handle_event("thumbs_up", %{"job-id" => job_id_str}, socket) do
    user_id = socket.assigns.current_user.id
    job_id = String.to_integer(job_id_str)
    {:ok, _} = Feedback.thumbs_up(user_id, job_id)

    socket =
      socket
      |> update_feedback_state(job_id, :thumbs, :up)
      |> update(:feedback_count, &(&1 + 1))
      |> assign(:last_rated_job_id, job_id)
      |> assign(:show_why_for, job_id)

    {:noreply, socket}
  end

  def handle_event("thumbs_down", %{"job-id" => job_id_str}, socket) do
    user_id = socket.assigns.current_user.id
    job_id = String.to_integer(job_id_str)
    {:ok, _} = Feedback.thumbs_down(user_id, job_id)

    socket =
      socket
      |> update_feedback_state(job_id, :thumbs, :down)
      |> update(:feedback_count, &(&1 + 1))
      |> assign(:last_rated_job_id, job_id)
      |> assign(:show_why_for, job_id)

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
    result = Enum.find(socket.assigns.results, fn r -> r[:saved_interest_id] == job_id end)
    company_name = if result, do: result.company, else: ""

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

    # Remove blocked company results
    results =
      Enum.reject(socket.assigns.results, fn r ->
        String.downcase(r.company || "") == String.downcase(company_name)
      end)

    {:noreply,
     socket
     |> assign(:show_block_modal, false)
     |> assign(:block_company_name, "")
     |> assign(:results, results)
     |> assign(:blocked_companies, [company_name | socket.assigns.blocked_companies])}
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

  def handle_event("quick_why", %{"reason" => reason}, socket) do
    user_id = socket.assigns.current_user.id
    job_id = socket.assigns.show_why_for

    if job_id, do: Feedback.record_why(user_id, job_id, reason)

    {:noreply, assign(socket, :show_why_for, nil)}
  end

  def handle_event("dismiss_inline_why", _params, socket) do
    {:noreply, assign(socket, :show_why_for, nil)}
  end

  # --- handle_info callbacks ---

  @impl true
  def handle_info({:saved_phase, phase_id}, socket) do
    {:noreply, update_phase(socket, phase_id, :in_progress)}
  end

  def handle_info({:saved_results, vec_results, jobs}, socket) do
    blocked = socket.assigns.blocked_companies
    user_prefs = socket.assigns.user_prefs
    booster = socket.assigns.booster
    jobs_map = Map.new(jobs, &{&1.id, &1})

    results =
      vec_results
      |> Enum.map(fn {id, combined_dist, title_dist, desc_dist} ->
        case Map.get(jobs_map, id) do
          nil ->
            nil

          job ->
            if String.downcase(job.company_name || "") in Enum.map(blocked, &String.downcase/1) do
              nil
            else
              similarities = %{
                title: max(0.0, 1.0 - title_dist),
                description: max(0.0, 1.0 - desc_dist),
                composite: max(0.0, 1.0 - combined_dist),
                skills: 0.0,
                requirements: 0.0
              }

              job_map = %{
                title_clean: job.position_title,
                company_name: job.company_name,
                location: job.location,
                remote_policy: job.work_model,
                salary_min: job.salary_min,
                salary_max: job.salary_max
              }

              features = FeatureExtractor.extract(job_map, similarities, user_prefs)

              score =
                case booster do
                  nil -> max(0.0, 1.0 - combined_dist)
                  b -> Ranker.predict(b, [features]) |> List.first()
                end

              %{
                id: job.id,
                title: job.position_title,
                company: job.company_name,
                location: job.location,
                work_model: job.work_model,
                salary_range: format_salary(job.salary_min, job.salary_max),
                score: score,
                features: features,
                source: :saved,
                url: job.job_url,
                saved_interest_id: job.id
              }
            end
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.score, :desc)

    # Load feedback states
    job_ids = Enum.map(results, & &1.saved_interest_id) |> Enum.reject(&is_nil/1)
    feedback_states = Feedback.get_feedback_states(socket.assigns.current_user.id, job_ids)

    {:noreply,
     socket
     |> assign(:results, results)
     |> assign(:searching, false)
     |> assign(:feedback_states, feedback_states)
     |> update_phase(:searching, :complete)
     |> update_phase(:ranking, :complete)}
  end

  def handle_info({:linkedin_jobs_found, count}, socket) do
    socket =
      socket
      |> update_phase(:searching, :complete)
      |> update_phase(:details, :in_progress)
      |> update_phase_label(:details, "Loading details (0/#{count})")

    {:noreply, assign(socket, :linkedin_total, count)}
  end

  def handle_info({:linkedin_job_ready, processed}, socket) do
    user_prefs = socket.assigns.user_prefs
    booster = socket.assigns.booster
    blocked = socket.assigns.blocked_companies

    extracted = processed.extracted
    company = extracted[:company_name] || processed.raw[:company]

    # Skip blocked companies
    if String.downcase(company || "") in Enum.map(blocked, &String.downcase/1) do
      {:noreply, socket}
    else
      # Compute similarities if we have user resume embeddings
      similarities = %{
        title: 0.5,
        description: 0.5,
        composite: 0.5,
        skills: 0.0,
        requirements: 0.0
      }

      features = FeatureExtractor.extract(extracted, similarities, user_prefs)

      score =
        case booster do
          nil -> similarities.composite
          b -> Ranker.predict(b, [features]) |> List.first()
        end

      # Merge description into extracted for the detail panel
      extracted_with_desc =
        Map.put(extracted, :description, processed.detail[:description_text])

      result = %{
        id: processed.raw[:linkedin_job_id] || System.unique_integer([:positive]),
        title: extracted[:title_clean] || processed.raw[:title],
        company: company,
        location: processed.detail[:location] || processed.raw[:location],
        work_model: extracted[:remote_policy],
        salary_range: format_salary(extracted[:salary_min], extracted[:salary_max]),
        score: score,
        features: features,
        extracted: extracted_with_desc,
        source: :linkedin,
        url: processed.raw[:url],
        saved_interest_id: nil
      }

      # Insert in sorted order
      results = insert_sorted(socket.assigns.results, result)
      processed_count = length(results)
      total = Map.get(socket.assigns, :linkedin_total, 25)

      socket =
        socket
        |> assign(:results, results)
        |> update_phase(:details, :in_progress)
        |> update_phase_label(:details, "Loading details (#{processed_count}/#{total})")

      {:noreply, socket}
    end
  end

  def handle_info({:linkedin_job_error, _job_id, _error}, socket) do
    # Silently skip failed jobs
    {:noreply, socket}
  end

  def handle_info(:linkedin_pipeline_complete, socket) do
    {:noreply,
     socket
     |> assign(:searching, false)
     |> update_phase(:details, :complete)
     |> update_phase(:extracting, :complete)
     |> update_phase(:ranking, :complete)}
  end

  def handle_info({:search_error, message}, socket) do
    {:noreply,
     socket
     |> assign(:searching, false)
     |> assign(:error, message)
     |> update_all_phases(:error)}
  end

  # --- Private helpers ---

  defp update_feedback_state(socket, job_id, key, value) do
    states = socket.assigns.feedback_states
    current = Map.get(states, job_id, %{thumbs: nil, bookmarked: false})
    updated = Map.put(current, key, value)
    assign(socket, :feedback_states, Map.put(states, job_id, updated))
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

  defp update_phase(socket, phase_id, status) do
    phases =
      Enum.map(socket.assigns.phases, fn phase ->
        if phase.id == phase_id, do: %{phase | status: status}, else: phase
      end)

    assign(socket, :phases, phases)
  end

  defp update_phase_label(socket, phase_id, label) do
    phases =
      Enum.map(socket.assigns.phases, fn phase ->
        if phase.id == phase_id, do: %{phase | label: label}, else: phase
      end)

    assign(socket, :phases, phases)
  end

  defp update_all_phases(socket, status) do
    phases =
      Enum.map(socket.assigns.phases, fn phase ->
        if phase.status == :in_progress, do: %{phase | status: status}, else: phase
      end)

    assign(socket, :phases, phases)
  end

  defp insert_sorted(results, new_result) do
    {before, after_list} =
      Enum.split_while(results, fn r -> r.score >= new_result.score end)

    before ++ [new_result | after_list]
  end

  defp maybe_add_remote(opts, true), do: Keyword.put(opts, :remote, true)
  defp maybe_add_remote(opts, false), do: opts

  defp maybe_add_experience(opts, "any"), do: opts

  defp maybe_add_experience(opts, level),
    do: Keyword.put(opts, :experience, [String.to_atom(level)])

  defp format_score(score) when is_float(score), do: "#{round(score * 100)}%"
  defp format_score(_), do: "N/A"

  defp score_badge(score) when is_float(score) and score >= 0.7, do: "badge-success"
  defp score_badge(score) when is_float(score) and score >= 0.4, do: "badge-warning"
  defp score_badge(score) when is_float(score), do: "badge-error"
  defp score_badge(_), do: "badge-ghost"

  defp format_training_phase("llm_proxy"), do: "Collecting"
  defp format_training_phase("simple_model"), do: "Simple Model"
  defp format_training_phase("full_model"), do: "Full Model"
  defp format_training_phase(other), do: other

  defp phase_badge("llm_proxy"), do: "badge-warning"
  defp phase_badge("simple_model"), do: "badge-info"
  defp phase_badge("full_model"), do: "badge-success"
  defp phase_badge(_), do: "badge-ghost"

  defp format_feature_name(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp feature_color(value) when is_float(value) and value >= 0.7, do: "text-green-600"
  defp feature_color(value) when is_float(value) and value >= 0.4, do: "text-yellow-600"
  defp feature_color(value) when is_float(value) and value >= 0.0, do: "text-red-600"
  defp feature_color(_), do: "text-gray-600"

  defp format_salary(nil, nil), do: nil
  defp format_salary(min, nil), do: "$#{format_number(min)}+"
  defp format_salary(nil, max), do: "Up to $#{format_number(max)}"
  defp format_salary(min, max), do: "$#{format_number(min)} - $#{format_number(max)}"

  defp format_number(n) when is_integer(n) and n >= 1000 do
    "#{div(n, 1000)}k"
  end

  defp format_number(n), do: "#{n}"

  defp skills_list(extracted) when is_map(extracted) do
    required = extracted[:required_skills] || []
    preferred = extracted[:preferred_skills] || []
    tech = extracted[:tech_stack] || []
    (required ++ preferred ++ tech) |> Enum.uniq() |> Enum.take(15)
  end

  defp skills_list(_), do: []

  defp format_work_model(nil), do: "remote"
  defp format_work_model("full_remote"), do: "remote"
  defp format_work_model("hybrid_2d"), do: "hybrid"
  defp format_work_model("hybrid_3d"), do: "hybrid"
  defp format_work_model("onsite"), do: "onsite"
  defp format_work_model("flexible"), do: "remote"
  defp format_work_model(other), do: other
end
