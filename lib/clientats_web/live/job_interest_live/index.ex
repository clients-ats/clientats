defmodule ClientatsWeb.JobInterestLive.Index do
  use ClientatsWeb, :live_view

  alias Clientats.Jobs
  alias Clientats.Jobs.JobInterest

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :job_interests, Jobs.list_job_interests(socket.assigns.current_user.id))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Job Interest")
    |> assign(:job_interest, Jobs.get_job_interest!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Job Interest")
    |> assign(:job_interest, %JobInterest{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Job Interests")
    |> assign(:job_interest, nil)
  end

  @impl true
  def handle_info({ClientatsWeb.JobInterestLive.FormComponent, {:saved, job_interest}}, socket) do
    {:noreply, stream_insert(socket, :job_interests, job_interest)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    job_interest = Jobs.get_job_interest!(id)
    {:ok, _} = Jobs.delete_job_interest(job_interest)

    {:noreply, stream_delete(socket, :job_interests, job_interest)}
  end
end
