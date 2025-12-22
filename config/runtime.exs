import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# For production releases (desktop app, docker, etc), we enable the server by default.
# You can disable it by setting PHX_SERVER=false if needed (e.g., for specific deployment scenarios).
# In development and test, the server is controlled by the respective config files.
if config_env() == :prod do
  # Enable server by default in production unless explicitly disabled
  server_enabled = System.get_env("PHX_SERVER", "true") != "false"
  config :clientats, ClientatsWeb.Endpoint, server: server_enabled
elsif System.get_env("PHX_SERVER") do
  # In dev/test, only enable if PHX_SERVER is explicitly set
  config :clientats, ClientatsWeb.Endpoint, server: true
end

if config_env() == :prod do
  # Use platform-specific config directory for database unless DATABASE_PATH is set
  # This will use:
  # - Linux: ~/.config/clientats/db/clientats.db
  # - macOS: ~/Library/Application Support/clientats/db/clientats.db
  # - Windows: %APPDATA%/clientats/db/clientats.db
  database_path = Clientats.Platform.database_path(ensure_dir: true)

  config :clientats, Clientats.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    busy_timeout: String.to_integer(System.get_env("BUSY_TIMEOUT") || "5000"),
    journal_mode: :wal,
    cache_size: -64000,
    temp_store: :memory,
    synchronous: :normal,
    foreign_keys: :on

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  # For desktop app deployments, we generate a stable key based on the machine
  # We need at least 64 bytes for the secret, so we hash twice and concatenate
  generate_secret = fn ->
    hash1 = :crypto.hash(:sha256, "clientats-desktop-#{:erlang.system_info(:system_version)}")
    hash2 = :crypto.hash(:sha256, hash1)
    (hash1 <> hash2)
    |> Base.encode64(padding: false)
    |> binary_part(0, 64)
  end

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") || generate_secret.()

  # For desktop app deployments, we default to localhost if PHX_HOST is not set
  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT") || "4000")

  # For the desktop app, we want the URL to match the local address
  # If scheme is https and port is 443, it will cause issues with local connections
  url_port = if System.get_env("PHX_HOST"), do: 443, else: port
  url_scheme = if System.get_env("PHX_HOST"), do: "https", else: "http"

  config :clientats, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Generate a stable encryption key for desktop deployments
  generate_encryption_key = fn ->
    :crypto.hash(:sha256, "clientats-llm-#{:erlang.system_info(:system_version)}")
    |> Base.encode64(padding: false)
    |> binary_part(0, 32)
  end

  llm_encryption_key =
    System.get_env("LLM_ENCRYPTION_KEY") || generate_encryption_key.()

  config :clientats,
    llm_encryption_key: llm_encryption_key

  # LLM Configuration for job scraping feature
  config :req_llm,
    primary_provider: :openai,
    providers: %{
      openai: %{
        api_key: System.get_env("OPENAI_API_KEY"),
        organization: System.get_env("OPENAI_ORG"),
        default_model: System.get_env("OPENAI_MODEL") || "gpt-4o",
        timeout: 30_000,
        max_retries: 3
      },
      anthropic: %{
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        default_model: System.get_env("ANTHROPIC_MODEL") || "claude-3-opus-20240229",
        timeout: 30_000,
        max_retries: 3
      },
      mistral: %{
        api_key: System.get_env("MISTRAL_API_KEY"),
        default_model: System.get_env("MISTRAL_MODEL") || "mistral-large-latest",
        timeout: 30_000,
        max_retries: 3
      },
      ollama: %{
        base_url: System.get_env("OLLAMA_BASE_URL") || "http://localhost:11434",
        default_model:
          System.get_env("OLLAMA_MODEL") || "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL",
        vision_model: System.get_env("OLLAMA_VISION_MODEL") || "qwen2.5vl:7b",
        timeout: 60_000,
        max_retries: 2
      },
      google: %{
        api_key: System.get_env("GEMINI_API_KEY"),
        default_model: System.get_env("GEMINI_MODEL") || "gemini-2.0-flash",
        vision_model: System.get_env("GEMINI_VISION_MODEL") || "gemini-2.0-flash",
        api_version: System.get_env("GEMINI_API_VERSION") || "v1beta",
        timeout: 30_000,
        max_retries: 3
      }
    },
    fallback_providers: [:anthropic, :mistral, :google, :ollama],
    max_content_length: 2_000_000,
    enable_logging: System.get_env("LLM_ENABLE_LOGGING") != "false",
    # 24 hours cache for successful extractions
    cache_ttl: 86400

  config :clientats, ClientatsWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    check_origin: ["//localhost", "//127.0.0.1", "//localhost:#{port}", "//127.0.0.1:#{port}"],
    http: [
      # For desktop/Tauri app: bind to IPv4 loopback (127.0.0.1)
      # This ensures the app can connect via http://127.0.0.1:4000
      ip: {127, 0, 0, 1},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :clientats, ClientatsWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :clientats, ClientatsWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :clientats, Clientats.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
