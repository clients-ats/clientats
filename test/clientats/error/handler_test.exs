defmodule Clientats.Error.HandlerTest do
  use ExUnit.Case

  alias Clientats.Error.Handler

  describe "classify_error/1" do
    test "classifies Ecto.Changeset as validation error" do
      changeset = %Ecto.Changeset{}
      assert Handler.classify_error(changeset) == :validation_error
    end

    test "classifies not found error tuple" do
      assert Handler.classify_error({:error, :not_found}) == :not_found_error
    end

    test "classifies duplicate error tuple" do
      assert Handler.classify_error({:error, :duplicate}) == :duplicate_error
    end

    test "classifies unauthorized error tuple" do
      assert Handler.classify_error({:error, :unauthorized}) == :permission_error
    end

    test "classifies forbidden error tuple" do
      assert Handler.classify_error({:error, :forbidden}) == :permission_error
    end

    test "classifies unknown error" do
      assert Handler.classify_error({:error, :unknown}) == :unknown_error
    end

    test "classifies string as unknown error" do
      assert Handler.classify_error("error message") == :unknown_error
    end
  end

  describe "format_error/3" do
    test "formats validation error from changeset" do
      changeset = %Ecto.Changeset{
        errors: [email: {"is invalid", [validation: :format]}],
        data: %{}
      }

      result = Handler.format_error(changeset, :validation_error, %{})

      assert result.type == :validation_error
      assert result.message
      assert result.field == :email
      assert result.recovery
    end

    test "formats not found error" do
      result = Handler.format_error({:error, :not_found}, :not_found_error, %{})

      assert result.type == :not_found_error
      assert result.message == "Resource not found"
      assert result.recovery
      assert result.user_message
    end

    test "formats duplicate error" do
      result =
        Handler.format_error(
          {:error, :duplicate},
          :duplicate_error,
          %{resource: "job interest"}
        )

      assert result.type == :duplicate_error
      assert result.message == "Resource already exists"
      assert result.recovery
    end

    test "formats permission error" do
      result = Handler.format_error({:error, :unauthorized}, :permission_error, %{})

      assert result.type == :permission_error
      assert result.message == "Unauthorized access"
      assert result.recovery
    end

    test "formats unknown error" do
      result = Handler.format_error("unknown error", :unknown_error, %{})

      assert result.type == :unknown_error
      assert result.user_message == "Something went wrong. Please try again."
      assert result.recovery
    end
  end

  describe "handle_error/2" do
    test "handles changeset error and returns formatted error" do
      changeset = %Ecto.Changeset{
        errors: [email: {"is invalid", [validation: :format]}],
        data: %{}
      }

      {:ok, result} = Handler.handle_error(changeset, %{})

      assert result.type == :validation_error
      assert result.recovery
    end

    test "handles not found error" do
      {:ok, result} = Handler.handle_error({:error, :not_found}, %{})

      assert result.type == :not_found_error
    end

    test "handles permission error" do
      {:ok, result} = Handler.handle_error({:error, :unauthorized}, %{})

      assert result.type == :permission_error
    end

    test "includes context in error response" do
      changeset = %Ecto.Changeset{
        errors: [email: {"is invalid", [validation: :format]}],
        data: %{}
      }

      context = %{feature: :job_interests, action: :create}
      {:ok, result} = Handler.handle_error(changeset, context)

      assert result.recovery
    end
  end

  describe "get_flash_message/2" do
    test "returns user-friendly flash message for validation error" do
      message = Handler.get_flash_message(:validation_error)

      assert is_binary(message)
      assert String.length(message) > 0
    end

    test "returns message for network error" do
      message = Handler.get_flash_message(:network_error)

      assert is_binary(message)
    end

    test "returns message for storage error" do
      message = Handler.get_flash_message(:storage_error)

      assert is_binary(message)
    end
  end
end
