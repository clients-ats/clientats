defmodule Clientats.Audit.AuditLog do
  @moduledoc """
  Immutable audit log for tracking user actions and system events.

  All audit entries are write-once, immutable records used for compliance
  (GDPR, CCPA) and security auditing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__]}
  @primary_key {:id, :string, autogenerate: false}
  schema "audit_logs" do
    field :user_id, :string
    field :action, :string
    field :resource_type, :string
    field :resource_id, :string
    field :description, :string
    field :ip_address, :string
    field :user_agent, :string
    field :old_values, :map
    field :new_values, :map
    field :status, :string
    field :error_message, :string
    field :metadata, :map

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :user_id,
      :action,
      :resource_type,
      :resource_id,
      :description,
      :ip_address,
      :user_agent,
      :old_values,
      :new_values,
      :status,
      :error_message,
      :metadata
    ])
    |> validate_required([:action, :resource_type])
    |> validate_inclusion(:action, [
      "create",
      "update",
      "delete",
      "login",
      "logout",
      "api_key_created",
      "api_key_deleted",
      "export",
      "import",
      "permission_change",
      "config_change",
      "file_upload",
      "file_download"
    ])
    |> validate_inclusion(:status, ["success", "failure", "partial"])
    |> validate_immutable()
  end

  defp validate_immutable(changeset) do
    # Ensure we're only doing inserts, not updates
    case changeset.action do
      :insert -> changeset
      :update -> add_error(changeset, :base, "Audit logs are immutable")
      _ -> changeset
    end
  end

  @doc """
  Create audit entry for user action.
  """
  def create_entry(attrs) do
    # Generate UUID for primary key
    attrs = Map.put(attrs, :id, Ecto.UUID.generate())

    # Convert user_id and resource_id to strings if they're integers
    attrs =
      attrs
      |> convert_id_to_string(:user_id)
      |> convert_id_to_string(:resource_id)
      |> stringify_map_keys(:old_values)
      |> stringify_map_keys(:new_values)
      |> stringify_map_keys(:metadata)

    %__MODULE__{}
    |> changeset(attrs)
  end

  defp convert_id_to_string(attrs, key) do
    case Map.get(attrs, key) do
      nil -> attrs
      id when is_integer(id) -> Map.put(attrs, key, Integer.to_string(id))
      id when is_binary(id) -> attrs
      _ -> attrs
    end
  end

  defp stringify_map_keys(attrs, key) do
    case Map.get(attrs, key) do
      nil ->
        attrs

      map when is_map(map) ->
        stringified =
          map
          |> Enum.map(fn {k, v} -> {to_string(k), v} end)
          |> Enum.into(%{})

        Map.put(attrs, key, stringified)

      _ ->
        attrs
    end
  end

  @doc """
  Extract IP address from connection.
  """
  def extract_ip_address(conn) do
    case conn.remote_ip do
      {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
      {a, b, c, d, e, f, g, h} -> format_ipv6({a, b, c, d, e, f, g, h})
      _ -> "unknown"
    end
  end

  defp format_ipv6({a, b, c, d, e, f, g, h}) do
    "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
  end

  @doc """
  Extract user agent from connection.
  """
  def extract_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      _ -> "unknown"
    end
  end
end
