defmodule ClientatsWeb.UserRegistrationLive do
  use ClientatsWeb, :live_view

  on_mount {ClientatsWeb.UserAuth, :redirect_if_authenticated}

  alias Clientats.Accounts
  alias Clientats.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md mx-auto">
        <div class="text-center mb-8">
          <h2 class="text-3xl font-bold text-gray-900">Create your account</h2>
          <p class="mt-2 text-sm text-gray-600">
            Already have an account?
            <.link navigate={~p"/login"} class="font-medium text-blue-600 hover:text-blue-500">
              Sign in
            </.link>
          </p>
        </div>

        <div class="bg-white py-8 px-6 shadow-xl rounded-lg">
          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
          >
            <div class="space-y-4">
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                placeholder="you@example.com"
                required
              />

              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@form[:first_name]}
                  type="text"
                  label="First Name"
                  required
                />
                <.input
                  field={@form[:last_name]}
                  type="text"
                  label="Last Name"
                  required
                />
              </div>

              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                placeholder="Minimum 8 characters"
                required
              />

              <.input
                field={@form[:password_confirmation]}
                type="password"
                label="Confirm Password"
                required
              />

              <div>
                <.button phx-disable-with="Creating account..." class="w-full">
                  Create an account
                </.button>
              </div>
            </div>
          </.form>

          <form
            :if={@trigger_submit}
            id="login_form"
            action={~p"/login-after-registration"}
            method="post"
            phx-trigger-action={@trigger_submit}
            style="display: none;"
          >
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <input type="hidden" name="session[user_id]" value={@login_form.params["user_id"]} />
          </form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false)
      |> assign(login_form: nil)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        form = to_form(%{"user_id" => user.id}, as: "session")

        {:noreply,
         socket
         |> put_flash(:info, "Welcome to Clientats! Your account has been created successfully.")
         |> assign(:trigger_submit, true)
         |> assign(:login_form, form)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
