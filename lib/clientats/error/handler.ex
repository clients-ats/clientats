defmodule Clientats.Error.Handler do
  @moduledoc """
  Centralizes error handling with context-aware recovery suggestions.

  Provides intelligent error messages and recovery actions based on:
  - Error type and cause
  - User experience level
  - Current context and feature
  - Previous error patterns
  """

  require Logger

  alias Clientats.Help.ContextHelper

  @doc """
  Handle an error with context and return user-friendly response.

  Returns:
    {:ok, formatted_error} - Error with recovery suggestions
    {:error, reason} - When error handling itself fails
  """
  def handle_error(error, context \\ %{}) do
    Logger.error("Error in context: #{inspect(context)}", error: inspect(error))

    error_type = classify_error(error)
    formatted = format_error(error, error_type, context)

    {:ok, formatted}
  rescue
    e ->
      Logger.error("Error handler failed", error: inspect(e))
      {:error, :handler_error}
  end

  @doc """
  Classify error type for recovery suggestions.
  """
  def classify_error(error) do
    case error do
      %Ecto.Changeset{} ->
        :validation_error

      {:error, :not_found} ->
        :not_found_error

      {:error, :duplicate} ->
        :duplicate_error

      {:error, :unauthorized} ->
        :permission_error

      {:error, :forbidden} ->
        :permission_error

      %File.Error{} ->
        :storage_error

      _other ->
        # Check if it's a database connection error
        if is_db_error(error), do: :network_error, else: :unknown_error
    end
  end

  defp is_db_error(error) do
    case error do
      %{__struct__: mod} when mod == DBConnection.Error -> true
      _ -> false
    end
  rescue
    _e -> false
  end

  @doc """
  Format error with user-friendly message and recovery options.
  """
  def format_error(%Ecto.Changeset{} = changeset, :validation_error, context) do
    {field, {message, _}} = Enum.at(changeset.errors, 0) || {:unknown, {"Invalid input", []}}

    recovery_context =
      Map.merge(context, %{
        field: field,
        message: message
      })

    recovery = ContextHelper.get_error_recovery(:validation_error, recovery_context)

    %{
      type: :validation_error,
      message: validation_message(changeset),
      field: field,
      error_details: changeset.errors,
      recovery: recovery,
      user_message: recovery[:message]
    }
  end

  def format_error({:error, :not_found}, :not_found_error, context) do
    recovery = ContextHelper.get_error_recovery(:not_found_error, context)

    %{
      type: :not_found_error,
      message: "Resource not found",
      recovery: recovery,
      user_message: recovery[:message]
    }
  end

  def format_error({:error, :duplicate}, :duplicate_error, context) do
    recovery = ContextHelper.get_error_recovery(:duplicate_error, context)

    %{
      type: :duplicate_error,
      message: "Resource already exists",
      recovery: recovery,
      user_message: recovery[:message]
    }
  end

  def format_error({:error, :unauthorized}, :permission_error, context) do
    recovery = ContextHelper.get_error_recovery(:permission_error, context)

    %{
      type: :permission_error,
      message: "Unauthorized access",
      recovery: recovery,
      user_message: recovery[:message]
    }
  end

  def format_error(error, :network_error, context) when is_map(error) do
    recovery = ContextHelper.get_error_recovery(:network_error, context)
    message = Map.get(error, :message) || "Connection error"

    %{
      type: :network_error,
      message: "Database connection error",
      details: message,
      recovery: recovery,
      user_message: recovery[:message],
      retryable: true
    }
  end

  def format_error(%File.Error{} = error, :storage_error, context) do
    recovery = ContextHelper.get_error_recovery(:storage_error, context)

    %{
      type: :storage_error,
      message: "File operation error",
      details: error.reason,
      recovery: recovery,
      user_message: recovery[:message]
    }
  end

  def format_error(error, :unknown_error, _context) do
    %{
      type: :unknown_error,
      message: "An unexpected error occurred",
      details: inspect(error),
      user_message: "Something went wrong. Please try again.",
      recovery: %{
        title: "Error",
        message: "Please try again or contact support",
        actions: [
          %{label: "Retry", icon: "refresh"},
          %{label: "Contact support", icon: "help"}
        ]
      }
    }
  end

  # Private Helpers

  defp validation_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} ->
      "#{field} #{message}"
    end)
    |> Enum.join(", ")
  end

  @doc """
  Get context-aware error message for live view rendering.
  """
  def get_flash_message(error_type, context \\ %{}) do
    recovery = ContextHelper.get_error_recovery(error_type, context)
    recovery[:message]
  end
end
