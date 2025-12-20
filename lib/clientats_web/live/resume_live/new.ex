defmodule ClientatsWeb.ResumeLive.New do
  use ClientatsWeb, :live_view

  alias Clientats.Documents
  alias Clientats.Documents.Resume

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Documents.change_resume(%Resume{})

    {:ok,
     socket
     |> assign(:page_title, "Upload Resume")
     |> assign(:resume, %Resume{})
     |> assign(:form, to_form(changeset))
     |> allow_upload(:resume_file,
       accept: ~w(.pdf .doc .docx),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def handle_event("validate", %{"resume" => resume_params}, socket) do
    changeset =
      %Resume{}
      |> Documents.change_resume(resume_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"resume" => resume_params}, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :resume_file, fn %{path: path}, entry ->
        dest = Path.join(["priv", "static", "uploads", "resumes", "#{entry.uuid}.#{ext(entry)}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/resumes/#{entry.uuid}.#{ext(entry)}"}
      end)

    case uploaded_files do
      [file_path] ->
        [entry] = socket.assigns.uploads.resume_file.entries

        resume_params =
          resume_params
          |> Map.put("user_id", socket.assigns.current_user.id)
          |> Map.put("file_path", file_path)
          |> Map.put("original_filename", entry.client_name)
          |> Map.put("file_size", entry.client_size)

        case Documents.create_resume(resume_params) do
          {:ok, _resume} ->
            {:noreply,
             socket
             |> put_flash(:info, "Resume uploaded successfully")
             |> push_navigate(to: ~p"/dashboard/resumes")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      [] ->
        {:noreply, put_flash(socket, :error, "Please select a file to upload")}
    end
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4">
          <.link navigate={~p"/dashboard/resumes"} class="text-blue-600 hover:text-blue-800">
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Resumes
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-2xl">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Upload Resume</h2>
            <p class="text-sm text-gray-600 mt-1">
              Upload a new resume version (PDF, DOC, DOCX - max 5MB)
            </p>
          </div>

          <.form
            for={@form}
            id="resume-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Resume Name"
              placeholder="e.g., Software Engineer 2024"
              required
            />

            <.input
              field={@form[:description]}
              type="textarea"
              label="Description (Optional)"
              placeholder="e.g., Tailored for backend positions"
              rows="2"
            />

            <div>
              <label class="label">
                <span class="label-text font-medium">Resume File *</span>
              </label>
              <div class="mt-1">
                <div
                  class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-blue-500 transition-colors"
                  phx-drop-target={@uploads.resume_file.ref}
                >
                  <.icon name="hero-document-arrow-up" class="w-12 h-12 mx-auto text-gray-400 mb-2" />
                  <div class="text-sm text-gray-600 mb-2">
                    Drag and drop your resume here, or click to browse
                  </div>
                  <.live_file_input upload={@uploads.resume_file} class="hidden" />
                  <label for={@uploads.resume_file.ref} class="btn btn-sm btn-outline cursor-pointer">
                    Choose File
                  </label>
                  <p class="text-xs text-gray-500 mt-2">PDF, DOC, or DOCX up to 5MB</p>
                </div>

                <%= for entry <- @uploads.resume_file.entries do %>
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

                <%= for err <- upload_errors(@uploads.resume_file) do %>
                  <p class="text-sm text-red-600 mt-2">{error_to_string(err)}</p>
                <% end %>
              </div>
            </div>

            <.input
              field={@form[:is_default]}
              type="checkbox"
              label="Set as default resume"
            />

            <div>
              <.button phx-disable-with="Uploading..." class="w-full">Upload Resume</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted (PDF, DOC, DOCX only)"
  defp error_to_string(:too_many_files), do: "Too many files (max 1)"
end
