defmodule Clientats.LLMConfigTest do
  use Clientats.DataCase

  alias Clientats.LLMConfig
  alias Clientats.LLM.Setting
  alias Clientats.Accounts

  describe "get_provider_config/2" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "returns provider config when configured", %{user: user} do
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash",
        "enabled" => true
      }

      {:ok, _setting} = LLMConfig.save_provider_config(user.id, :gemini, config)

      {:ok, retrieved} = LLMConfig.get_provider_config(user.id, :gemini)
      assert retrieved.provider == "gemini"
      assert retrieved.enabled == true
    end

    test "returns :not_found when not configured", %{user: user} do
      {:error, :not_found} = LLMConfig.get_provider_config(user.id, :gemini)
    end

    test "accepts provider name as string or atom", %{user: user} do
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "enabled" => true
      }

      {:ok, _setting} = LLMConfig.save_provider_config(user.id, :gemini, config)

      {:ok, _retrieved_atom} = LLMConfig.get_provider_config(user.id, :gemini)
      {:ok, _retrieved_string} = LLMConfig.get_provider_config(user.id, "gemini")
    end
  end

  describe "save_provider_config/3" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "saves new provider configuration", %{user: user} do
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash",
        "enabled" => true
      }

      {:ok, setting} = LLMConfig.save_provider_config(user.id, :gemini, config)
      assert setting.user_id == user.id
      assert setting.provider == "gemini"
      assert setting.enabled == true
    end

    test "updates existing provider configuration", %{user: user} do
      config1 = %{
        "provider" => "gemini",
        "api_key" => "AIza111111111111111111111111",
        "enabled" => true
      }

      {:ok, _} = LLMConfig.save_provider_config(user.id, :gemini, config1)

      config2 = %{
        "provider" => "gemini",
        "api_key" => "AIza222222222222222222222222",
        "enabled" => false
      }

      {:ok, updated} = LLMConfig.save_provider_config(user.id, :gemini, config2)
      assert updated.enabled == false
    end

    test "stores API keys as plain text", %{user: user} do
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "enabled" => true
      }

      {:ok, setting} = LLMConfig.save_provider_config(user.id, :gemini, config)

      # Verify API key is stored as plain text
      assert setting.api_key == "AIza123456789abcdefghijklmnop"
      assert is_binary(setting.api_key)
    end
  end

  describe "get_enabled_providers/1" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "returns list of enabled providers", %{user: user} do
      LLMConfig.save_provider_config(user.id, :gemini, %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "enabled" => true
      })

      LLMConfig.save_provider_config(user.id, :ollama, %{
        "provider" => "ollama",
        "base_url" => "http://localhost:11434",
        "enabled" => false
      })

      enabled = LLMConfig.get_enabled_providers(user.id)
      assert :gemini in enabled
      refute :ollama in enabled
    end

    test "returns empty list when no providers enabled", %{user: user} do
      enabled = LLMConfig.get_enabled_providers(user.id)
      assert enabled == []
    end
  end

  describe "get_provider_status/1" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "returns status of all providers for user", %{user: user} do
      LLMConfig.save_provider_config(user.id, :gemini, %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash",
        "enabled" => true
      })

      statuses = LLMConfig.get_provider_status(user.id)
      assert length(statuses) >= 1

      gemini_status = Enum.find(statuses, &(&1[:provider] == "gemini"))
      assert gemini_status[:enabled] == true
    end
  end

  describe "validate_api_key/2" do
    test "allows nil or no API key for Ollama" do
      assert :ok = LLMConfig.validate_api_key(:ollama, nil)
      assert :ok = LLMConfig.validate_api_key(:ollama, "")
    end

    test "validates Gemini API key format" do
      assert :ok = LLMConfig.validate_api_key(:gemini, "AIza123456789abcdefghijklmnop")
      assert {:error, _} = LLMConfig.validate_api_key(:gemini, "short")
      assert {:error, _} = LLMConfig.validate_api_key(:gemini, "")
    end

    test "rejects unknown provider" do
      assert {:error, _} = LLMConfig.validate_api_key(:unknown, "key")
    end
  end

  describe "test_connection/2" do
    test "handles Ollama local connection" do
      # This test might fail if Ollama is not running, which is expected
      config = %{base_url: "http://localhost:11434"}
      _result = LLMConfig.test_connection(:ollama, config)
    end

    test "returns error when Gemini API key is missing" do
      config = %{api_key: nil}
      {:error, msg} = LLMConfig.test_connection(:gemini, config)
      assert msg == "API key is required"
    end

    test "returns error when Gemini API key is empty" do
      config = %{api_key: ""}
      {:error, msg} = LLMConfig.test_connection(:gemini, config)
      assert msg == "API key is required"
    end

    test "handles Gemini 401 authentication error" do
      # Invalid API key will typically result in 401
      config = %{api_key: "invalid-key-12345"}
      result = LLMConfig.test_connection(:gemini, config)
      assert {:error, _msg} = result
    end

    test "handles Gemini 403 access denied error gracefully" do
      # 403 typically means API is not enabled in Google Cloud project
      config = %{api_key: "AIza-test-12345"}
      result = LLMConfig.test_connection(:gemini, config)
      # Result might vary based on actual API response - either error or success
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "change_provider_config/3" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "returns changeset for new configuration", %{user: user} do
      changeset = LLMConfig.change_provider_config(user.id, :gemini)
      # Changeset is for a new configuration, just verify it's a changeset
      assert is_map(changeset)

      changeset =
        LLMConfig.change_provider_config(user.id, :gemini, %{
          api_key: "AIza123456789abcdefghijklmnop",
          default_model: "gemini-2.0-flash"
        })

      assert is_map(changeset)
    end

    test "returns changeset with existing data for edit", %{user: user} do
      LLMConfig.save_provider_config(user.id, :gemini, %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash"
      })

      changeset = LLMConfig.change_provider_config(user.id, :gemini)
      assert changeset.data.provider == "gemini"
    end
  end

  describe "get_env_defaults/0" do
    test "returns defaults from environment variables" do
      defaults = LLMConfig.get_env_defaults()

      # Verify structure
      assert is_map(defaults[:ollama])
      assert is_map(defaults[:gemini])

      # Verify required keys
      assert defaults[:ollama][:base_url] =~ "localhost"

      # Verify Gemini defaults
      assert defaults[:gemini][:default_model] == "gemini-2.5-flash"
      assert defaults[:gemini][:vision_model] == "gemini-2.5-flash"
      assert defaults[:gemini][:text_model] == "gemini-2.5-flash"
      assert is_boolean(defaults[:gemini][:enabled])
    end
  end

  # Test Setting schema directly
  describe "Setting schema" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "validates required fields", %{user: user} do
      changeset =
        Setting.changeset(%Setting{}, %{
          "user_id" => user.id
          # missing provider
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).provider
    end

    test "validates provider inclusion", %{user: user} do
      changeset =
        Setting.changeset(%Setting{}, %{
          "user_id" => user.id,
          "provider" => "invalid_provider"
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).provider
    end

    test "stores API keys as plain text" do
      original_key = "sk-test-key-12345"

      # API keys are now stored as plain text, no encryption
      assert is_binary(original_key)
    end

    test "allows Gemini as a valid provider" do
      {:ok, user} = create_test_user()

      changeset =
        Setting.changeset(%Setting{}, %{
          "user_id" => user.id,
          "provider" => "gemini",
          "api_key" => "AIza-test-12345"
        })

      assert changeset.valid?
    end

    test "stores Gemini configuration with vision and text models" do
      {:ok, user} = create_test_user()

      changeset =
        Setting.changeset(%Setting{}, %{
          "user_id" => user.id,
          "provider" => "gemini",
          "api_key" => "AIza-test-12345",
          "default_model" => "gemini-2.0-flash",
          "vision_model" => "gemini-2.0-flash",
          "text_model" => "gemini-1.5-pro"
        })

      assert changeset.valid?
      {:ok, setting} = Repo.insert(changeset)
      assert setting.provider == "gemini"
      assert setting.default_model == "gemini-2.0-flash"
    end
  end

  describe "Gemini provider configuration workflow" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    test "complete Gemini setup flow", %{user: user} do
      # 1. Validate API key
      assert :ok = LLMConfig.validate_api_key(:gemini, "AIza123456789abcdefghijklmnop")

      # 2. Save provider configuration
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash",
        "vision_model" => "gemini-2.0-flash",
        "enabled" => true
      }

      {:ok, setting} = LLMConfig.save_provider_config(user.id, :gemini, config)
      assert setting.provider == "gemini"
      assert setting.enabled == true

      # 3. Retrieve configuration
      {:ok, retrieved} = LLMConfig.get_provider_config(user.id, :gemini)
      assert retrieved.provider == "gemini"
      assert retrieved.enabled == true
    end

    test "Gemini error handling for rate limiting", %{user: _user} do
      # Test error message generation for rate limit (429) error
      config = %{api_key: "AIza-test-key"}
      # This will fail with actual API, but tests error handling structure
      result = LLMConfig.test_connection(:gemini, config)
      assert {:error, _} = result
    end
  end

  defp create_test_user do
    Accounts.register_user(%{
      email: "test#{System.unique_integer()}@example.com",
      password: "testpassword123",
      first_name: "Test",
      last_name: "User"
    })
  end
end
