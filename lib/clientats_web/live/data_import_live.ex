defmodule ClientatsWeb.DataImportLive do
  use ClientatsWeb, :live_view

  alias Clientats.DataExport

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Data")
     |> assign(:import_result, nil)
     |> allow_upload(:import_file,
       accept: ~w(.json),
       max_entries: 1,
       max_file_size: 50_000_000
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :import_file, ref)}
  end

  def handle_event("import", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :import_file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case uploaded_files do
      [file_content] ->
        case Jason.decode(file_content) do
          {:ok, data} ->
            case DataExport.import_user_data(socket.assigns.current_user.id, data) do
              {:ok, stats} ->
                {:noreply,
                 socket
                 |> assign(:import_result, {:success, stats})
                 |> put_flash(:info, "Data imported successfully!")}

              {:error, reason} ->
                {:noreply,
                 socket
                 |> assign(:import_result, {:error, reason})
                 |> put_flash(:error, "Import failed: #{reason}")}
            end

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:import_result, {:error, "Invalid JSON file"})
             |> put_flash(:error, "Invalid JSON file")}
        end

      [] ->
        {:noreply,
         socket
         |> assign(:import_result, {:error, "Please select a file to import"})
         |> put_flash(:error, "Please select a file to import")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4">
          <.link navigate={~p"/"} class="text-blue-600 hover:text-blue-800">
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Home
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-2xl">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Import Data</h2>
            <p class="text-sm text-gray-600 mt-1">
              Import your Clientats data from a JSON file (max 50MB)
            </p>
          </div>

          <%= if @import_result do %>
            <div class="mb-6">
              <%= case @import_result do %>
                <% {:success, stats} -> %>
                  <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                    <h3 class="text-green-800 font-semibold mb-2">Import Successful!</h3>
                    <div class="text-sm text-green-700 space-y-1">
                      <p>Job Interests: {stats.job_interests}</p>
                      <p>Job Applications: {stats.job_applications}</p>
                      <p>Application Events: {stats.application_events}</p>
                      <p>Resumes: {stats.resumes}</p>
                      <p>Cover Letter Templates: {stats.cover_letter_templates}</p>
                    </div>
                    <div class="mt-4">
                      <.link
                        navigate={~p"/dashboard"}
                        class="text-green-800 font-semibold hover:underline"
                      >
                        Go to Dashboard →
                      </.link>
                    </div>
                  </div>
                <% {:error, reason} -> %>
                  <div class="bg-red-50 border border-red-200 rounded-lg p-4">
                    <h3 class="text-red-800 font-semibold mb-2">Import Failed</h3>
                    <p class="text-sm text-red-700">{reason}</p>
                  </div>
              <% end %>
            </div>
          <% end %>

          <.form
            for={%{}}
            id="import-form"
            phx-change="validate"
            phx-submit="import"
            class="space-y-4"
          >
            <div>
              <label class="label">
                <span class="label-text font-medium">Import File *</span>
              </label>
              <div class="mt-1">
                <div
                  class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-blue-500 transition-colors"
                  phx-drop-target={@uploads.import_file.ref}
                >
                  <.icon name="hero-arrow-up-tray" class="w-12 h-12 mx-auto text-gray-400 mb-2" />
                  <div class="text-sm text-gray-600 mb-2">
                    Drag and drop your JSON file here, or click to browse
                  </div>
                  <.live_file_input upload={@uploads.import_file} class="hidden" />
                  <label for={@uploads.import_file.ref} class="btn btn-sm btn-outline cursor-pointer">
                    Choose File
                  </label>
                  <p class="text-xs text-gray-500 mt-2">JSON files up to 50MB</p>
                </div>

                <%= for entry <- @uploads.import_file.entries do %>
                  <div class="mt-4 p-4 bg-gray-50 rounded-lg">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <.icon name="hero-document" class="w-6 h-6 text-blue-600" />
                        <div>
                          <p class="text-sm font-medium text-gray-900">{entry.client_name}</p>
                          <p class="text-xs text-gray-500">
                            {Float.round(entry.client_size / 1024 / 1024, 2)} MB
                          </p>
                        </div>
                      </div>
                      <button
                        type="button"
                        phx-click="cancel-upload"
                        phx-value-ref={entry.ref}
                        class="text-red-600 hover:text-red-800"
                      >
                        <.icon name="hero-x-mark" class="w-5 h-5" />
                      </button>
                    </div>
                    <div class="mt-2">
                      <div class="w-full bg-gray-200 rounded-full h-2">
                        <div
                          class="bg-blue-600 h-2 rounded-full transition-all"
                          style={"width: #{entry.progress}%"}
                        >
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>

                <%= for err <- upload_errors(@uploads.import_file) do %>
                  <p class="text-sm text-red-600 mt-2">{error_to_string(err)}</p>
                <% end %>
              </div>
            </div>

            <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <div class="flex">
                <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-yellow-600 mr-2" />
                <div class="text-sm text-yellow-800">
                  <p class="font-semibold">Important:</p>
                  <ul class="list-disc list-inside mt-1 space-y-1">
                    <li>Imported data will be added to your existing data</li>
                    <li>This operation cannot be undone</li>
                    <li>Resume file paths will be imported as metadata only</li>
                  </ul>
                </div>
              </div>
            </div>

            <div>
              <.button phx-disable-with="Importing..." class="w-full">Import Data</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 50MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted (JSON only)"
  defp error_to_string(:too_many_files), do: "Too many files (max 1)"
end
