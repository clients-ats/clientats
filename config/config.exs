# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :clientats,
  ecto_repos: [Clientats.Repo],
  generators: [timestamp_type: :utc_datetime],
  llm_encryption_key: "default-dev-key-for-local-development-only"

# Configure Oban background job queue
config :clientats, Oban,
  engine: Oban.Engines.Lite,
  repo: Clientats.Repo,
  plugins: [
    {Oban.Plugins.Pruner, interval: :timer.hours(12), limit: 5000}
  ],
  queues: [
    scrape: [limit: 10],
    default: [limit: 50],
    low: [limit: 20]
  ]

# Configures the endpoint
config :clientats, ClientatsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ClientatsWeb.ErrorHTML, json: ClientatsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Clientats.PubSub,
  live_view: [signing_salt: "NlvhmEV+"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
# config :clientats, Clientats.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  clientats: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=. --alias:phoenix-colocated=../_build/#{Mix.env()}/phoenix-colocated),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  clientats: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
