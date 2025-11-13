defmodule ClientatsWeb.Router do
  use ClientatsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ClientatsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ClientatsWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/register", UserRegistrationLive
    live "/login", UserLoginLive
    live "/dashboard", DashboardLive
    live "/dashboard/job-interests/new", JobInterestLive.New
    live "/dashboard/job-interests/:id", JobInterestLive.Show, :show
    live "/dashboard/job-interests/:id/edit", JobInterestLive.Edit
    live "/dashboard/resumes", ResumeLive.Index
    live "/dashboard/resumes/new", ResumeLive.New
    live "/dashboard/resumes/:id/edit", ResumeLive.Edit
    live "/dashboard/cover-letters", CoverLetterLive.Index
    live "/dashboard/cover-letters/new", CoverLetterLive.New
    live "/dashboard/cover-letters/:id/edit", CoverLetterLive.Edit
    live "/dashboard/applications", JobApplicationLive.Index
    live "/dashboard/applications/new", JobApplicationLive.New
    live "/dashboard/applications/:id", JobApplicationLive.Show, :show
    post "/login", UserSessionController, :create
    post "/login-after-registration", UserSessionController, :create_after_registration
    delete "/logout", UserSessionController, :delete
  end

  # Other scopes may use custom stacks.
  # scope "/api", ClientatsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:clientats, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ClientatsWeb.Telemetry
    end
  end
end
