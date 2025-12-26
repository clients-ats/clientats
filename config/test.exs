import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :clientats, Clientats.Repo,
  database: Path.expand("../clientats_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  journal_mode: :wal,
  cache_size: -64000,
  temp_store: :memory,
  synchronous: :normal,
  foreign_keys: :on

# We don't run a server during test. If one is required,
# you can enable the server option below.
# For E2E tests with Wallaby, the server needs to be enabled.
config :clientats, ClientatsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "HTyRfmn4cRcIgfLAswemEzOYbfJLwP2vXGBgSNWAThcHuAH75fnKnK///Gdp1Dnl",
  server: true

# In test we don't send emails
# config :clientats, Clientats.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
# config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Wallaby configuration for E2E tests
config :wallaby,
  driver: Wallaby.Chrome,
  hackney_options: [timeout: :infinity, recv_timeout: :infinity],
  screenshot_on_failure: true,
  # Use headless mode in CI environments
  chromedriver: [
    headless: System.get_env("CI") == "true" || System.get_env("HEADLESS") == "true"
  ]

config :clientats, :sql_sandbox, true

config :clientats,
  llm_encryption_key: "test-encryption-key-for-testing"

# Configure Oban for testing
config :clientats, Oban,
  testing: :inline,
  plugins: false,
  queues: false
