defmodule ClientatsWeb.Versioning.APIVersion do
  @moduledoc """
  API versioning constants and utilities.

  Defines the supported API versions and provides utilities for version management
  and deprecation tracking across the application.
  """

  @current_version "v1"
  @supported_versions ["v1", "v2"]
  @deprecated_versions []

  @doc """
  Get the current/default API version.
  """
  def current_version, do: @current_version

  @doc """
  Get all supported API versions.
  """
  def supported_versions, do: @supported_versions

  @doc """
  Get list of deprecated versions.
  """
  def deprecated_versions, do: @deprecated_versions

  @doc """
  Check if a version is supported.
  """
  def supported?(version) when is_binary(version) do
    version in @supported_versions
  end

  @doc """
  Check if a version is deprecated.
  """
  def deprecated?(version) when is_binary(version) do
    version in @deprecated_versions
  end

  @doc """
  Get version info including deprecation status and migration info.
  """
  def version_info(version) when is_binary(version) do
    case version do
      "v1" ->
        %{
          version: "v1",
          status: :active,
          deprecated: false,
          created_date: "2025-01-01",
          sunset_date: nil,
          migration_guide: nil
        }

      "v2" ->
        %{
          version: "v2",
          status: :beta,
          deprecated: false,
          created_date: "2025-12-15",
          sunset_date: nil,
          migration_guide: "https://docs.example.com/api/migration/v1-to-v2"
        }

      _ ->
        nil
    end
  end

  @doc """
  Get deprecation timeline for a version.
  """
  def deprecation_timeline(version) when is_binary(version) do
    case version do
      _ ->
        nil
    end
  end
end
