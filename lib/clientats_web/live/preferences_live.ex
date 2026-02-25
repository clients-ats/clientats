defmodule ClientatsWeb.PreferencesLive do
  use ClientatsWeb, :live_view

  alias Clientats.Feedback
  alias Clientats.Feedback.RankingModel

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    preferences = Feedback.get_all_preferences(user_id)
    prefs_map = build_prefs_map(preferences)
    blocked = Feedback.blocked_companies(user_id)
    feedback_count = Feedback.feedback_count(user_id)
    saved_searches = Feedback.get_saved_searches(user_id)

    {model_info, training_phase} = load_model_info(user_id, feedback_count)

    {:ok,
     socket
     |> assign(:page_title, "Matching Preferences")
     |> assign(:prefs, prefs_map)
     |> assign(:blocked_companies, blocked)
     |> assign(:feedback_count, feedback_count)
     |> assign(:training_phase, training_phase)
     |> assign(:model_info, model_info)
     |> assign(:training, false)
     |> assign(:saved_searches, saved_searches)
     |> assign(:new_skill, "")
     |> assign(:new_role, "")
     |> assign(:new_industry, "")
     |> assign(:new_block, "")}
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
            <h1 class="text-2xl font-bold text-gray-900">Matching Preferences</h1>
          </div>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-3xl space-y-6">
        <%!-- Skills --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Skills</h2>
          <div class="flex flex-wrap gap-2 mb-3">
            <%= for skill <- @prefs.skills do %>
              <span class="badge badge-lg gap-1">
                {skill}
                <button
                  phx-click="remove_item"
                  phx-value-type="skills"
                  phx-value-item={skill}
                  class="text-gray-500 hover:text-red-500"
                >
                  x
                </button>
              </span>
            <% end %>
            <span :if={@prefs.skills == []} class="text-sm text-gray-400">
              No skills added yet
            </span>
          </div>
          <form phx-submit="add_item" class="flex gap-2">
            <input type="hidden" name="type" value="skills" />
            <input
              type="text"
              name="item"
              value={@new_skill}
              phx-change="update_input"
              phx-value-field="new_skill"
              placeholder="Add a skill..."
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-sm btn-primary">Add</button>
          </form>
        </div>

        <%!-- Target Roles --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Target Roles</h2>
          <div class="flex flex-wrap gap-2 mb-3">
            <%= for role <- @prefs.roles do %>
              <span class="badge badge-lg badge-outline gap-1">
                {role}
                <button
                  phx-click="remove_item"
                  phx-value-type="roles"
                  phx-value-item={role}
                  class="text-gray-500 hover:text-red-500"
                >
                  x
                </button>
              </span>
            <% end %>
            <span :if={@prefs.roles == []} class="text-sm text-gray-400">
              No target roles added yet
            </span>
          </div>
          <form phx-submit="add_item" class="flex gap-2">
            <input type="hidden" name="type" value="roles" />
            <input
              type="text"
              name="item"
              value={@new_role}
              phx-change="update_input"
              phx-value-field="new_role"
              placeholder="Add a target role..."
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-sm btn-primary">Add</button>
          </form>
        </div>

        <%!-- Industries --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Industries</h2>
          <div class="flex flex-wrap gap-2 mb-3">
            <%= for industry <- @prefs.industries do %>
              <span class="badge badge-lg badge-secondary gap-1">
                {industry}
                <button
                  phx-click="remove_item"
                  phx-value-type="industries"
                  phx-value-item={industry}
                  class="text-gray-500 hover:text-red-500"
                >
                  x
                </button>
              </span>
            <% end %>
            <span :if={@prefs.industries == []} class="text-sm text-gray-400">
              No industries added yet
            </span>
          </div>
          <form phx-submit="add_item" class="flex gap-2">
            <input type="hidden" name="type" value="industries" />
            <input
              type="text"
              name="item"
              value={@new_industry}
              phx-change="update_input"
              phx-value-field="new_industry"
              placeholder="Add an industry..."
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-sm btn-primary">Add</button>
          </form>
        </div>

        <%!-- Seniority & Work Model --%>
        <div class="bg-white rounded-lg shadow p-6">
          <div class="grid md:grid-cols-2 gap-6">
            <div>
              <h2 class="text-lg font-semibold text-gray-900 mb-3">Seniority Level</h2>
              <select
                class="select select-bordered w-full"
                phx-change="update_seniority"
                name="level"
              >
                <option value="" selected={@prefs.seniority == ""}>Select...</option>
                <%= for level <- ~w(intern junior mid senior staff principal director vp c_level) do %>
                  <option value={level} selected={@prefs.seniority == level}>
                    {String.capitalize(String.replace(level, "_", " "))}
                  </option>
                <% end %>
              </select>
            </div>

            <div>
              <h2 class="text-lg font-semibold text-gray-900 mb-3">Work Model</h2>
              <div class="flex flex-col gap-2">
                <%= for model <- ~w(remote hybrid onsite) do %>
                  <label class="flex items-center gap-2 cursor-pointer">
                    <input
                      type="radio"
                      name="work_model"
                      value={model}
                      checked={@prefs.work_model == model}
                      phx-click="update_work_model"
                      phx-value-model={model}
                      class="radio radio-sm"
                    />
                    <span class="text-sm">{String.capitalize(model)}</span>
                  </label>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- Location & Salary --%>
        <div class="bg-white rounded-lg shadow p-6">
          <div class="grid md:grid-cols-2 gap-6">
            <div>
              <h2 class="text-lg font-semibold text-gray-900 mb-3">Preferred Location</h2>
              <form phx-change="update_location">
                <input
                  type="text"
                  name="location"
                  value={@prefs.location}
                  placeholder="e.g. San Francisco, Remote, NYC..."
                  class="input input-bordered w-full"
                  phx-debounce="500"
                />
              </form>
            </div>

            <div>
              <h2 class="text-lg font-semibold text-gray-900 mb-3">Salary Range</h2>
              <form phx-change="update_salary" class="flex gap-2 items-center">
                <div>
                  <label class="text-xs text-gray-500">Min</label>
                  <input
                    type="number"
                    name="salary_min"
                    value={@prefs.salary_min}
                    placeholder="80000"
                    class="input input-bordered input-sm w-full"
                    phx-debounce="500"
                  />
                </div>
                <span class="mt-5 text-gray-400">-</span>
                <div>
                  <label class="text-xs text-gray-500">Max</label>
                  <input
                    type="number"
                    name="salary_max"
                    value={@prefs.salary_max}
                    placeholder="150000"
                    class="input input-bordered input-sm w-full"
                    phx-debounce="500"
                  />
                </div>
              </form>
            </div>
          </div>
        </div>

        <%!-- Saved Searches --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-1">Saved Searches</h2>
          <p class="text-sm text-gray-500 mb-3">
            Enabled searches run automatically each night to discover new job postings.
          </p>

          <div class="space-y-3 mb-4">
            <%= for {search, idx} <- Enum.with_index(@saved_searches) do %>
              <div class={[
                "flex items-center justify-between rounded-lg px-4 py-3 border",
                if(search["enabled"], do: "bg-green-50 border-green-200", else: "bg-gray-50 border-gray-200")
              ]}>
                <div class="flex-1">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-gray-900">{search["keywords"]}</span>
                    <span :if={search["remote"]} class="badge badge-xs badge-info">Remote</span>
                    <span :if={search["experience"]} class="badge badge-xs badge-ghost">
                      {format_experience(search["experience"])}
                    </span>
                  </div>
                  <span :if={search["location"]} class="text-xs text-gray-500">
                    {search["location"]}
                  </span>
                </div>
                <div class="flex items-center gap-2">
                  <button
                    phx-click="toggle_search"
                    phx-value-index={idx}
                    class={["btn btn-xs", if(search["enabled"], do: "btn-success", else: "btn-ghost")]}
                  >
                    {if search["enabled"], do: "Enabled", else: "Disabled"}
                  </button>
                  <button
                    phx-click="remove_search"
                    phx-value-index={idx}
                    class="btn btn-xs btn-ghost text-red-500"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </button>
                </div>
              </div>
            <% end %>
            <p :if={@saved_searches == []} class="text-sm text-gray-400">
              No saved searches yet. Add one below or save from the Discover page.
            </p>
          </div>

          <form phx-submit="add_search" class="space-y-3 border-t pt-4">
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="text-xs text-gray-500">Keywords *</label>
                <input
                  type="text"
                  name="keywords"
                  placeholder="e.g. Java backend"
                  class="input input-bordered input-sm w-full"
                  required
                />
              </div>
              <div>
                <label class="text-xs text-gray-500">Location</label>
                <input
                  type="text"
                  name="location"
                  placeholder="United States"
                  class="input input-bordered input-sm w-full"
                />
              </div>
            </div>
            <div class="flex items-center gap-4">
              <label class="flex items-center gap-2 cursor-pointer">
                <input type="checkbox" name="remote" value="true" class="checkbox checkbox-sm" />
                <span class="text-sm">Remote only</span>
              </label>
              <select name="experience" class="select select-bordered select-sm">
                <option value="">Any experience</option>
                <option value="entry_level">Entry Level</option>
                <option value="associate">Associate</option>
                <option value="mid_senior">Mid-Senior</option>
                <option value="director">Director</option>
                <option value="executive">Executive</option>
              </select>
              <button type="submit" class="btn btn-sm btn-primary ml-auto">Add Search</button>
            </div>
          </form>
        </div>

        <%!-- Blocked Companies --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Blocked Companies</h2>
          <div class="space-y-2 mb-3">
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
          <form phx-submit="block_company" class="flex gap-2">
            <input
              type="text"
              name="company"
              value={@new_block}
              placeholder="Company name..."
              class="input input-bordered input-sm flex-1"
            />
            <button type="submit" class="btn btn-sm btn-error btn-outline">Block</button>
          </form>
        </div>

        <%!-- Model Status --%>
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Model Status</h2>
          <div class="grid md:grid-cols-2 gap-4">
            <div class="space-y-2">
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">Training Phase</span>
                <span class={["badge badge-sm", phase_badge(@training_phase)]}>
                  {format_phase(@training_phase)}
                </span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500">Feedback Signals</span>
                <span class="font-medium">{@feedback_count}</span>
              </div>
              <div :if={@model_info} class="flex justify-between text-sm">
                <span class="text-gray-500">Training Examples</span>
                <span class="font-medium">{@model_info.training_examples}</span>
              </div>
              <div :if={@model_info} class="flex justify-between text-sm">
                <span class="text-gray-500">Last Trained</span>
                <span class="font-medium">
                  {Calendar.strftime(@model_info.updated_at, "%b %d, %Y %H:%M")}
                </span>
              </div>
            </div>

            <div :if={@model_info && @model_info.metrics != %{}} class="space-y-2">
              <h3 class="text-sm font-medium text-gray-700">Model Metrics</h3>
              <div :if={@model_info.metrics["accuracy"]} class="flex justify-between text-sm">
                <span class="text-gray-500">Accuracy</span>
                <span class="font-mono">
                  {Float.round(@model_info.metrics["accuracy"] * 100, 1)}%
                </span>
              </div>
              <div :if={@model_info.metrics["auc"]} class="flex justify-between text-sm">
                <span class="text-gray-500">AUC</span>
                <span class="font-mono">{Float.round(@model_info.metrics["auc"], 3)}</span>
              </div>
              <div :if={@model_info.metrics["precision"]} class="flex justify-between text-sm">
                <span class="text-gray-500">Precision</span>
                <span class="font-mono">
                  {Float.round(@model_info.metrics["precision"] * 100, 1)}%
                </span>
              </div>
              <div :if={@model_info.metrics["recall"]} class="flex justify-between text-sm">
                <span class="text-gray-500">Recall</span>
                <span class="font-mono">
                  {Float.round(@model_info.metrics["recall"] * 100, 1)}%
                </span>
              </div>
            </div>
          </div>

          <div class="mt-4">
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
            <p :if={@feedback_count < 10} class="text-xs text-gray-500 mt-1">
              Need at least 10 feedback signals to train (have {@feedback_count})
            </p>
            <.link navigate={~p"/dashboard/feedback-history"} class="btn btn-sm btn-ghost ml-2">
              View Feedback History
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("update_input", params, socket) do
    # Handle phx-change on text inputs
    field = params["field"] || params["_target"] |> List.last()

    socket =
      case field do
        "new_skill" -> assign(socket, :new_skill, params["item"] || "")
        "new_role" -> assign(socket, :new_role, params["item"] || "")
        "new_industry" -> assign(socket, :new_industry, params["item"] || "")
        _ -> socket
      end

    {:noreply, socket}
  end

  def handle_event("add_item", %{"type" => type, "item" => item}, socket) do
    item = String.trim(item)

    if item == "" do
      {:noreply, socket}
    else
      user_id = socket.assigns.current_user.id
      prefs = socket.assigns.prefs

      {list_key, input_key} =
        case type do
          "skills" -> {:skills, :new_skill}
          "roles" -> {:roles, :new_role}
          "industries" -> {:industries, :new_industry}
        end

      current_list = Map.get(prefs, list_key, [])

      if item in current_list do
        {:noreply, socket}
      else
        new_list = current_list ++ [item]
        save_list_preference(user_id, type, new_list)
        prefs = Map.put(prefs, list_key, new_list)

        {:noreply,
         socket
         |> assign(:prefs, prefs)
         |> assign(input_key, "")
         |> put_flash(:info, "Saved")}
      end
    end
  end

  def handle_event("remove_item", %{"type" => type, "item" => item}, socket) do
    user_id = socket.assigns.current_user.id
    prefs = socket.assigns.prefs

    list_key =
      case type do
        "skills" -> :skills
        "roles" -> :roles
        "industries" -> :industries
      end

    new_list = List.delete(Map.get(prefs, list_key, []), item)
    save_list_preference(user_id, type, new_list)
    prefs = Map.put(prefs, list_key, new_list)

    {:noreply,
     socket
     |> assign(:prefs, prefs)
     |> put_flash(:info, "Saved")}
  end

  def handle_event("update_seniority", %{"level" => level}, socket) do
    user_id = socket.assigns.current_user.id
    Feedback.set_preference(user_id, "seniority", %{"level" => level})
    prefs = Map.put(socket.assigns.prefs, :seniority, level)

    {:noreply,
     socket
     |> assign(:prefs, prefs)
     |> put_flash(:info, "Saved")}
  end

  def handle_event("update_work_model", %{"model" => model}, socket) do
    user_id = socket.assigns.current_user.id
    Feedback.set_preference(user_id, "work_model", %{"preferred" => model})
    prefs = Map.put(socket.assigns.prefs, :work_model, model)

    {:noreply,
     socket
     |> assign(:prefs, prefs)
     |> put_flash(:info, "Saved")}
  end

  def handle_event("update_location", %{"location" => location}, socket) do
    user_id = socket.assigns.current_user.id
    Feedback.set_preference(user_id, "location", %{"preferred" => location})
    prefs = Map.put(socket.assigns.prefs, :location, location)

    {:noreply, assign(socket, :prefs, prefs)}
  end

  def handle_event("update_salary", params, socket) do
    user_id = socket.assigns.current_user.id

    salary_min = parse_int(params["salary_min"])
    salary_max = parse_int(params["salary_max"])

    Feedback.set_preference(user_id, "salary", %{"min" => salary_min, "max" => salary_max})

    prefs =
      socket.assigns.prefs
      |> Map.put(:salary_min, salary_min)
      |> Map.put(:salary_max, salary_max)

    {:noreply, assign(socket, :prefs, prefs)}
  end

  def handle_event("block_company", %{"company" => company}, socket) do
    company = String.trim(company)

    if company == "" do
      {:noreply, socket}
    else
      user_id = socket.assigns.current_user.id
      {:ok, _} = Feedback.block_company(user_id, company)
      blocked = Feedback.blocked_companies(user_id)

      {:noreply,
       socket
       |> assign(:blocked_companies, blocked)
       |> assign(:new_block, "")
       |> put_flash(:info, "Company blocked")}
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

  def handle_event("add_search", params, socket) do
    user_id = socket.assigns.current_user.id

    search_params = %{
      "keywords" => String.trim(params["keywords"] || ""),
      "location" => String.trim(params["location"] || ""),
      "remote" => params["remote"] == "true",
      "experience" => params["experience"]
    }

    case Feedback.add_saved_search(user_id, search_params) do
      {:ok, _} ->
        searches = Feedback.get_saved_searches(user_id)

        {:noreply,
         socket
         |> assign(:saved_searches, searches)
         |> put_flash(:info, "Search saved")}

      {:error, :keywords_required} ->
        {:noreply, put_flash(socket, :error, "Keywords are required")}
    end
  end

  def handle_event("remove_search", %{"index" => index}, socket) do
    user_id = socket.assigns.current_user.id
    idx = String.to_integer(index)
    Feedback.remove_saved_search(user_id, idx)
    searches = Feedback.get_saved_searches(user_id)

    {:noreply,
     socket
     |> assign(:saved_searches, searches)
     |> put_flash(:info, "Search removed")}
  end

  def handle_event("toggle_search", %{"index" => index}, socket) do
    user_id = socket.assigns.current_user.id
    idx = String.to_integer(index)
    Feedback.toggle_saved_search(user_id, idx)
    searches = Feedback.get_saved_searches(user_id)

    {:noreply, assign(socket, :saved_searches, searches)}
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

  defp build_prefs_map(preferences) do
    base = %{
      skills: [],
      roles: [],
      industries: [],
      seniority: "",
      work_model: "",
      location: "",
      salary_min: nil,
      salary_max: nil
    }

    Enum.reduce(preferences, base, fn pref, acc ->
      case pref.preference_type do
        "skills" -> Map.put(acc, :skills, pref.value["list"] || [])
        "roles" -> Map.put(acc, :roles, pref.value["list"] || [])
        "industries" -> Map.put(acc, :industries, pref.value["list"] || [])
        "seniority" -> Map.put(acc, :seniority, pref.value["level"] || "")
        "work_model" -> Map.put(acc, :work_model, pref.value["preferred"] || "")
        "location" -> Map.put(acc, :location, pref.value["preferred"] || "")
        "salary" ->
          acc
          |> Map.put(:salary_min, pref.value["min"])
          |> Map.put(:salary_max, pref.value["max"])
        _ -> acc
      end
    end)
  end

  defp load_model_info(user_id, feedback_count) do
    case Feedback.get_ranking_model(user_id) do
      {:ok, _booster, model} ->
        {model, model.phase}

      {:error, :no_model} ->
        {nil, RankingModel.phase_for_count(feedback_count)}
    end
  end

  defp save_list_preference(user_id, type, list) do
    Feedback.set_preference(user_id, type, %{"list" => list})
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp parse_int(n) when is_integer(n), do: n

  defp format_phase("llm_proxy"), do: "Collecting"
  defp format_phase("simple_model"), do: "Simple Model"
  defp format_phase("full_model"), do: "Full Model"
  defp format_phase(other), do: other

  defp format_experience("entry_level"), do: "Entry Level"
  defp format_experience("associate"), do: "Associate"
  defp format_experience("mid_senior"), do: "Mid-Senior"
  defp format_experience("director"), do: "Director"
  defp format_experience("executive"), do: "Executive"
  defp format_experience(nil), do: nil
  defp format_experience(other), do: other

  defp phase_badge("llm_proxy"), do: "badge-warning"
  defp phase_badge("simple_model"), do: "badge-info"
  defp phase_badge("full_model"), do: "badge-success"
  defp phase_badge(_), do: "badge-ghost"
end
