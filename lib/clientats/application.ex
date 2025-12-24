defmodule Clientats.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Run migrations automatically on startup to ensure database schema is up to date
    # This is especially important when using platform-specific directories where the
    # database may be created fresh on first run. Migrations are idempotent, so they
    # won't re-apply if already completed. This provides a better user experience as
    # the application "just works" without requiring manual migration commands.
    migrate()

    children = [
      ClientatsWeb.Telemetry,
      Clientats.Repo,
      {DNSCluster, query: Application.get_env(:clientats, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Clientats.PubSub},
      # Background job queue
      {Oban, oban_config()},
      # LLM Cache for job scraping
      Clientats.LLM.Cache,
      # Metrics collector
      Clientats.LLM.Metrics,
      # Start to serve requests, typically the last entry
      ClientatsWeb.Endpoint
    ]

    # Attach metrics telemetry handlers after startup
    ClientatsWeb.MetricsHandler.attach_handlers()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Clientats.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Log database location for clarity
        db_path = Application.get_env(:clientats, Clientats.Repo)[:database]
        IO.puts("Database: #{db_path}")
        {:ok, pid}

      error ->
        error
    end
  end

  defp migrate do
    # Load the application to ensure all modules are available
    Application.load(:clientats)

    # Run migrations for all configured repos
    # Ecto.Migrator.with_repo will start the repo, run migrations, then stop it
    for repo <- Application.fetch_env!(:clientats, :ecto_repos) do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp oban_config do
    Application.get_env(:clientats, Oban)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClientatsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
