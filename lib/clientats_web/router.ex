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
    plug :fetch_session
    plug :protect_from_forgery
  end

  scope "/", ClientatsWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/register", UserRegistrationLive
    live "/login", UserLoginLive
    live "/dashboard", DashboardLive
    live "/dashboard/settings", UserSettingsLive
    live "/dashboard/job-interests/new", JobInterestLive.New
    live "/dashboard/job-interests/scrape", JobInterestLive.Scrape
    live "/dashboard/job-interests/:id", JobInterestLive.Show, :show
    live "/dashboard/job-interests/:id/edit", JobInterestLive.Edit
    live "/dashboard/resumes", ResumeLive.Index
    live "/dashboard/resumes/new", ResumeLive.New
    live "/dashboard/resumes/:id/edit", ResumeLive.Edit
    get "/dashboard/resumes/:id/download", ResumeController, :download
    live "/dashboard/cover-letters", CoverLetterLive.Index
    live "/dashboard/cover-letters/new", CoverLetterLive.New
    live "/dashboard/cover-letters/:id/edit", CoverLetterLive.Edit
    live "/dashboard/applications", JobApplicationLive.Index
    live "/dashboard/applications/new", JobApplicationLive.New
    live "/dashboard/applications/convert/:interest_id", JobApplicationLive.ConversionWizard
    live "/dashboard/applications/:id", JobApplicationLive.Show, :show
    get "/dashboard/applications/:id/download-cover-letter", JobApplicationController, :download_cover_letter
    live "/dashboard/llm-config", LLMConfigLive
    live "/dashboard/llm-setup", LLMWizardLive
    live "/import", DataImportLive
    get "/export", DataExportController, :export
    post "/login", UserSessionController, :create
    post "/login-after-registration", UserSessionController, :create_after_registration
    delete "/logout", UserSessionController, :delete
  end

  # API Routes - Version 1 (Current)
  scope "/api/v1", ClientatsWeb do
    pipe_through :api

    post "/scrape_job", JobScraperController, :scrape
    get "/llm/providers", JobScraperController, :providers
    get "/llm/config", JobScraperController, :config
  end

  # API Routes - Version 2 (Future - Beta)
  # Planned for future enhancements like enhanced response formats,
  # additional metadata, and improved error handling
  scope "/api/v2", ClientatsWeb do
    pipe_through :api

    post "/scrape_job", JobScraperController, :scrape
    get "/llm/providers", JobScraperController, :providers
    get "/llm/config", JobScraperController, :config
  end

  # Legacy: Support /api without version (redirects to v1 for backward compatibility)
  scope "/api", ClientatsWeb do
    pipe_through :api

    post "/scrape_job", JobScraperController, :scrape
    get "/llm/providers", JobScraperController, :providers
    get "/llm/config", JobScraperController, :config
  end

  # API Documentation endpoints
  scope "/api-docs", ClientatsWeb do
    get "/", APIDocsController, :index
    get "/swagger-ui", APIDocsController, :swagger_ui
    get "/redoc", APIDocsController, :redoc_ui
    get "/openapi.json", APIDocsController, :openapi
  end

  # Health check and metrics endpoints (no auth pipeline)
  scope "/", ClientatsWeb do
    get "/health", HealthController, :simple
    get "/health/ready", HealthController, :detailed
    get "/health/diagnostics", HealthController, :diagnostics
    get "/metrics", MetricsController, :index
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
