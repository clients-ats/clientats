defmodule ClientatsWeb.JobInterestLive.Scrape do
  use ClientatsWeb, :live_view

  alias Clientats.LLM.Service
  alias Clientats.LLM.ErrorHandler
  alias Clientats.LLMConfig
  alias Clientats.Jobs

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    # Check if any LLM providers are configured
    enabled_providers = LLMConfig.get_enabled_providers(user_id)

    if Enum.empty?(enabled_providers) do
      # Redirect to dashboard with error message
      {:ok,
       socket
       |> put_flash(
         :error,
         "Please configure at least one LLM provider first. Visit the LLM Configuration page."
       )
       |> redirect(to: ~p"/dashboard")}
    else
      # Get the user's preferred LLM provider (defaults to ollama if not set)
      llm_provider = get_preferred_provider(user_id, enabled_providers)
      estimated_time_ms = get_estimated_provider_time(llm_provider)

      {:ok,
       socket
       |> assign(:page_title, "Import Job from URL")
       |> assign(:step, 1)
       |> assign(:url, "")
       |> assign(:scraping, false)
       |> assign(:scraping_start_time, nil)
       |> assign(:saving, false)
       |> assign(:scraped_data, %{})
       |> assign(:error, nil)
       |> assign(:error_details, nil)
       |> assign(:manual_entry_mode, false)
       |> assign(:llm_provider, llm_provider)
       |> assign(:llm_status, nil)
       |> assign(:estimated_llm_time_ms, estimated_time_ms)
       |> assign(:remaining_llm_time_ms, estimated_time_ms)
       |> assign(:current_phase, nil)
       |> assign(:phases, [
         %{id: :loading, label: "Loading page", status: :pending},
         %{id: :screenshot, label: "Taking screenshot", status: :pending},
         %{id: :sending, label: "Sending to AI", status: :pending},
         %{id: :processing, label: "Processing response", status: :pending},
         %{id: :complete, label: "Complete", status: :pending}
       ])
       |> assign(:supported_sites, [
         "linkedin.com",
         "indeed.com",
         "glassdoor.com",
         "angel.co",
         "lever.co",
         "greenhouse.io",
         "workday.com"
       ])}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_url", %{"url" => url}, socket) do
    {:noreply, socket |> assign(:url, url) |> assign(:error, nil)}
  end

  def handle_event("update_url", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("scrape_url", _params, socket) do
    url = String.trim(socket.assigns.url)
    provider = socket.assigns.llm_provider

    # Validate URL first
    case validate_url(url) do
      {:error, :invalid_url} ->
        {:noreply,
         socket
         |> assign(:error, "Please enter a valid URL starting with http:// or https://")}

      {:ok, _valid_url} ->
        # Check if Ollama is selected and available
        if provider == "ollama" do
          check_ollama_status(socket)
        else
          start_scraping(url, provider, socket)
        end
    end
  end

  def handle_event("save_job_interest", params, socket) do
    # Set saving state immediately to prevent multiple submissions
    socket = assign(socket, :saving, true)

    job_interest_params = %{
      user_id: socket.assigns.current_user.id,
      company_name: params["company_name"] || "",
      position_title: params["position_title"] || "",
      job_description: params["job_description"] || "",
      job_url: params["url"] || socket.assigns.url,
      location: params["location"] || "",
      work_model: params["work_model"] || "remote",
      status: "researching",
      priority: "medium"
    }

    case Jobs.create_job_interest(job_interest_params) do
      {:ok, job_interest} ->
        {:noreply,
         socket
         |> put_flash(:info, "Job interest created successfully!")
         |> push_navigate(to: ~p"/dashboard/job-interests/#{job_interest.id}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:error, "Failed to create job interest. Please check the form.")}
    end
  end

  def handle_event("back_to_url", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, 1)
     |> assign(:error, nil)
     |> assign(:error_details, nil)
     |> assign(:manual_entry_mode, false)}
  end

  def handle_event("toggle_manual_entry", _params, socket) do
    current_mode = socket.assigns.manual_entry_mode
    {:noreply, socket |> assign(:manual_entry_mode, !current_mode)}
  end

  def handle_event("retry_scrape", _params, socket) do
    # Clear error and try scraping the same URL again
    url = String.trim(socket.assigns.url)

    case validate_url(url) do
      {:error, :invalid_url} ->
        {:noreply,
         socket
         |> assign(:error, "Please enter a valid URL starting with http:// or https://")}

      {:ok, _valid_url} ->
        provider = socket.assigns.llm_provider

        if provider == "ollama" do
          check_ollama_status(socket)
        else
          start_scraping(url, provider, socket)
        end
    end
  end

  @impl true
  def handle_info(:ollama_available, socket) do
    start_scraping(socket.assigns.url, "ollama", socket)
  end

  def handle_info(:ollama_unavailable, socket) do
    # Check if we're still in checking state (not already processed)
    if socket.assigns.llm_status == "checking" do
      {:noreply,
       socket
       |> assign(:llm_status, "unavailable")
       |> assign(
         :error,
         "Ollama server is not available. Please start Ollama or select another provider."
       )}
    else
      # Already handled, do nothing
      {:noreply, socket}
    end
  end

  def handle_info({:phase_update, phase_id}, socket) do
    # Update the phase status to in_progress
    updated_phases =
      Enum.map(socket.assigns.phases, fn phase ->
        if phase.id == phase_id do
          %{phase | status: :in_progress}
        else
          phase
        end
      end)

    {:noreply,
     socket
     |> assign(:current_phase, phase_id)
     |> assign(:phases, updated_phases)}
  end

  def handle_info({:scrape_result, %{result: result}}, socket) do
    case result do
      {:ok, data} ->
        # Mark all phases as complete
        completed_phases = Enum.map(socket.assigns.phases, &Map.put(&1, :status, :complete))

        {:noreply,
         socket
         |> assign(:scraping, false)
         |> assign(:scraped_data, data)
         |> assign(:step, 2)
         |> assign(:phases, completed_phases)
         |> assign(:error, nil)
         |> assign(:error_details, nil)
         |> assign(:llm_status, "success")}

      {:error, reason} ->
        # Get comprehensive error details for fallback UI
        error_details = ErrorHandler.error_details(reason)

        {:noreply,
         socket
         |> assign(:scraping, false)
         |> assign(:error, error_details.user_message)
         |> assign(:error_details, error_details)
         |> assign(:llm_status, "error")}
    end
  end

  # Private functions

  defp validate_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] do
      {:ok, url}
    else
      {:error, :invalid_url}
    end
  end

  defp validate_url(_), do: {:error, :invalid_url}

  defp get_llm_providers do
    [
      %{
        id: "auto",
        name: "Auto (Recommended)",
        description: "Automatically select the best available provider",
        icon: "hero-cog"
      },
      %{
        id: "openai",
        name: "OpenAI (GPT-4)",
        description: "High accuracy, commercial API",
        icon: "hero-sparkles"
      },
      %{
        id: "anthropic",
        name: "Anthropic (Claude)",
        description: "Excellent reasoning, commercial API",
        icon: "hero-chat-bubble-left-ellipsis"
      },
      %{
        id: "mistral",
        name: "Mistral AI",
        description: "Open-source models, commercial API",
        icon: "hero-rocket-launch"
      },
      %{
        id: "ollama",
        name: "Ollama (Local)",
        description: "Privacy-focused, runs on your machine",
        icon: "hero-computer-desktop",
        local: true
      }
    ]
  end

  defp check_ollama_status(socket) do
    # Check if Ollama is available with timeout
    liveview_pid = self()

    spawn(fn ->
      case Clientats.LLM.Providers.Ollama.ping() do
        {:ok, :available} ->
          send(liveview_pid, :ollama_available)

        {:error, :unavailable} ->
          send(liveview_pid, :ollama_unavailable)
      end
    end)

    # Set a timeout to prevent hanging (must be longer than ping timeout)
    Process.send_after(self(), :ollama_unavailable, 15_000)

    {:noreply, assign(socket, :llm_status, "checking")}
  end

  defp start_scraping(url, provider, socket) do
    # Parse provider (handle both string and atom forms)
    llm_provider =
      case provider do
        "auto" -> nil
        :auto -> nil
        "ollama" -> :ollama
        :ollama -> :ollama
        "openai" -> :openai
        :openai -> :openai
        "anthropic" -> :anthropic
        :anthropic -> :anthropic
        "mistral" -> :mistral
        :mistral -> :mistral
        "gemini" -> :gemini
        :gemini -> :gemini
        "google" -> :google
        :google -> :google
        # Pass through if already an atom or unknown
        _ -> provider
      end

    # Get the estimated time for this specific provider
    estimated_time_ms = get_estimated_provider_time(provider)

    # Capture the current process PID to send messages back to LiveView
    liveview_pid = self()
    user_id = socket.assigns.current_user.id

    # Spawn scraping process
    spawn(fn ->
      result =
        case llm_provider do
          :ollama ->
            Service.extract_job_data_from_url(url, :generic,
              provider: :ollama,
              user_id: user_id,
              progress_callback: fn phase -> send(liveview_pid, {:phase_update, phase}) end
            )

          _ ->
            Service.extract_job_data_from_url(url, :generic,
              provider: llm_provider,
              user_id: user_id,
              progress_callback: fn phase -> send(liveview_pid, {:phase_update, phase}) end
            )
        end

      send(liveview_pid, {:scrape_result, %{result: result}})
    end)

    # Reset phases
    reset_phases = Enum.map(socket.assigns.phases, &Map.put(&1, :status, :pending))

    {:noreply,
     socket
     |> assign(:scraping, true)
     |> assign(:scraping_start_time, System.monotonic_time(:millisecond))
     |> assign(:estimated_llm_time_ms, estimated_time_ms)
     |> assign(:remaining_llm_time_ms, estimated_time_ms)
     |> assign(:current_phase, nil)
     |> assign(:phases, reset_phases)
     |> assign(:error, nil)
     |> assign(:llm_status, "processing")}
  end

  defp get_provider_icon(provider_id) do
    providers = get_llm_providers()

    case Enum.find(providers, &(&1.id == provider_id)) do
      %{icon: icon} -> icon
      _ -> "hero-cog"
    end
  end

  defp get_provider_name(provider_id) do
    providers = get_llm_providers()

    case Enum.find(providers, &(&1.id == provider_id)) do
      %{name: name} -> name
      _ -> provider_id
    end
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
        </div>
      </div>

      <div class="container mx-auto px-4">
        <.flash kind={:info} flash={@flash} />
        <.flash kind={:error} flash={@flash} />
      </div>

      <div class="container mx-auto px-4 py-8 max-w-3xl">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h1 class="text-2xl font-bold text-gray-900">Import Job from URL</h1>
            <p class="text-sm text-gray-600 mt-1">
              Paste a job posting URL to automatically extract details
            </p>
          </div>
          
    <!-- Provider Info - Using Global Configuration -->
          <div class="mb-6 p-4 bg-blue-50 rounded-lg border border-blue-200">
            <div class="flex items-center gap-3">
              <div class="flex-shrink-0">
                <.icon name="hero-cog-6-tooth" class="w-5 h-5 text-blue-600" />
              </div>
              <div class="flex-1">
                <p class="text-sm font-medium text-blue-900">
                  Using configured LLM provider: <span class="capitalize">{@llm_provider}</span>
                </p>
                <p class="text-xs text-blue-600 mt-0.5">
                  Change your provider in
                  <.link navigate={~p"/dashboard/llm-config"} class="underline hover:text-blue-800">
                    LLM Configuration
                  </.link>
                </p>
              </div>
            </div>
          </div>
          
    <!-- Progress Steps -->
          <div class="mb-8">
            <div class="flex items-center justify-between">
              <div class={"flex items-center gap-2 " <> step_class(1, @step)}>
                <div class={"w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold " <> step_color(1, @step)}>
                  {if @step > 1, do: "✓", else: "1"}
                </div>
                <span class="text-sm hidden sm:inline">Enter URL</span>
              </div>

              <div class="flex-1 h-0.5 bg-gray-200 mx-2">
                <div class={"h-full bg-blue-500 transition-all" <> progress_width(@step)}></div>
              </div>

              <div class={"flex items-center gap-2 " <> step_class(2, @step)}>
                <div class={"w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold " <> step_color(2, @step)}>
                  {if @step > 2, do: "✓", else: "2"}
                </div>
                <span class="text-sm hidden sm:inline">Review & Save</span>
              </div>
            </div>
          </div>
          
    <!-- Step 1: URL Input -->
          <%= if @step == 1 do %>
            <div class="space-y-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Job Posting URL
                </label>
                <form phx-change="update_url">
                  <div class="relative">
                    <input
                      type="text"
                      name="url"
                      placeholder="https://www.linkedin.com/jobs/view/123456789"
                      class="w-full px-4 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 pr-12"
                      value={@url}
                      disabled={@scraping}
                    />
                    <button
                      type="button"
                      phx-click="scrape_url"
                      disabled={@scraping || @url == ""}
                      class={"absolute right-2 top-1/2 -translate-y-1/2 btn btn-primary btn-sm " <>
                            if(@scraping || @url == "", do: "btn-disabled", else: "")}
                    >
                      <%= if @scraping do %>
                        <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
                      <% else %>
                        <.icon name="hero-arrow-right" class="w-4 h-4" />
                      <% end %>
                      {if @scraping, do: "Processing...", else: "Import"}
                    </button>
                  </div>
                </form>
                
    <!-- Error Recovery Panel with Fallback Options -->
                <%= if @error_details do %>
                  <div class="mt-4">
                    <.error_recovery_panel
                      error_details={@error_details}
                      on_manual_entry="toggle_manual_entry"
                      on_retry="retry_scrape"
                      on_config={~p"/dashboard/llm-config"}
                    />
                  </div>
                <% end %>
                
    <!-- Manual Entry Form (appears when all LLM providers fail) -->
                <%= if @manual_entry_mode && @error_details do %>
                  <div class="mt-6 bg-white rounded-lg border border-gray-300 p-6">
                    <h3 class="text-lg font-semibold text-gray-900 mb-4">
                      Enter Job Details Manually
                    </h3>
                    <p class="text-sm text-gray-600 mb-6">
                      Fill in the job information below. You can always edit it later.
                    </p>

                    <form phx-submit="save_job_interest" class="space-y-4">
                      <div class="grid md:grid-cols-2 gap-4">
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Company Name <span class="text-red-500">*</span>
                          </label>
                          <input
                            type="text"
                            name="company_name"
                            placeholder="e.g., Acme Inc."
                            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                            required
                          />
                        </div>
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Position Title <span class="text-red-500">*</span>
                          </label>
                          <input
                            type="text"
                            name="position_title"
                            placeholder="e.g., Senior Engineer"
                            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                            required
                          />
                        </div>
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Job URL
                        </label>
                        <input
                          type="url"
                          name="url"
                          value={@url}
                          placeholder="https://..."
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Job Description
                        </label>
                        <textarea
                          name="job_description"
                          rows="4"
                          placeholder="Paste the job description here..."
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        ></textarea>
                      </div>

                      <div class="grid md:grid-cols-2 gap-4">
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Location
                          </label>
                          <input
                            type="text"
                            name="location"
                            placeholder="e.g., San Francisco, CA"
                            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                          />
                        </div>
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">
                            Work Model
                          </label>
                          <select
                            name="work_model"
                            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                          >
                            <option value="remote">Remote</option>
                            <option value="hybrid">Hybrid</option>
                            <option value="on_site">On-site</option>
                          </select>
                        </div>
                      </div>

                      <div class="flex justify-end gap-3 pt-4 border-t border-gray-200">
                        <button
                          type="button"
                          phx-click="toggle_manual_entry"
                          class="btn btn-ghost"
                        >
                          Cancel
                        </button>
                        <button
                          type="submit"
                          class="btn btn-primary"
                          phx-disable-with="Saving..."
                        >
                          <.icon name="hero-check" class="w-4 h-4 mr-2" /> Save Job Interest
                        </button>
                      </div>
                    </form>
                  </div>
                <% end %>
                
    <!-- ETA Display during scraping -->
                <%= if @scraping do %>
                  <div class="mt-4 bg-gradient-to-r from-blue-50 to-indigo-50 border border-blue-200 rounded-lg p-4">
                    <div class="flex items-start gap-4">
                      <div class="flex-shrink-0">
                        <div class="flex items-center justify-center h-12 w-12 rounded-md bg-blue-100">
                          <.icon name="hero-arrow-path" class="h-6 w-6 text-blue-600 animate-spin" />
                        </div>
                      </div>
                      <div class="flex-1">
                        <p class="text-sm font-medium text-gray-900 mb-4">
                          Processing job posting...
                        </p>
                        
    <!-- Phase Progress List -->
                        <div class="space-y-2">
                          <%= for phase <- @phases do %>
                            <div class="flex items-center gap-3">
                              <div class="flex-shrink-0">
                                <%= case phase.status do %>
                                  <% :complete -> %>
                                    <.icon name="hero-check-circle" class="w-5 h-5 text-green-600" />
                                  <% :in_progress -> %>
                                    <.icon
                                      name="hero-arrow-path"
                                      class="w-5 h-5 text-blue-600 animate-spin"
                                    />
                                  <% :pending -> %>
                                    <div class="w-5 h-5 rounded-full border-2 border-gray-300"></div>
                                <% end %>
                              </div>
                              <span class="text-xs font-medium text-gray-700">{phase.label}</span>
                            </div>
                          <% end %>
                        </div>

                        <p class="mt-4 text-xs text-gray-500">Using {@llm_provider} provider</p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>

              <div class="bg-blue-50 border border-blue-100 rounded-lg p-4">
                <h3 class="font-medium text-blue-800 mb-2">Supported Job Boards</h3>
                <div class="flex flex-wrap gap-2">
                  <%= for site <- @supported_sites do %>
                    <span class="bg-white px-2 py-1 rounded text-xs text-gray-700">{site}</span>
                  <% end %>
                </div>
                <p class="mt-3 text-xs text-blue-600">
                  We support most major job boards. If your site isn't listed, we'll do our best to extract the information.
                </p>
              </div>
            </div>
          <% end %>
          
    <!-- Step 2: Review Data -->
          <%= if @step == 2 do %>
            <form phx-submit="save_job_interest" class="space-y-6">
              <!-- Provider Info -->
              <div class="bg-gray-50 rounded-lg p-4 flex items-center gap-3">
                <.icon name={get_provider_icon(@llm_provider)} class="w-6 h-6 text-gray-600" />
                <div>
                  <p class="text-sm text-gray-600">Processed using</p>
                  <p class="font-medium text-gray-900">{get_provider_name(@llm_provider)}</p>
                </div>
                <%= if @llm_status == "success" do %>
                  <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded-full ml-auto">
                    Success
                  </span>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Job Posting URL
                </label>
                <input
                  type="url"
                  name="url"
                  value={@scraped_data[:source_url] || @scraped_data[:url] || @url}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  readonly
                />
              </div>

              <div class="grid md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Company Name <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    name="company_name"
                    value={@scraped_data[:company_name] || ""}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    required
                    disabled={@saving}
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Position Title <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    name="position_title"
                    value={@scraped_data[:position_title] || ""}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    required
                    disabled={@saving}
                  />
                </div>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Job Description
                </label>
                <textarea
                  name="job_description"
                  rows="6"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  disabled={@saving}
                ><%= @scraped_data[:job_description] || "" %></textarea>
              </div>

              <div class="grid md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Location
                  </label>
                  <input
                    type="text"
                    name="location"
                    value={extract_location(@scraped_data[:location]) || ""}
                    placeholder="e.g., San Francisco, CA"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    disabled={@saving}
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Work Model
                  </label>
                  <select
                    name="work_model"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    disabled={@saving}
                  >
                    <option value="remote" selected={@scraped_data[:work_model] == "remote"}>
                      Remote
                    </option>
                    <option value="hybrid" selected={@scraped_data[:work_model] == "hybrid"}>
                      Hybrid
                    </option>
                    <option value="on_site" selected={@scraped_data[:work_model] == "on_site"}>
                      On-site
                    </option>
                  </select>
                </div>
              </div>

              <%= if @scraped_data[:salary] && (@scraped_data[:salary][:min] || @scraped_data[:salary][:max]) do %>
                <div class="bg-gray-50 rounded-lg p-4">
                  <h3 class="font-medium text-gray-800 mb-2">Extracted Salary Information</h3>
                  <p class="text-sm text-gray-600">
                    {format_salary(@scraped_data)}
                  </p>
                </div>
              <% end %>
              
    <!-- Loading Indicator during save -->
              <%= if @saving do %>
                <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 flex items-center gap-3">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-arrow-path" class="w-5 h-5 text-blue-600 animate-spin" />
                    <div>
                      <p class="text-sm font-medium text-blue-900">Saving job interest...</p>
                      <p class="text-xs text-blue-600 mt-0.5">
                        This typically takes {div(@estimated_llm_time_ms, 1000)} seconds
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>

              <div class="flex justify-between items-center pt-6 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="back_to_url"
                  class="btn btn-ghost"
                  disabled={@saving}
                >
                  <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back
                </button>

                <button
                  type="submit"
                  class={"btn btn-primary " <> if(@saving, do: "btn-disabled", else: "")}
                  disabled={@saving}
                  phx-disable-with="Saving..."
                >
                  <%= if @saving do %>
                    <.icon name="hero-arrow-path" class="w-4 h-4 mr-2 animate-spin" /> Saving...
                  <% else %>
                    <.icon name="hero-check" class="w-4 h-4 mr-2" /> Save Job Interest
                  <% end %>
                </button>
              </div>
            </form>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp step_class(current, active) do
    cond do
      active > current -> "text-blue-600"
      active == current -> "text-blue-800 font-medium"
      true -> "text-gray-400"
    end
  end

  defp step_color(current, active) do
    cond do
      active > current -> "bg-blue-600 text-white"
      active == current -> "bg-blue-100 text-blue-800 border-2 border-blue-500"
      true -> "bg-gray-200 text-gray-500"
    end
  end

  defp progress_width(step) do
    case step do
      1 -> "w-0"
      2 -> "w-full"
      _ -> "w-full"
    end
  end

  defp extract_location(location) when is_binary(location) do
    # Extract just the location part, removing work model info
    location
    |> String.replace(~r/\([^)]+\)/, "")
    |> String.trim()
  end

  defp extract_location(_), do: ""

  defp format_salary(data) do
    salary = data[:salary]

    cond do
      salary && salary[:min] && salary[:max] ->
        "$#{salary[:min]} - $#{salary[:max]}"

      salary && salary[:min] ->
        "$#{salary[:min]}+"

      salary && salary[:max] ->
        "Up to $#{salary[:max]}"

      true ->
        "Not specified"
    end
  end

  defp get_preferred_provider(user_id, enabled_providers) do
    # Get the user's preferred provider from config, default to first enabled or ollama
    case LLMConfig.get_provider_config(user_id, "preferred_provider") do
      {:ok, %{"provider" => provider}} ->
        provider

      _ ->
        # Default to ollama if available, otherwise first enabled provider
        if Enum.member?(enabled_providers, "ollama") do
          "ollama"
        else
          List.first(enabled_providers, "ollama")
        end
    end
  end

  defp get_estimated_provider_time(provider) do
    case provider do
      # ~2 minutes for Ollama
      "ollama" -> 120_000
      :ollama -> 120_000
      # ~45 seconds for Gemini
      "gemini" -> 45_000
      :gemini -> 45_000
      # ~45 seconds for Google
      "google" -> 45_000
      :google -> 45_000
      # Default to 45 seconds
      _ -> 45_000
    end
  end
end
