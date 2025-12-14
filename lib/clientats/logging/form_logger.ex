defmodule Clientats.Logging.FormLogger do
  @moduledoc """
  Logging handler for form submissions in LiveView.

  This module provides utilities to log form data for debugging purposes.
  """

  alias Clientats.Logging.Utils
  require Logger

  @doc """
  Log a form submission event.

  Usage in LiveView handle_event:

      def handle_event("save", %{"job_interest" => params} = data, socket) do
        FormLogger.log_form_event(socket, "save", data, provider_name: "job_interest")
        # ... rest of handler
      end

  Parameters:
  - socket: LiveView socket
  - event_type: "save", "validate", or custom event name
  - params: the form parameters
  - opts: keyword list with optional:
    - provider_name: name of the form/provider
    - user_id: can be extracted from socket.assigns.current_user
    - extra_data: additional metadata to log
  """
  def log_form_event(socket, event_type, params, opts \\ []) do
    try do
      user_id = extract_user_id(socket, opts)
      provider_name = Keyword.get(opts, :provider_name, "unknown")
      extra_data = Keyword.get(opts, :extra_data, %{})

      form_data = %{
        "event_type" => event_type,
        "form_name" => provider_name,
        "parameters" => sanitize_params(params),
        "extra_data" => extra_data
      }

      metadata = %{
        user_id: user_id,
        provider_name: provider_name
      }

      Utils.log_form_submission(form_data, metadata)
    rescue
      e ->
        Logger.error("Error logging form event: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Log a form validation event.

  Usage: FormLogger.log_form_validation(socket, "job_interest", params)
  """
  def log_form_validation(socket, provider_name, params, opts \\ []) do
    log_form_event(socket, "validate", params, [
      provider_name: provider_name | opts
    ])
  end

  @doc """
  Log a form submission (save) event.

  Usage: FormLogger.log_form_save(socket, "job_interest", params)
  """
  def log_form_save(socket, provider_name, params, opts \\ []) do
    log_form_event(socket, "save", params, [
      provider_name: provider_name | opts
    ])
  end

  @doc """
  Extract user_id from socket or options.
  """
  def extract_user_id(socket, opts) do
    case Keyword.fetch(opts, :user_id) do
      {:ok, user_id} ->
        user_id

      :error ->
        case socket.assigns do
          %{current_user: %{id: id}} -> id
          %{current_user: user} when is_map(user) -> Map.get(user, :id)
          _ -> nil
        end
    end
  end

  defp sanitize_params(params) do
    params
    |> sanitize_sensitive_fields()
  end

  defp sanitize_sensitive_fields(params) when is_map(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      sanitized_key = to_string(key)

      sanitized_value =
        cond do
          is_sensitive_field?(sanitized_key) ->
            "[REDACTED]"

          is_map(value) ->
            sanitize_sensitive_fields(value)

          is_list(value) ->
            Enum.map(value, fn item ->
              if is_map(item), do: sanitize_sensitive_fields(item), else: item
            end)

          true ->
            value
        end

      Map.put(acc, sanitized_key, sanitized_value)
    end)
  end

  defp sanitize_sensitive_fields(other), do: other

  defp is_sensitive_field?(field_name) do
    sensitive_keywords = [
      "password",
      "token",
      "secret",
      "api_key",
      "key",
      "credential",
      "auth",
      "apikey"
    ]

    Enum.any?(sensitive_keywords, fn keyword ->
      field_name |> String.downcase() |> String.contains?(keyword)
    end)
  end
end
