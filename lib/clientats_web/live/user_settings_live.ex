defmodule ClientatsWeb.UserSettingsLive do
  use ClientatsWeb, :live_view

  alias Clientats.Accounts
  alias Clientats.LLMConfig

  on_mount {ClientatsWeb.UserAuth, :ensure_authenticated}

  @impl true
  def mount(_params, session, socket) do
    user = Accounts.get_user!(session["user_id"])

    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:current_user, user)
     |> assign(:active_tab, "profile")
     |> assign(:profile_form, to_form(Accounts.change_user_profile(user)))
     |> assign(:password_form, to_form(Accounts.change_user_password(user)))
     |> assign(:llm_form, to_form(Accounts.change_user_llm_provider(user)))
     |> assign(:llm_providers, get_configured_providers(user))
     |> assign(:password_error, nil)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :profile_form, to_form(changeset))}
  end

  def handle_event("save_profile", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:profile_form, to_form(Accounts.change_user_profile(user)))
         |> put_flash(:info, "Profile updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  def handle_event("validate_password", %{"password_change" => _params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save_password", %{"password_change" => params}, socket) do
    current_password = params["current_password"] || ""

    case Accounts.update_user_password(
           socket.assigns.current_user,
           current_password,
           params
         ) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(
           :password_form,
           to_form(Accounts.change_user_password(socket.assigns.current_user))
         )
         |> assign(:password_error, nil)
         |> put_flash(:info, "Password updated successfully")}

      {:error, :invalid_current_password} ->
        {:noreply,
         socket
         |> assign(:password_error, "Current password is incorrect")
         |> put_flash(:error, "Current password is incorrect")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(changeset))
         |> assign(:password_error, nil)}
    end
  end

  def handle_event("validate_llm", %{"user" => _user_params}, socket) do
    {:noreply, socket}
  end

  def handle_event("save_llm", %{"user" => user_params}, socket) do
    case Accounts.update_user_llm_provider(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:llm_form, to_form(Accounts.change_user_llm_provider(user)))
         |> put_flash(:info, "LLM provider updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :llm_form, to_form(changeset))}
    end
  end

  defp get_configured_providers(user) do
    case LLMConfig.list_providers(user.id) do
      [] -> []
      settings -> Enum.map(settings, & &1.provider)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="bg-white shadow">
        <div class="container mx-auto px-4 py-4">
          <.link navigate={~p"/dashboard"} class="text-blue-600 hover:text-blue-800">
            <.icon name="hero-arrow-left" class="w-5 h-5 inline" /> Back to Dashboard
          </.link>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8 max-w-4xl">
        <div class="mb-6">
          <h1 class="text-3xl font-bold text-gray-900">Settings</h1>
          <p class="text-sm text-gray-600 mt-1">Manage your account settings and preferences</p>
        </div>

        <div class="bg-white rounded-lg shadow">
          <!-- Tabs -->
          <div class="border-b border-gray-200">
            <nav class="flex -mb-px">
              <button
                phx-click="switch_tab"
                phx-value-tab="profile"
                class={[
                  "px-6 py-3 text-sm font-medium border-b-2",
                  if @active_tab == "profile" do
                    "border-blue-500 text-blue-600"
                  else
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  end
                ]}
              >
                Profile
              </button>
              <button
                phx-click="switch_tab"
                phx-value-tab="password"
                class={[
                  "px-6 py-3 text-sm font-medium border-b-2",
                  if @active_tab == "password" do
                    "border-blue-500 text-blue-600"
                  else
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  end
                ]}
              >
                Password
              </button>
              <button
                phx-click="switch_tab"
                phx-value-tab="llm"
                class={[
                  "px-6 py-3 text-sm font-medium border-b-2",
                  if @active_tab == "llm" do
                    "border-blue-500 text-blue-600"
                  else
                    "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  end
                ]}
              >
                LLM Preferences
              </button>
            </nav>
          </div>
          
    <!-- Tab Content -->
          <div class="p-6">
            <%= if @active_tab == "profile" do %>
              <div>
                <h2 class="text-xl font-semibold text-gray-900 mb-4">Profile Information</h2>
                <.form
                  for={@profile_form}
                  id="profile-form"
                  phx-change="validate_profile"
                  phx-submit="save_profile"
                  class="space-y-4"
                >
                  <.input
                    field={@profile_form[:first_name]}
                    type="text"
                    label="First Name"
                    required
                  />
                  <.input
                    field={@profile_form[:last_name]}
                    type="text"
                    label="Last Name"
                    required
                  />
                  <.input
                    field={@profile_form[:email]}
                    type="email"
                    label="Email"
                    required
                  />
                  <div>
                    <.button phx-disable-with="Saving..." class="w-full sm:w-auto">
                      Update Profile
                    </.button>
                  </div>
                </.form>
              </div>
            <% end %>

            <%= if @active_tab == "password" do %>
              <div>
                <h2 class="text-xl font-semibold text-gray-900 mb-4">Change Password</h2>
                <.form
                  for={@password_form}
                  id="password-form"
                  phx-change="validate_password"
                  phx-submit="save_password"
                  class="space-y-4"
                >
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Current Password
                    </label>
                    <input
                      type="password"
                      name="password_change[current_password]"
                      class="input w-full"
                      required
                    />
                    <%= if @password_error do %>
                      <p class="mt-1 text-sm text-red-600">{@password_error}</p>
                    <% end %>
                  </div>
                  <.input
                    field={@password_form[:password]}
                    type="password"
                    label="New Password"
                    required
                  />
                  <.input
                    field={@password_form[:password_confirmation]}
                    type="password"
                    label="Confirm New Password"
                    required
                  />
                  <div>
                    <.button phx-disable-with="Saving..." class="w-full sm:w-auto">
                      Update Password
                    </.button>
                  </div>
                </.form>
              </div>
            <% end %>

            <%= if @active_tab == "llm" do %>
              <div>
                <h2 class="text-xl font-semibold text-gray-900 mb-4">LLM Provider Preferences</h2>
                <%= if @llm_providers == [] do %>
                  <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
                    <p class="text-sm text-yellow-800">
                      No LLM providers configured.
                      <.link navigate={~p"/dashboard/llm-config"} class="underline font-medium">
                        Configure an LLM provider
                      </.link>
                      to enable AI features.
                    </p>
                  </div>
                <% else %>
                  <.form
                    for={@llm_form}
                    id="llm-form"
                    phx-change="validate_llm"
                    phx-submit="save_llm"
                    class="space-y-4"
                  >
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Primary LLM Provider
                      </label>
                      <select
                        name="user[primary_llm_provider]"
                        class="input w-full"
                        value={@current_user.primary_llm_provider}
                      >
                        <%= for provider <- @llm_providers do %>
                          <option value={provider}>{String.capitalize(provider)}</option>
                        <% end %>
                      </select>
                      <p class="mt-1 text-sm text-gray-500">
                        This provider will be used for AI-powered features like job analysis and auto-fill
                      </p>
                    </div>
                    <div>
                      <.button phx-disable-with="Saving..." class="w-full sm:w-auto">
                        Update Preferences
                      </.button>
                    </div>
                  </.form>
                <% end %>
                <div class="mt-6">
                  <.link
                    navigate={~p"/dashboard/llm-config"}
                    class="text-blue-600 hover:text-blue-800 text-sm font-medium"
                  >
                    Manage LLM Configuration →
                  </.link>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
