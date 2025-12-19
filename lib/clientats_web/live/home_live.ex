defmodule ClientatsWeb.HomeLive do
  use ClientatsWeb, :live_view

  on_mount {ClientatsWeb.UserAuth, :fetch_current_user}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      <div class="container mx-auto px-4 py-16">
        <div class="max-w-4xl mx-auto text-center">
          <h1 class="text-6xl font-bold text-gray-900 mb-6">
            Welcome to <span class="text-blue-600">Clientats</span>
          </h1>

          <p class="text-xl text-gray-600 mb-8">
            Your comprehensive job application tracking system
          </p>

          <div class="bg-white rounded-lg shadow-xl p-8 mb-12">
            <div class="grid md:grid-cols-3 gap-8">
              <div class="p-6">
                <.icon name="hero-briefcase" class="w-12 h-12 text-blue-600 mx-auto mb-4" />
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Track Interests</h3>
                <p class="text-gray-600">Keep track of jobs you're interested in applying to</p>
              </div>

              <div class="p-6">
                <.icon name="hero-document-text" class="w-12 h-12 text-purple-600 mx-auto mb-4" />
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Manage Applications</h3>
                <p class="text-gray-600">Organize all your job applications in one place</p>
              </div>

              <div class="p-6">
                <.icon
                  name="hero-chat-bubble-left-right"
                  class="w-12 h-12 text-green-600 mx-auto mb-4"
                />
                <h3 class="text-lg font-semibold text-gray-900 mb-2">Track Communications</h3>
                <p class="text-gray-600">Never lose track of important conversations</p>
              </div>
            </div>
          </div>

          <div class="space-x-4">
            <%= if @current_user do %>
              <.link
                navigate={~p"/dashboard"}
                class="inline-block bg-blue-600 hover:bg-blue-700 text-white font-semibold px-8 py-3 rounded-lg shadow-lg transition duration-200"
              >
                Go to Dashboard
              </.link>
            <% else %>
              <.link
                navigate={~p"/register"}
                class="inline-block bg-blue-600 hover:bg-blue-700 text-white font-semibold px-8 py-3 rounded-lg shadow-lg transition duration-200"
              >
                Get Started
              </.link>
              <.link
                navigate={~p"/login"}
                class="inline-block bg-white hover:bg-gray-50 text-gray-800 font-semibold px-8 py-3 rounded-lg shadow-lg border border-gray-200 transition duration-200"
              >
                Sign In
              </.link>
            <% end %>
          </div>

          <%= if @current_user do %>
            <div class="mt-12 pt-8 border-t border-gray-200">
              <h3 class="text-lg font-semibold text-gray-900 mb-4 text-center">
                Data Management
              </h3>
              <div class="flex justify-center gap-4">
                <a
                  href={~p"/export"}
                  class="inline-flex items-center gap-2 bg-green-600 hover:bg-green-700 text-white font-semibold px-6 py-3 rounded-lg shadow-lg transition duration-200"
                >
                  <.icon name="hero-arrow-down-tray" class="w-5 h-5" />
                  Export Data
                </a>
                <.link
                  navigate={~p"/import"}
                  class="inline-flex items-center gap-2 bg-purple-600 hover:bg-purple-700 text-white font-semibold px-6 py-3 rounded-lg shadow-lg transition duration-200"
                >
                  <.icon name="hero-arrow-up-tray" class="w-5 h-5" />
                  Import Data
                </.link>
              </div>
              <p class="text-sm text-gray-500 mt-4 text-center">
                Export your data as JSON or import data from another Clientats instance
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
