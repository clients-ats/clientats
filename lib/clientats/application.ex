defmodule Clientats.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize Prometheus metrics
    Clientats.LLM.Metrics.setup()
    ClientatsWeb.PrometheusHandler.attach_handlers()

    children = [
      ClientatsWeb.Telemetry,
      Clientats.Repo,
      {DNSCluster, query: Application.get_env(:clientats, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Clientats.PubSub},
      # LLM Cache for job scraping
      Clientats.LLM.Cache,
      # Start a worker by calling: Clientats.Worker.start_link(arg)
      # {Clientats.Worker, arg},
      # Start to serve requests, typically the last entry
      ClientatsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Clientats.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClientatsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
