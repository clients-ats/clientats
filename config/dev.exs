import Config

# Configure your database
config :clientats, Clientats.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "clientats_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  max_overflow: 2,
  timeout: 5000

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :clientats, ClientatsWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "HTyRfmn4cRcIgfLAswemEzOYbfJLwP2vXGBgSNWAThcHuAH75fnKnK///Gdp1Dnl",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:clientats, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:clientats, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :clientats, ClientatsWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/clientats_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :phoenix, :plug_init_mode, :runtime

# Enable dev routes for dashboard and mailbox
config :clientats, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
# config :swoosh, :api_client, false

# LLM Configuration for development
config :req_llm,
  primary_provider: :ollama,
  providers: %{
    openai: %{
      api_key: System.get_env("OPENAI_API_KEY"),
      default_model: "gpt-4o"
    },
    anthropic: %{
      api_key: System.get_env("ANTHROPIC_API_KEY"),
      default_model: "claude-3-opus-20240229"
    },
    mistral: %{
      api_key: System.get_env("MISTRAL_API_KEY"),
      default_model: "mistral-large-latest"
    },
    ollama: %{
      base_url: System.get_env("OLLAMA_BASE_URL") || "http://localhost:11434",
      default_model:
        System.get_env("OLLAMA_MODEL") || "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL",
      vision_model: System.get_env("OLLAMA_VISION_MODEL") || "qwen2.5vl:7b",
      timeout: 60_000
    },
    google: %{
      api_key: System.get_env("GEMINI_API_KEY"),
      default_model: System.get_env("GEMINI_MODEL") || "gemini-2.0-flash",
      vision_model: System.get_env("GEMINI_VISION_MODEL") || "gemini-2.0-flash",
      api_version: System.get_env("GEMINI_API_VERSION") || "v1beta"
    }
  },
  fallback_providers: [:anthropic, :mistral, :google, :ollama],
  max_content_length: 2_000_000,
  enable_logging: true,
  cache_ttl: 86400
