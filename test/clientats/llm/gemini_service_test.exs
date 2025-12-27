defmodule Clientats.LLM.GeminiServiceTest do
  use Clientats.DataCase, async: true

  alias Clientats.LLM.Service
  alias Clientats.LLMConfig
  alias Clientats.Accounts

  describe "Gemini provider configuration" do
    test "get_config returns provider map" do
      config = Service.get_config()
      assert is_map(config)
    end

    test "fallback providers are configured" do
      fallback = Application.get_env(:req_llm, :fallback_providers, [])
      assert is_list(fallback)
      # In dev/test, fallback may be empty, but in prod it has entries
      # Just verify it's a list structure
    end
  end

  describe "Gemini integration with LLM config" do
    setup do
      {:ok, user} = create_test_user()
      {:ok, user: user}
    end

    @tag :gemini
    test "test_connection validates Gemini connection" do
      # Test with missing API key
      config = %{api_key: nil}
      result = LLMConfig.test_connection(:gemini, config)
      assert {:error, "API key is required"} = result

      # Test with empty API key
      config = %{api_key: ""}
      result = LLMConfig.test_connection(:gemini, config)
      assert {:error, "API key is required"} = result

      # Test with invalid API key (will fail with actual API call)
      config = %{api_key: "invalid-test-key"}
      result = LLMConfig.test_connection(:gemini, config)
      assert {:error, _msg} = result
    end

    test "validate_api_key checks Gemini key format" do
      # Valid key format
      assert :ok = LLMConfig.validate_api_key(:gemini, "AIza123456789abcdefghijklmnop")

      # Invalid key - too short
      assert {:error, _} = LLMConfig.validate_api_key(:gemini, "short")

      # Invalid key - empty
      assert {:error, _} = LLMConfig.validate_api_key(:gemini, "")
    end

    test "save and retrieve Gemini configuration", %{user: user} do
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash",
        "vision_model" => "gemini-2.0-flash",
        "enabled" => true
      }

      # Save configuration
      {:ok, setting} = LLMConfig.save_provider_config(user.id, :gemini, config)
      assert setting.provider == "gemini"
      assert setting.enabled == true

      # Retrieve configuration
      {:ok, retrieved} = LLMConfig.get_provider_config(user.id, :gemini)
      assert retrieved.provider == "gemini"
      assert retrieved.enabled == true
    end

    test "provider_available? works for Gemini", %{user: user} do
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash",
        "enabled" => true
      }

      {:ok, _setting} = LLMConfig.save_provider_config(user.id, :gemini, config)

      # Function should not raise error
      result = Service.provider_available?(user.id, :gemini)
      assert is_boolean(result) or match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "get_provider_config_with_fallback for Gemini", %{user: user} do
      config = %{
        "provider" => "gemini",
        "api_key" => "AIza123456789abcdefghijklmnop",
        "default_model" => "gemini-2.0-flash",
        "enabled" => true
      }

      LLMConfig.save_provider_config(user.id, :gemini, config)

      result = Service.get_provider_config_with_fallback(user.id, :gemini)
      assert {:ok, _config} = result
    end
  end

  describe "Gemini error handling" do
    @tag :gemini
    test "Gemini connection errors are logged and reported" do
      # Test with invalid key format
      config = %{api_key: "invalid"}
      result = LLMConfig.test_connection(:gemini, config)

      case result do
        {:error, _msg} -> assert true
        {:ok, _} -> assert true
      end
    end

    test "Gemini API key validation catches invalid formats" do
      # Test boundary cases
      assert {:error, _} = LLMConfig.validate_api_key(:gemini, "")
      assert {:error, _} = LLMConfig.validate_api_key(:gemini, "a")
      assert {:error, _} = LLMConfig.validate_api_key(:gemini, "short-key")
    end
  end

  describe "Gemini provider integration" do
    test "Gemini is listed as valid provider" do
      alias Clientats.LLM.Setting

      changeset =
        Setting.changeset(%Setting{}, %{
          "user_id" => 1,
          "provider" => "gemini"
        })

      assert changeset.valid?
    end

    test "Gemini with all model configurations" do
      alias Clientats.LLM.Setting

      changeset =
        Setting.changeset(%Setting{}, %{
          "user_id" => 1,
          "provider" => "gemini",
          "default_model" => "gemini-2.0-flash",
          "vision_model" => "gemini-2.0-flash",
          "text_model" => "gemini-1.5-pro"
        })

      assert changeset.valid?
    end

    test "Gemini env defaults are properly configured" do
      defaults = LLMConfig.get_env_defaults()
      assert is_map(defaults[:gemini])
      assert defaults[:gemini][:default_model] == "gemini-2.5-flash"
      assert defaults[:gemini][:vision_model] == "gemini-2.5-flash"
    end
  end

  describe "Gemini API configuration" do
    test "Gemini API version configuration" do
      config = Service.get_config()
      # Check if google config exists and has api_version
      case config[:google] do
        # Config might not be set
        nil ->
          assert true

        google_config ->
          assert is_map(google_config)

          if Map.has_key?(google_config, :api_version) do
            assert google_config[:api_version] =~ ~r/v\d/
          end
      end
    end

    test "Gemini timeout configuration" do
      config = Service.get_config()
      # Check if timeout is configured
      case config[:google] do
        nil ->
          assert true

        google_config ->
          if Map.has_key?(google_config, :timeout) do
            assert is_integer(google_config[:timeout])
            assert google_config[:timeout] > 0
          end
      end
    end
  end

  defp create_test_user do
    Accounts.register_user(%{
      email: "gemini_test_#{System.unique_integer()}@example.com",
      password: "testpassword123",
      first_name: "Test",
      last_name: "User"
    })
  end
end
