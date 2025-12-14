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
      :openai ->
        test_openai_connection(config)

      :anthropic ->
        test_anthropic_connection(config)

      :mistral ->
        test_mistral_connection(config)

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
  Get status of all providers for a user.

  ## Parameters
    - user_id: User ID

  ## Returns
    - List of provider statuses
  """
  def get_provider_status(user_id) do
    Setting
    |> where(user_id: ^user_id)
    |> order_by([s], s.provider)
    |> Repo.all()
    |> Enum.map(&format_provider_status/1)
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
      :openai ->
        if String.starts_with?(api_key, "sk-") and byte_size(api_key) > 20 do
          :ok
        else
          {:error, "Invalid OpenAI API key format"}
        end

      :anthropic ->
        if byte_size(api_key) > 20 do
          :ok
        else
          {:error, "Invalid Anthropic API key format"}
        end

      :mistral ->
        if byte_size(api_key) > 20 do
          :ok
        else
          {:error, "Invalid Mistral API key format"}
        end

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
      openai: %{
        api_key: System.get_env("OPENAI_API_KEY"),
        default_model: System.get_env("OPENAI_MODEL") || "gpt-4o",
        enabled: System.get_env("OPENAI_API_KEY") != nil
      },
      anthropic: %{
        api_key: System.get_env("ANTHROPIC_API_KEY"),
        default_model: System.get_env("ANTHROPIC_MODEL") || "claude-3-opus-20240229",
        enabled: System.get_env("ANTHROPIC_API_KEY") != nil
      },
      mistral: %{
        api_key: System.get_env("MISTRAL_API_KEY"),
        default_model: System.get_env("MISTRAL_MODEL") || "mistral-large-latest",
        enabled: System.get_env("MISTRAL_API_KEY") != nil
      },
      gemini: %{
        api_key: System.get_env("GEMINI_API_KEY"),
        default_model: System.get_env("GEMINI_MODEL") || "gemini-2.0-flash",
        vision_model: System.get_env("GEMINI_VISION_MODEL") || "gemini-2.0-flash",
        text_model: System.get_env("GEMINI_TEXT_MODEL") || "gemini-2.0-flash",
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
    decrypted_key = if setting.api_key, do: Setting.decrypt_api_key(setting.api_key)
    %{setting | api_key: decrypted_key}
  end

  defp decrypt_setting(setting), do: setting

  defp format_provider_status(%Setting{} = setting) do
    %{
      provider: setting.provider,
      enabled: setting.enabled,
      status: setting.provider_status || "unconfigured",
      model: setting.default_model,
      configured: setting.provider_status != "unconfigured" and setting.api_key != nil
    }
  end

  defp test_openai_connection(config) do
    api_key = config[:api_key]

    if !api_key || !String.starts_with?(api_key, "sk-") do
      {:error, "Invalid OpenAI API key"}
    else
      try do
        case Req.post!("https://api.openai.com/v1/models",
          auth: {:bearer, api_key},
          receive_timeout: 5000
        ) do
          %{status: 200} ->
            {:ok, "connected"}

          %{status: 401} ->
            {:error, "Invalid API key"}

          %{status: status} ->
            {:error, "Connection failed (#{status})"}
        end
      rescue
        _e -> {:error, "Connection failed"}
      end
    end
  end

  defp test_anthropic_connection(config) do
    api_key = config[:api_key]

    if !api_key do
      {:error, "Missing Anthropic API key"}
    else
      try do
        case Req.get!("https://api.anthropic.com/v1/models",
          headers: [{"x-api-key", api_key}],
          receive_timeout: 5000
        ) do
          %{status: 200} ->
            {:ok, "connected"}

          %{status: 401} ->
            {:error, "Invalid API key"}

          %{status: status} ->
            {:error, "Connection failed (#{status})"}
        end
      rescue
        _e -> {:error, "Connection failed"}
      end
    end
  end

  defp test_mistral_connection(config) do
    api_key = config[:api_key]

    if !api_key do
      {:error, "Missing Mistral API key"}
    else
      try do
        case Req.get!("https://api.mistral.ai/v1/models",
          headers: [{"Authorization", "Bearer #{api_key}"}],
          receive_timeout: 5000
        ) do
          %{status: 200} ->
            {:ok, "connected"}

          %{status: 401} ->
            {:error, "Invalid API key"}

          %{status: status} ->
            {:error, "Connection failed (#{status})"}
        end
      rescue
        _e -> {:error, "Connection failed"}
      end
    end
  end

  defp test_ollama_connection(config) do
    base_url = config[:base_url] || "http://localhost:11434"

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
    api_key = config[:api_key]

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

        case response do
          %{status: 200} ->
            {:ok, "connected"}

          %{status: 401} ->
            {:error, "Invalid API key"}

          %{status: 403} ->
            {:error, "Access denied - check API key and enable required APIs"}

          %{status: 429} ->
            {:error, "Rate limited"}

          %{status: status} ->
            {:error, "Connection failed with status #{status}"}
        end
      rescue
        e ->
          error_msg = Exception.message(e)
          {:error, "Failed to connect: #{error_msg}"}
      end
    end
  end
end
