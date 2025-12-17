defmodule Clientats.LLMConfig do
  @moduledoc """
  Context for managing LLM provider configurations.

  Provides functions for managing provider settings including validation,
  encryption, connection testing, and provider status tracking.
  """

  import Ecto.Query, warn: false
  alias Clientats.Repo
  alias Clientats.LLM.Setting

  @doc """
  Get provider configuration for a user.

  ## Parameters
    - user_id: User ID
    - provider: Provider name (atom or string)

  ## Returns
    - {:ok, setting} if found
    - {:error, :not_found} if not found
  """
  def get_provider_config(user_id, provider) when is_binary(provider) do
    provider_atom = String.to_atom(provider)
    get_provider_config(user_id, provider_atom)
  end

  def get_provider_config(user_id, provider) when is_atom(provider) do
    case Repo.get_by(Setting, user_id: user_id, provider: Atom.to_string(provider)) do
      nil -> {:error, :not_found}
      setting -> {:ok, decrypt_setting(setting)}
    end
  end

  @doc """
  Save provider configuration for a user.

  ## Parameters
    - user_id: User ID
    - provider: Provider name (atom or string)
    - config_params: Configuration parameters

  ## Returns
    - {:ok, setting} on success
    - {:error, changeset} on validation failure
  """
  def save_provider_config(user_id, provider, config_params) when is_binary(provider) do
    provider_atom = String.to_atom(provider)
    save_provider_config(user_id, provider_atom, config_params)
  end

  def save_provider_config(user_id, provider, config_params) when is_atom(provider) do
    provider_str = Atom.to_string(provider)

    # Normalize config_params to use string keys
    normalized_params =
      config_params
      |> Enum.map(fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)
      |> Enum.into(%{})

    case Repo.get_by(Setting, user_id: user_id, provider: provider_str) do
      nil ->
        %Setting{}
        |> Setting.changeset(
          normalized_params
          |> Map.put("user_id", user_id)
          |> Map.put("provider", provider_str)
        )
        |> Repo.insert()

      existing ->
        existing
        |> Setting.changeset(
          normalized_params
          |> Map.put("provider", provider_str)
        )
        |> Repo.update()
    end
  end

  @doc """
  Test connection to a provider with given configuration.

  ## Parameters
    - provider: Provider name
    - config: Configuration map

  ## Returns
    - {:ok, status} on success
    - {:error, reason} on failure
  """
  def test_connection(provider, config) when is_binary(provider) do
    provider_atom = String.to_atom(provider)
    test_connection(provider_atom, config)
  end

  def test_connection(provider, config) when is_atom(provider) do
    case provider do
      :gemini ->
        test_gemini_connection(config)

      :ollama ->
        test_ollama_connection(config)

      _ ->
        {:error, "Unknown provider: #{provider}"}
    end
  end

  @doc """
  Get list of enabled providers for a user.

  ## Parameters
    - user_id: User ID

  ## Returns
    - List of provider names (atoms)
  """
  def get_enabled_providers(user_id) do
    Setting
    |> where(user_id: ^user_id, enabled: true)
    |> select([s], s.provider)
    |> Repo.all()
    |> Enum.map(&String.to_atom/1)
  end

  @doc """
  Get status of all providers for a user, ordered by sort_order.

  ## Parameters
    - user_id: User ID

  ## Returns
    - List of provider statuses ordered by sort_order
  """
  def get_provider_status(user_id) do
    Setting
    |> where(user_id: ^user_id)
    |> order_by([s], [asc: s.sort_order, asc: s.provider])
    |> Repo.all()
    |> Enum.map(&format_provider_status/1)
  end

  @doc """
  List all providers for a user, ordered by sort_order.

  ## Parameters
    - user_id: User ID

  ## Returns
    - List of provider settings ordered by sort_order
  """
  def list_providers(user_id) do
    Setting
    |> where(user_id: ^user_id)
    |> order_by([s], [asc: s.sort_order, asc: s.provider])
    |> Repo.all()
  end

  @doc """
  Reorder providers for a user.

  Takes a list of provider names in the desired order and updates the sort_order field.

  ## Parameters
    - user_id: User ID
    - provider_order: List of provider names in desired order

  ## Returns
    - {:ok, updated_count} on success
    - {:error, reason} on failure
  """
  def reorder_providers(user_id, provider_order) when is_list(provider_order) do
    Repo.transaction(fn ->
      provider_order
      |> Enum.with_index()
      |> Enum.each(fn {provider, index} ->
        provider_str = if is_atom(provider), do: Atom.to_string(provider), else: provider

        Setting
        |> where(user_id: ^user_id, provider: ^provider_str)
        |> Repo.update_all(set: [sort_order: index])
      end)

      length(provider_order)
    end)
  end

  @doc """
  Delete a provider configuration for a user.

  ## Parameters
    - user_id: User ID
    - provider: Provider name (atom or string)

  ## Returns
    - {:ok, deleted_setting} on success
    - {:error, :not_found} if provider not configured
    - {:error, changeset} on database error
  """
  def delete_provider(user_id, provider) when is_binary(provider) do
    provider_atom = String.to_atom(provider)
    delete_provider(user_id, provider_atom)
  end

  def delete_provider(user_id, provider) when is_atom(provider) do
    provider_str = Atom.to_string(provider)

    case Repo.get_by(Setting, user_id: user_id, provider: provider_str) do
      nil -> {:error, :not_found}
      setting -> Repo.delete(setting)
    end
  end

  @doc """
  Validate API key format for a provider.

  ## Parameters
    - provider: Provider name
    - api_key: API key to validate

  ## Returns
    - :ok if valid
    - {:error, reason} if invalid
  """
  def validate_api_key(provider, api_key) when is_binary(provider) do
    provider_atom = String.to_atom(provider)
    validate_api_key(provider_atom, api_key)
  end

  def validate_api_key(provider, api_key) when is_atom(provider) and is_binary(api_key) do
    case provider do
      :gemini ->
        if byte_size(api_key) > 10 do
          :ok
        else
          {:error, "Invalid Gemini API key format"}
        end

      :ollama ->
        # Ollama doesn't require an API key
        :ok

      _ ->
        {:error, "Unknown provider: #{provider}"}
    end
  end

  def validate_api_key(_, nil), do: :ok
  def validate_api_key(_, _), do: {:error, "Invalid API key"}

  @doc """
  Load configuration from environment variables as defaults.

  ## Returns
    - Map of default configurations from environment
  """
  def get_env_defaults do
    %{
      gemini: %{
        api_key: System.get_env("GEMINI_API_KEY"),
        default_model: System.get_env("GEMINI_MODEL") || "gemini-2.5-flash",
        vision_model: System.get_env("GEMINI_VISION_MODEL") || "gemini-2.5-flash",
        text_model: System.get_env("GEMINI_TEXT_MODEL") || "gemini-2.5-flash",
        enabled: System.get_env("GEMINI_API_KEY") != nil
      },
      ollama: %{
        base_url: System.get_env("OLLAMA_BASE_URL") || "http://localhost:11434",
        default_model: System.get_env("OLLAMA_MODEL") || "hf.co/unsloth/Magistral-Small-2509-GGUF:UD-Q4_K_XL",
        vision_model: System.get_env("OLLAMA_VISION_MODEL") || "qwen2.5vl:7b",
        enabled: true
      }
    }
  end

  @doc """
  Create a changeset for provider configuration form.

  ## Parameters
    - user_id: User ID
    - provider: Provider name
    - attrs: Form attributes

  ## Returns
    - Changeset for the configuration
  """
  def change_provider_config(user_id, provider, attrs \\ %{}) do
    case Repo.get_by(Setting, user_id: user_id, provider: Atom.to_string(provider)) do
      nil ->
        Setting.changeset(
          %Setting{},
          Map.merge(attrs, %{user_id: user_id, provider: Atom.to_string(provider)})
        )

      setting ->
        Setting.changeset(setting, attrs)
    end
  end

  # Private functions

  defp decrypt_setting(%Setting{} = setting) do
    # API keys are now stored in plain text, no decryption needed
    setting
  end

  defp decrypt_setting(setting), do: setting

  defp format_provider_status(%Setting{} = setting) do
    # For Ollama, we don't need an API key, so just check provider_status
    # For other providers, check both provider_status and api_key
    configured =
      case setting.provider do
        "ollama" ->
          setting.provider_status != "unconfigured" and setting.base_url != nil and setting.base_url != ""
        _ ->
          setting.provider_status != "unconfigured" and setting.api_key != nil
      end

    %{
      provider: setting.provider,
      enabled: setting.enabled,
      status: setting.provider_status || "unconfigured",
      model: setting.default_model,
      configured: configured,
      last_tested_at: setting.last_tested_at,
      last_error: setting.last_error,
      updated_at: setting.updated_at
    }
  end

  defp test_ollama_connection(config) do
    base_url = config.base_url || "http://localhost:11434"

    try do
      case Req.get!("#{base_url}/api/tags", receive_timeout: 5000) do
        %{status: 200} ->
          {:ok, "connected"}

        %{status: status} ->
          {:error, "Connection failed with status #{status}"}
      end
    rescue
      e ->
        error_msg = Exception.message(e)
        {:error, "Failed to connect: #{error_msg}"}
    end
  end

  defp test_gemini_connection(config) do
    api_key = config.api_key

    if is_nil(api_key) or api_key == "" do
      {:error, "API key is required"}
    else
      try do
        response = Req.post!(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent",
          headers: [{"x-goog-api-key", api_key}],
          json: %{
            "contents" => [%{"parts" => [%{"text" => "Test"}]}]
          },
          receive_timeout: 5000
        )

        handle_gemini_response(response)
      rescue
        e ->
          handle_gemini_connection_error(e)
      end
    end
  end

  defp handle_gemini_response(%{status: 200}) do
    require Logger
    Logger.info("Gemini connection successful", provider: "gemini")
    {:ok, "connected"}
  end

  defp handle_gemini_response(%{status: 400, body: body}) do
    require Logger
    error_detail = extract_gemini_error_message(body)
    Logger.warning("Gemini validation error: #{error_detail}", provider: "gemini", status: 400)
    {:error, "Invalid request: #{error_detail}. Check your API configuration."}
  end

  defp handle_gemini_response(%{status: 401, body: body}) do
    require Logger
    error_detail = extract_gemini_error_message(body)
    Logger.warning("Gemini authentication failed: #{error_detail}", provider: "gemini", status: 401)
    {:error, "Authentication failed: Invalid API key or expired credentials"}
  end

  defp handle_gemini_response(%{status: 403, body: body}) do
    require Logger
    error_detail = extract_gemini_error_message(body)
    Logger.warning("Gemini access denied: #{error_detail}", provider: "gemini", status: 403)
    {:error, "Access denied: Generative AI API may not be enabled in your Google Cloud project. Enable it at console.cloud.google.com"}
  end

  defp handle_gemini_response(%{status: 429, body: body}) do
    require Logger
    error_detail = extract_gemini_error_message(body)
    Logger.warning("Gemini rate limited: #{error_detail}", provider: "gemini", status: 429)
    {:error, "Rate limited: Too many requests. Please wait before trying again."}
  end

  defp handle_gemini_response(%{status: 500, body: body}) do
    require Logger
    error_detail = extract_gemini_error_message(body)
    Logger.error("Gemini server error: #{error_detail}", provider: "gemini", status: 500)
    {:error, "Server error: Google Generative AI service is temporarily unavailable. Please try again later."}
  end

  defp handle_gemini_response(%{status: status, body: body}) do
    require Logger
    error_detail = extract_gemini_error_message(body)
    Logger.error("Gemini connection failed (#{status}): #{error_detail}", provider: "gemini", status: status)
    {:error, "Connection failed with status #{status}: #{error_detail}"}
  end

  @doc """
  Get the primary LLM provider for a user.

  ## Parameters
    - user_id: User ID

  ## Returns
    - Provider name as string (e.g., "gemini", "ollama")
  """
  def get_primary_provider(user_id) do
    case Repo.get(Clientats.Accounts.User, user_id) do
      nil -> "gemini"
      user -> user.primary_llm_provider || "gemini"
    end
  end

  @doc """
  Set the primary LLM provider for a user.

  ## Parameters
    - user_id: User ID
    - provider: Provider name (atom or string)

  ## Returns
    - {:ok, user} on success
    - {:error, reason} on failure
  """
  def set_primary_provider(user_id, provider) when is_binary(provider) do
    provider_atom = String.to_atom(provider)
    set_primary_provider(user_id, provider_atom)
  end

  def set_primary_provider(user_id, provider) when is_atom(provider) do
    provider_str = Atom.to_string(provider)

    case Repo.get(Clientats.Accounts.User, user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        user
        |> Ecto.Changeset.change(%{primary_llm_provider: provider_str})
        |> Repo.update()
    end
  end

  @doc """
  Save test connection results for a provider.

  ## Parameters
    - user_id: User ID
    - provider: Provider name (string)
    - test_result: {:ok, _} or {:error, error_msg}
  """
  def save_test_result(user_id, provider, test_result) when is_binary(provider) do
    case get_provider_config(user_id, provider) do
      {:ok, setting} ->
        attrs =
          case test_result do
            {:ok, _} ->
              %{
                provider_status: "connected",
                last_tested_at: NaiveDateTime.utc_now(),
                last_error: nil
              }

            {:error, error_msg} ->
              %{
                provider_status: "error",
                last_tested_at: NaiveDateTime.utc_now(),
                last_error: error_msg
              }
          end

        setting
        |> Setting.changeset(attrs)
        |> Repo.update()

      {:error, _} ->
        {:error, :provider_not_configured}
    end
  end

  @doc """
  Toggle the enabled state of a provider.

  ## Parameters
    - user_id: User ID
    - provider: Provider name (string)

  ## Returns
    - {:ok, updated_status_map} on success
    - {:error, reason} on failure
  """
  def toggle_provider_enabled(user_id, provider) when is_binary(provider) do
    case get_provider_config(user_id, provider) do
      {:ok, setting} ->
        new_enabled = !setting.enabled

        setting
        |> Setting.changeset(%{enabled: new_enabled})
        |> Repo.update()
        |> case do
          {:ok, updated_setting} ->
            {:ok, format_provider_status(updated_setting)}

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, _} ->
        {:error, :provider_not_configured}
    end
  end

  defp extract_gemini_error_message(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"message" => message}}} -> message
      {:ok, %{"error" => error}} when is_binary(error) -> error
      _ -> "(no error details)"
    end
  rescue
    _ -> "(unable to parse error details)"
  end

  defp extract_gemini_error_message(_), do: "(no error details)"

  defp handle_gemini_connection_error(e) do
    require Logger
    error_msg = Exception.message(e)
    Logger.error("Gemini connection error: #{error_msg}", provider: "gemini")
    {:error, "Failed to connect to Gemini service: #{error_msg}"}
  end
end
