defmodule ClientatsWeb.JobInterestLive.Scrape do
  use ClientatsWeb, :live_view

  alias Clientats.LLM.Service
  alias Clientats.Jobs

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    providers = get_llm_providers()

    {:ok,
     socket
     |> assign(:page_title, "Import Job from URL")
     |> assign(:step, 1)
     |> assign(:url, "")
     |> assign(:scraping, false)
     |> assign(:scraped_data, %{})
     |> assign(:error, nil)
     |> assign(:llm_provider, "ollama")
     |> assign(:llm_providers, providers)
     |> assign(:llm_status, nil)
     |> assign(:show_provider_settings, true)
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

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_url", %{"url" => url}, socket) do
    {:noreply, socket |> assign(:url, url) |> assign(:error, nil)}
  end

  def handle_event("update_url", params, socket) do
    {:noreply, socket}
  end

  def handle_event("update_provider", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, :llm_provider, provider)}
  end

  def handle_event("toggle_provider_settings", _params, socket) do
    {:noreply, assign(socket, :show_provider_settings, !socket.assigns.show_provider_settings)}
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
    job_interest_params = %{
      user_id: socket.assigns.current_user.id,
      company_name: params["company_name"] || "",
      position_title: params["position_title"] || "",
      job_description: params["job_description"] || "",
      job_url: params["url"] || socket.assigns.url,
      location: params["location"] || "",
      work_model: params["work_model"] || "remote",
      status: "interested",
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
         |> assign(:error, "Failed to create job interest. Please check the form.")}
    end
  end

  def handle_event("back_to_url", _params, socket) do
    {:noreply, socket |> assign(:step, 1) |> assign(:error, nil)}
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
       |> assign(:error, "Ollama server is not available. Please start Ollama or select another provider.")}
    else
      {:noreply, socket}  # Already handled, do nothing
    end
  end

  def handle_info(:scrape_result, %{result: result}, socket) do
    case result do
      {:ok, data} ->
        {:noreply, 
         socket
         |> assign(:scraping, false)
         |> assign(:scraped_data, data)
         |> assign(:step, 2)
         |> assign(:llm_status, "success")}
      
      {:error, reason} ->
        {:noreply, 
         socket
         |> assign(:scraping, false)
         |> assign(:error, "Scraping failed: #{reason}")
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
    spawn(fn ->
      case Clientats.LLM.Providers.Ollama.ping() do
        {:ok, :available} -> send(self(), :ollama_available)
        {:error, :unavailable} -> send(self(), :ollama_unavailable)
      end
    end)
    
    # Set a timeout to prevent hanging
    Process.send_after(self(), :ollama_unavailable, 5000)
    
    {:noreply, assign(socket, :llm_status, "checking")}
  end

  defp start_scraping(url, provider, socket) do
    # Parse provider
    llm_provider = 
      case provider do
        "auto" -> nil
        "ollama" -> :ollama
        "openai" -> :openai
        "anthropic" -> :anthropic
        "mistral" -> :mistral
        _ -> nil
      end
    
    # Start scraping process
    {:noreply, 
     socket
     |> assign(:scraping, true)
     |> assign(:error, nil)
     |> assign(:llm_status, "processing")}
    
    # Spawn scraping process
    spawn(fn ->
      result = 
        case llm_provider do
          :ollama ->
            Service.extract_job_data_from_url(url, :generic, provider: :ollama)
          _ ->
            Service.extract_job_data_from_url(url, :generic, provider: llm_provider)
        end
      
      send(self(), {:scrape_result, %{result: result}})
    end)
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
            <p class="text-sm text-gray-600 mt-1">Paste a job posting URL to automatically extract details</p>
          </div>

          <!-- Provider Selection -->
          <div class="mb-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="font-medium text-gray-900">LLM Provider</h3>
                <p class="text-sm text-gray-600">Choose how to process the job posting</p>
              </div>
              <button
                phx-click="toggle_provider_settings"
                class="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1"
              >
                <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                <%= if @show_provider_settings, do: "Hide Settings", else: "Show Settings" %>
              </button>
            </div>
            
            <%= if @show_provider_settings do %>
              <div class="mt-4 grid grid-cols-1 md:grid-cols-2 gap-4">
                <%= for provider <- @llm_providers do %>
                  <label class={"flex items-start gap-3 p-3 border rounded-lg cursor-pointer hover:bg-white transition-colors " <> 
                          if(provider.id == @llm_provider, do: "border-blue-300 bg-blue-50", else: "border-gray-200")}>
                    <input
                      type="radio"
                      name="llm_provider"
                      value={provider.id}
                      phx-click="update_provider"
                      phx-value-provider={provider.id}
                      class="mt-1"
                      checked={provider.id == @llm_provider}
                    />
                    <div class="flex-1">
                      <div class="flex items-center gap-2">
                        <.icon name={provider.icon} class="w-5 h-5 text-gray-600" />
                        <span class="font-medium text-gray-900"><%= provider.name %></span>
                        <%= if Map.get(provider, :local) do %>
                          <span class="text-xs bg-green-100 text-green-800 px-2 py-0.5 rounded-full">Local</span>
                        <% end %>
                      </div>
                      <p class="text-sm text-gray-500 mt-1"><%= provider.description %></p>
                    </div>
                  </label>
                <% end %>
              </div>
              
              <!-- Ollama Status -->
              <%= if @llm_provider == "ollama" && @llm_status do %>
                <div class="mt-4 p-3 rounded-md flex items-center gap-2" class={"bg-yellow-50 border border-yellow-200 text-yellow-800" <> 
                        if(@llm_status == "success", do: "bg-green-50 border border-green-200 text-green-800", else: "")}>
                  <.icon name={"hero-exclamation-triangle" <> if(@llm_status == "success", do: "hero-check-circle", else: "")} class="w-5 h-5" />
                  <span class="text-sm">
                    <%= 
                      case @llm_status do
                        "checking" -> "Checking Ollama server..."
                        "success" -> "Ollama is ready!"
                        "error" -> "Ollama encountered an error"
                        "unavailable" -> "Ollama server is not available"
                        _ -> "Status: " <> @llm_status
                      end
                    %>
                  </span>
                </div>
              <% end %>
            <% end %>
          </div>

          <!-- Progress Steps -->
          <div class="mb-8">
            <div class="flex items-center justify-between">
              <div class={"flex items-center gap-2 " <> step_class(1, @step)}>
                <div class={"w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold " <> step_color(1, @step)}>
                  <%= if @step > 1, do: "✓", else: "1" %>
                </div>
                <span class="text-sm hidden sm:inline">Enter URL</span>
              </div>
              
              <div class="flex-1 h-0.5 bg-gray-200 mx-2">
                <div class={"h-full bg-blue-500 transition-all" <> progress_width(@step)}></div>
              </div>
              
              <div class={"flex items-center gap-2 " <> step_class(2, @step)}>
                <div class={"w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold " <> step_color(2, @step)}>
                  <%= if @step > 2, do: "✓", else: "2" %>
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
                      <%= if @scraping, do: "Processing...", else: "Import" %>
                    </button>
                  </div>
                </form>
                <%= if @error do %>
                  <p class="mt-2 text-sm text-red-600"><%= @error %></p>
                <% end %>
              </div>

              <div class="bg-blue-50 border border-blue-100 rounded-lg p-4">
                <h3 class="font-medium text-blue-800 mb-2">Supported Job Boards</h3>
                <div class="flex flex-wrap gap-2">
                  <%= for site <- @supported_sites do %>
                    <span class="bg-white px-2 py-1 rounded text-xs text-gray-700"><%= site %></span>
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
            <div class="space-y-6">
              <!-- Provider Info -->
              <div class="bg-gray-50 rounded-lg p-4 flex items-center gap-3">
                <.icon name={get_provider_icon(@llm_provider)} class="w-6 h-6 text-gray-600" />
                <div>
                  <p class="text-sm text-gray-600">Processed using</p>
                  <p class="font-medium text-gray-900"><%= get_provider_name(@llm_provider) %></p>
                </div>
                <%= if @llm_status == "success" do %>
                  <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded-full ml-auto">Success</span>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Job Posting URL
                </label>
                <input
                  type="url"
                  name="url"
                  value={@scraped_data.url || @url}
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
                    value={@scraped_data.company_name || ""}
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
                    value={@scraped_data.position_title || ""}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    required
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
                ><%= @scraped_data.job_description || "" %></textarea>
              </div>

              <div class="grid md:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Location
                  </label>
                  <input
                    type="text"
                    name="location"
                    value={extract_location(@scraped_data.location) || ""}
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
                    <option value="remote" selected={@scraped_data.work_model == "remote"}>Remote</option>
                    <option value="hybrid" selected={@scraped_data.work_model == "hybrid"}>Hybrid</option>
                    <option value="on_site" selected={@scraped_data.work_model == "on_site"}>On-site</option>
                  </select>
                </div>
              </div>

              <%= if @scraped_data.salary_min || @scraped_data.salary_max do %>
                <div class="bg-gray-50 rounded-lg p-4">
                  <h3 class="font-medium text-gray-800 mb-2">Extracted Salary Information</h3>
                  <p class="text-sm text-gray-600">
                    <%= format_salary(@scraped_data) %>
                  </p>
                </div>
              <% end %>

              <div class="flex justify-between items-center pt-6 border-t border-gray-200">
                <button
                  type="button"
                  phx-click="back_to_url"
                  class="btn btn-ghost"
                >
                  <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" />
                  Back
                </button>
                
                <button
                  type="submit"
                  phx-click="save_job_interest"
                  form="job-interest-form"
                  class="btn btn-primary"
                >
                  <.icon name="hero-check" class="w-4 h-4 mr-2" />
                  Save Job Interest
                </button>
              </div>
            </div>
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
    cond do
      data.salary_min && data.salary_max ->
        "$#{data.salary_min} - $#{data.salary_max}"
      data.salary_min ->
        "$#{data.salary_min}+"
      data.salary_max ->
        "Up to $#{data.salary_max}"
      true ->
        "Not specified"
    end
  end
end