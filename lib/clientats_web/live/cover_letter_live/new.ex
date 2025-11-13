defmodule ClientatsWeb.CoverLetterLive.New do
  use ClientatsWeb, :live_view

  alias Clientats.Documents
  alias Clientats.Documents.CoverLetterTemplate

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Documents.change_cover_letter_template(%CoverLetterTemplate{})

    {:ok,
     socket
     |> assign(:page_title, "New Cover Letter Template")
     |> assign(:template, %CoverLetterTemplate{})
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"cover_letter_template" => template_params}, socket) do
    changeset =
      %CoverLetterTemplate{}
      |> Documents.change_cover_letter_template(template_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"cover_letter_template" => template_params}, socket) do
    template_params = Map.put(template_params, "user_id", socket.assigns.current_user.id)

    case Documents.create_cover_letter_template(template_params) do
      {:ok, _template} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cover letter template created successfully")
         |> push_navigate(to: ~p"/dashboard/cover-letters")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4">
          <.link navigate={~p"/dashboard/cover-letters"} class="text-blue-600 hover:text-blue-800">
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Templates
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-3xl">
        <div class="bg-white rounded-lg shadow p-6">
          <div class="mb-6">
            <h2 class="text-2xl font-bold text-gray-900">New Cover Letter Template</h2>
            <p class="text-sm text-gray-600 mt-1">Create a reusable cover letter template</p>
          </div>

          <.form
            for={@form}
            id="template-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-4"
          >
            <.input
              field={@form[:name]}
              type="text"
              label="Template Name"
              placeholder="e.g., General Software Engineer"
              required
            />

            <.input
              field={@form[:description]}
              type="textarea"
              label="Description (Optional)"
              placeholder="e.g., For mid-level backend positions"
              rows="2"
            />

            <.input
              field={@form[:content]}
              type="textarea"
              label="Cover Letter Content"
              placeholder="Dear Hiring Manager,&#10;&#10;I am writing to express my interest in..."
              rows="15"
              required
            />

            <div class="p-4 bg-blue-50 rounded-lg">
              <p class="text-sm text-blue-800">
                <strong>Tip:</strong>
                You can use placeholders like &#123;company_name&#125;, &#123;position_title&#125;, etc. to customize this template for specific applications.
              </p>
            </div>

            <.input field={@form[:is_default]} type="checkbox" label="Set as default template" />

            <div>
              <.button phx-disable-with="Saving..." class="w-full">Create Template</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
