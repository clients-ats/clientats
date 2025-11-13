defmodule ClientatsWeb.JobInterestLive.FormComponent do
  use ClientatsWeb, :live_component

  alias Clientats.Jobs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-6">
        <h2 class="text-2xl font-bold text-gray-900"><%= @title %></h2>
        <p class="text-sm text-gray-600 mt-1">Track jobs you're interested in applying to</p>
      </div>

      <.form
        for={@form}
        id="job-interest-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <.input field={@form[:company_name]} type="text" label="Company Name" required />
        <.input field={@form[:position_title]} type="text" label="Position Title" required />
        <.input field={@form[:job_url]} type="url" label="Job Posting URL" placeholder="https://..." />

        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:location]} type="text" label="Location" placeholder="Remote, City, etc." />
          <.input
            field={@form[:work_model]}
            type="select"
            label="Work Model"
            prompt="Choose work model"
            options={[{"Remote", "remote"}, {"Hybrid", "hybrid"}, {"On-site", "on_site"}]}
          />
        </div>

        <.input field={@form[:job_description]} type="textarea" label="Job Description" rows="4" />

        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:salary_min]}
            type="number"
            label="Minimum Salary"
            placeholder="50000"
          />
          <.input
            field={@form[:salary_max]}
            type="number"
            label="Maximum Salary"
            placeholder="80000"
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <.input
            field={@form[:status]}
            type="select"
            label="Status"
            options={[
              {"Interested", "interested"},
              {"Researching", "researching"},
              {"Not a Fit", "not_a_fit"},
              {"Ready to Apply", "ready_to_apply"},
              {"Applied", "applied"}
            ]}
          />
          <.input
            field={@form[:priority]}
            type="select"
            label="Priority"
            options={[{"High", "high"}, {"Medium", "medium"}, {"Low", "low"}]}
          />
        </div>

        <.input field={@form[:notes]} type="textarea" label="Notes" rows="3" />

        <div>
          <.button phx-disable-with="Saving..." class="w-full">Save Job Interest</.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{job_interest: job_interest} = assigns, socket) do
    changeset = Jobs.change_job_interest(job_interest)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"job_interest" => job_interest_params}, socket) do
    changeset =
      socket.assigns.job_interest
      |> Jobs.change_job_interest(job_interest_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"job_interest" => job_interest_params}, socket) do
    save_job_interest(socket, socket.assigns.action, job_interest_params)
  end

  defp save_job_interest(socket, :edit, job_interest_params) do
    case Jobs.update_job_interest(socket.assigns.job_interest, job_interest_params) do
      {:ok, job_interest} ->
        notify_parent({:saved, job_interest})

        {:noreply,
         socket
         |> put_flash(:info, "Job interest updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_job_interest(socket, :new, job_interest_params) do
    job_interest_params = Map.put(job_interest_params, "user_id", socket.assigns.current_user.id)

    case Jobs.create_job_interest(job_interest_params) do
      {:ok, job_interest} ->
        notify_parent({:saved, job_interest})

        {:noreply,
         socket
         |> put_flash(:info, "Job interest created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
