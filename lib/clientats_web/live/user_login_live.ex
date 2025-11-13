defmodule ClientatsWeb.UserLoginLive do
  use ClientatsWeb, :live_view

  on_mount {ClientatsWeb.UserAuth, :redirect_if_authenticated}

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md mx-auto">
        <div class="text-center mb-8">
          <h2 class="text-3xl font-bold text-gray-900">Sign in to your account</h2>
          <p class="mt-2 text-sm text-gray-600">
            Don't have an account?
            <.link navigate={~p"/register"} class="font-medium text-blue-600 hover:text-blue-500">
              Sign up
            </.link>
          </p>
        </div>

        <div class="bg-white py-8 px-6 shadow-xl rounded-lg">
          <.form for={@form} id="login_form" action={~p"/login"} phx-update="ignore">
            <div class="space-y-4">
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                placeholder="you@example.com"
                required
              />

              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                required
              />

              <div>
                <.button phx-disable-with="Signing in..." class="w-full">
                  Sign in
                </.button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
