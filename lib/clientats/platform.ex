defmodule Clientats.Platform do
  @moduledoc """
  Platform-specific utilities for determining application directories.

  This module provides functions to locate platform-appropriate directories
  for configuration and data storage following OS conventions:
  - Linux: ~/.config/clientats
  - macOS: ~/Library/Application Support/clientats
  - Windows: %APPDATA%/clientats
  """

  @doc """
  Returns the platform-specific configuration directory for the application.

  ## Examples

      iex> Clientats.Platform.config_dir()
      "/home/user/.config/clientats"  # On Linux
  """
  def config_dir do
    case :os.type() do
      {:unix, :darwin} ->
        # macOS: ~/Library/Application Support/clientats
        Path.join([System.user_home!(), "Library", "Application Support", "clientats"])

      {:unix, _} ->
        # Linux/Unix: ~/.config/clientats
        Path.join([System.user_home!(), ".config", "clientats"])

      {:win32, _} ->
        # Windows: %APPDATA%/clientats
        appdata =
          System.get_env("APPDATA") || Path.join([System.user_home!(), "AppData", "Roaming"])

        Path.join(appdata, "clientats")
    end
  end

  @doc """
  Returns the database path, either from DATABASE_PATH environment variable
  or a default location in the config directory.

  ## Options

    * `:ensure_dir` - If true, creates the directory if it doesn't exist (default: false)

  ## Examples

      iex> Clientats.Platform.database_path()
      "/home/user/.config/clientats/db/clientats.db"
  """
  def database_path(opts \\ []) do
    path = System.get_env("DATABASE_PATH") || default_database_path()

    if Keyword.get(opts, :ensure_dir, false) do
      ensure_dir(Path.dirname(path))
    end

    path
  end

  @doc """
  Returns the default database path within the config directory.
  """
  def default_database_path do
    Path.join([config_dir(), "db", "clientats.db"])
  end

  @doc """
  Ensures a directory exists, creating it if necessary.

  ## Examples

      iex> Clientats.Platform.ensure_dir("/path/to/dir")
      :ok
  """
  def ensure_dir(path) do
    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, reason} -> raise "Failed to create directory #{path}: #{inspect(reason)}"
    end
  end

  @doc """
  Ensures the config directory exists.
  """
  def ensure_config_dir do
    ensure_dir(config_dir())
  end

  @doc """
  Returns information about the current platform and configured paths.

  ## Examples

      iex> Clientats.Platform.info()
      %{
        platform: :linux,
        config_dir: "/home/user/.config/clientats",
        database_path: "/home/user/.config/clientats/db/clientats.db",
        database_from_env: false
      }
  """
  def info do
    platform =
      case :os.type() do
        {:unix, :darwin} -> :macos
        {:unix, _} -> :linux
        {:win32, _} -> :windows
      end

    %{
      platform: platform,
      config_dir: config_dir(),
      database_path: database_path(),
      database_from_env: System.get_env("DATABASE_PATH") != nil
    }
  end
end
