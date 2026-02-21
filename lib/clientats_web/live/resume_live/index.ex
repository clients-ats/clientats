defmodule ClientatsWeb.ResumeLive.Index do
  use ClientatsWeb, :live_view

  alias Clientats.Documents
  alias Clientats.LLMConfig
  alias Clientats.ResumeParser

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    enabled_providers = LLMConfig.get_enabled_providers(user_id)

    {:ok,
     socket
     |> assign(:page_title, "My Resumes")
     |> assign(:resumes, Documents.list_resumes(user_id))
     |> assign(:llm_available, length(enabled_providers) > 0)
     |> assign(:parsing_resume_id, nil)
     |> assign(:parse_phase, nil)
     |> assign(:parse_result, nil)
     |> assign(:parse_error, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    resume = Documents.get_resume!(id)
    {:ok, _} = Documents.delete_resume(resume)

    {:noreply,
     socket
     |> put_flash(:info, "Resume deleted successfully")
     |> assign(:resumes, Documents.list_resumes(socket.assigns.current_user.id))}
  end

  def handle_event("set_default", %{"id" => id}, socket) do
    resume = Documents.get_resume!(id)
    {:ok, _} = Documents.set_default_resume(resume)

    {:noreply,
     socket
     |> put_flash(:info, "Default resume updated")
     |> assign(:resumes, Documents.list_resumes(socket.assigns.current_user.id))}
  end

  def handle_event("parse_resume", %{"id" => id}, socket) do
    resume_id = String.to_integer(id)
    user_id = socket.assigns.current_user.id
    liveview_pid = self()

    socket =
      socket
      |> assign(:parsing_resume_id, resume_id)
      |> assign(:parse_phase, :extracting)
      |> assign(:parse_result, nil)
      |> assign(:parse_error, nil)

    # Determine provider
    enabled_providers = LLMConfig.get_enabled_providers(user_id)

    provider =
      cond do
        :ollama in enabled_providers -> :ollama
        :gemini in enabled_providers -> :gemini
        true -> :ollama
      end

    start_async(socket, :parse_resume, fn ->
      resume = Documents.get_resume!(resume_id)

      # Phase 1: Extract text
      send(liveview_pid, {:parse_phase, :extracting})

      case Documents.extract_resume_text(resume) do
        {:ok, text} when byte_size(text) > 50 ->
          # Phase 2: Parse with LLM
          send(liveview_pid, {:parse_phase, :analyzing})

          case ResumeParser.parse(text, provider: provider, user_id: user_id) do
            {:ok, parsed} ->
              # Phase 3: Bootstrap preferences
              send(liveview_pid, {:parse_phase, :setting_prefs})
              prefs_result = ResumeParser.bootstrap_preferences(user_id, parsed)

              case prefs_result do
                {:ok, count} -> {:ok, parsed, count}
                {:error, errors} -> {:error, "Failed to set some preferences: #{inspect(errors)}"}
              end

            {:error, :insufficient_data} ->
              {:error, "Resume doesn't contain enough data to extract preferences."}

            {:error, reason} ->
              {:error, "AI analysis failed: #{format_parse_error(reason)}"}
          end

        {:ok, _text} ->
          {:error, "Resume text is too short to extract meaningful data."}

        {:error, :invalid_resume} ->
          {:error, "This resume file is invalid or corrupted."}

        {:error, :file_not_found} ->
          {:error, "Resume file could not be found."}

        {:error, :unsupported_format} ->
          {:error, "Only PDF and TXT resumes can be parsed."}

        {:error, reason} ->
          {:error, "Failed to extract text: #{inspect(reason)}"}
      end
    end)

    {:noreply, socket}
  end

  def handle_event("dismiss_parse_result", _params, socket) do
    {:noreply,
     socket
     |> assign(:parse_result, nil)
     |> assign(:parse_error, nil)
     |> assign(:parsing_resume_id, nil)}
  end

  @impl true
  def handle_info({:parse_phase, phase}, socket) do
    {:noreply, assign(socket, :parse_phase, phase)}
  end

  @impl true
  def handle_async(:parse_resume, {:ok, {:ok, parsed, pref_count}}, socket) do
    {:noreply,
     socket
     |> assign(:parsing_resume_id, nil)
     |> assign(:parse_phase, nil)
     |> assign(:parse_result, %{parsed: parsed, pref_count: pref_count})}
  end

  def handle_async(:parse_resume, {:ok, {:error, message}}, socket) do
    {:noreply,
     socket
     |> assign(:parsing_resume_id, nil)
     |> assign(:parse_phase, nil)
     |> assign(:parse_error, message)}
  end

  def handle_async(:parse_resume, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:parsing_resume_id, nil)
     |> assign(:parse_phase, nil)
     |> assign(:parse_error, "Resume parsing crashed: #{inspect(reason)}")}
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
          <.link navigate={~p"/dashboard/resumes/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="w-5 h-5" /> Upload Resume
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-gray-900">My Resumes</h1>
          <p class="text-sm text-gray-600 mt-1">Manage your resume versions</p>
        </div>

        <%!-- Parse result success panel --%>
        <%= if @parse_result do %>
          <div class="bg-green-50 border border-green-200 rounded-lg p-6 mb-6">
            <div class="flex justify-between items-start mb-4">
              <div>
                <h3 class="text-lg font-semibold text-green-800">Resume Parsed Successfully</h3>
                <p class="text-sm text-green-600">
                  {format_pref_count(@parse_result.pref_count)} set from your resume.
                </p>
              </div>
              <button phx-click="dismiss_parse_result" class="text-green-400 hover:text-green-600">
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= if @parse_result.parsed.current_title do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Current Title</span>
                  <p class="text-sm text-gray-900">{@parse_result.parsed.current_title}</p>
                </div>
              <% end %>
              <%= if @parse_result.parsed.target_titles != [] do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Target Roles</span>
                  <div class="flex flex-wrap gap-1 mt-1">
                    <%= for title <- @parse_result.parsed.target_titles do %>
                      <span class="px-2 py-0.5 text-xs bg-blue-100 text-blue-700 rounded-full">{title}</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%= if @parse_result.parsed.skills_primary != [] do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Primary Skills</span>
                  <div class="flex flex-wrap gap-1 mt-1">
                    <%= for skill <- @parse_result.parsed.skills_primary do %>
                      <span class="px-2 py-0.5 text-xs bg-indigo-100 text-indigo-700 rounded-full">{skill}</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%= if @parse_result.parsed.skills_secondary != [] do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Secondary Skills</span>
                  <div class="flex flex-wrap gap-1 mt-1">
                    <%= for skill <- @parse_result.parsed.skills_secondary do %>
                      <span class="px-2 py-0.5 text-xs bg-gray-100 text-gray-700 rounded-full">{skill}</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%= if @parse_result.parsed.seniority_level do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Seniority</span>
                  <p class="text-sm text-gray-900">{String.capitalize(@parse_result.parsed.seniority_level)}</p>
                </div>
              <% end %>
              <%= if @parse_result.parsed.industries != [] do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Industries</span>
                  <div class="flex flex-wrap gap-1 mt-1">
                    <%= for industry <- @parse_result.parsed.industries do %>
                      <span class="px-2 py-0.5 text-xs bg-green-100 text-green-700 rounded-full">{format_industry(industry)}</span>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%= if @parse_result.parsed.years_experience do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Experience</span>
                  <p class="text-sm text-gray-900">{@parse_result.parsed.years_experience} years</p>
                </div>
              <% end %>
              <%= if @parse_result.parsed.preferred_work_model do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Work Model</span>
                  <p class="text-sm text-gray-900">{String.capitalize(@parse_result.parsed.preferred_work_model)}</p>
                </div>
              <% end %>
              <%= if @parse_result.parsed.education != [] do %>
                <div>
                  <span class="text-xs font-medium text-gray-500 uppercase">Education</span>
                  <%= for edu <- @parse_result.parsed.education do %>
                    <p class="text-sm text-gray-900">
                      {edu.degree}<%= if edu.field do %> in {edu.field}<% end %>
                    </p>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div class="mt-4 pt-3 border-t border-green-200">
              <span class="text-sm text-green-600">
                Preferences will be used to improve job matching.
              </span>
            </div>
          </div>
        <% end %>

        <%!-- Parse error panel --%>
        <%= if @parse_error do %>
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
            <div class="flex justify-between items-start">
              <div class="flex gap-2">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5" />
                <p class="text-sm text-red-700">{@parse_error}</p>
              </div>
              <button phx-click="dismiss_parse_result" class="text-red-400 hover:text-red-600">
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>
          </div>
        <% end %>

        <%= if @resumes == [] do %>
          <div class="bg-white rounded-lg shadow p-12 text-center">
            <.icon name="hero-document-text" class="w-16 h-16 mx-auto text-gray-400 mb-4" />
            <p class="text-gray-500 mb-4">No resumes uploaded yet</p>
            <.link navigate={~p"/dashboard/resumes/new"} class="btn btn-primary">
              Upload Your First Resume
            </.link>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for resume <- @resumes do %>
              <div class="bg-white rounded-lg shadow p-6">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-2">
                      <h3 class="text-lg font-semibold text-gray-900">{resume.name}</h3>
                      <%= if resume.is_default do %>
                        <span class="badge badge-primary badge-sm">Default</span>
                      <% end %>
                      <%= if !resume.is_valid do %>
                        <span class="badge badge-error badge-sm">Invalid File</span>
                      <% end %>
                    </div>
                    <%= if !resume.is_valid do %>
                      <p class="text-sm text-red-600 mt-1">
                        <.icon name="hero-exclamation-triangle" class="w-4 h-4 inline" />
                        The original file for this resume could not be found or read.
                      </p>
                    <% end %>
                    <%= if resume.description do %>
                      <p class="text-sm text-gray-600 mt-1">{resume.description}</p>
                    <% end %>
                    <div class="flex items-center gap-4 mt-2 text-sm text-gray-500">
                      <span>{resume.original_filename}</span>
                      <%= if resume.file_size do %>
                        <span>{format_file_size(resume.file_size)}</span>
                      <% end %>
                      <span>Uploaded {Calendar.strftime(resume.inserted_at, "%b %d, %Y")}</span>
                    </div>

                    <%!-- Parsing progress indicator --%>
                    <%= if @parsing_resume_id == resume.id do %>
                      <div class="mt-3 flex items-center gap-2 text-sm text-blue-600">
                        <span class="loading loading-spinner loading-xs"></span>
                        <span>{phase_label(@parse_phase)}</span>
                      </div>
                    <% end %>
                  </div>
                  <div class="flex gap-2">
                    <%= if @llm_available && resume.is_valid && @parsing_resume_id != resume.id do %>
                      <.button
                        phx-click="parse_resume"
                        phx-value-id={resume.id}
                        class="btn btn-sm btn-accent"
                        title="Extract career data and set matching preferences"
                      >
                        <.icon name="hero-sparkles" class="w-4 h-4" /> Parse & Set Preferences
                      </.button>
                    <% end %>
                    <%= if !resume.is_default && resume.is_valid do %>
                      <.button
                        phx-click="set_default"
                        phx-value-id={resume.id}
                        class="btn btn-sm btn-outline"
                      >
                        Set as Default
                      </.button>
                    <% end %>
                    <%= if resume.is_valid do %>
                      <.link
                        href={~p"/dashboard/resumes/#{resume}/download"}
                        class="btn btn-sm btn-outline"
                      >
                        Download
                      </.link>
                    <% else %>
                      <button class="btn btn-sm btn-outline" disabled title="File missing">
                        Download
                      </button>
                    <% end %>
                    <.link navigate={~p"/dashboard/resumes/#{resume}/edit"} class="btn btn-sm">
                      Edit
                    </.link>
                    <.button
                      phx-click="delete"
                      phx-value-id={resume.id}
                      data-confirm="Are you sure you want to delete this resume?"
                      class="btn btn-sm btn-error"
                    >
                      Delete
                    </.button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_file_size(bytes),
    do: "#{Float.round(bytes / 1024 / 1024, 1)} MB"

  defp phase_label(:extracting), do: "Extracting text from PDF..."
  defp phase_label(:analyzing), do: "Analyzing resume with AI..."
  defp phase_label(:setting_prefs), do: "Setting preferences..."
  defp phase_label(_), do: "Processing..."

  defp format_pref_count(1), do: "1 preference category was"
  defp format_pref_count(n), do: "#{n} preference categories were"

  defp format_industry(industry) do
    industry
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_parse_error({:json_parse_error, _}), do: "Failed to parse AI response"
  defp format_parse_error({:http_error, status}), do: "HTTP error #{status}"
  defp format_parse_error({:http_error, status, _}), do: "HTTP error #{status}"
  defp format_parse_error({:timeout, _}), do: "AI request timed out, please try again"
  defp format_parse_error({:transport_error, msg}), do: "Connection error: #{msg}"
  defp format_parse_error({:exception, msg}), do: msg
  defp format_parse_error(:missing_api_key), do: "API key not configured"
  defp format_parse_error(other), do: inspect(other)
end
