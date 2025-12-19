defmodule ClientatsWeb.JobScraperController do
  @moduledoc """
  API Controller for job scraping functionality.

  Provides REST endpoints for extracting job data from URLs using LLM services.
  Supports API versioning (v1, v2) with deprecation headers and metadata.
  """

  use ClientatsWeb, :controller

  alias Clientats.LLM.Service
  alias Clientats.LLM.ErrorHandler
  alias Clientats.Jobs
  alias Clientats.Accounts
  alias ClientatsWeb.Versioning.APIVersion

  @doc """
  Scrape job data from URL.

  ## Parameters
    - url: Job posting URL (required)
    - mode: Extraction mode (:specific or :generic, default: :generic)
    - provider: LLM provider to use (optional)
    - save: Whether to automatically create job interest (default: false)

  ## Returns
    - 200: Success with extracted job data
    - 400: Invalid request
    - 401: Unauthorized
    - 429: Rate limited
    - 500: Server error
  """
  def scrape(conn, params) do
    # Extract parameters with defaults
    url = params["url"]
    mode = params["mode"] || "generic"
    provider = params["provider"]
    save = params["save"] || "false"

    # Validate authentication
    case ensure_authenticated(conn) do
      conn when conn.halted ->
        conn

      {:ok, current_user} ->
        case do_scrape(url, mode, provider, save, current_user) do
          {:ok, result} ->
            version = get_api_version(conn)

            conn
            |> put_status(:ok)
            |> put_resp_header("api-version", version)
            |> json(%{
              success: true,
              data: result,
              message: "Job data extracted successfully",
              _api: %{
                version: version,
                supported_versions: APIVersion.supported_versions()
              }
            })

          {:error, reason} ->
            version = get_api_version(conn)

            conn
            |> put_status(:bad_request)
            |> put_resp_header("api-version", version)
            |> json(%{
              success: false,
              error: reason,
              message: "Job scraping failed",
              _api: %{
                version: version,
                supported_versions: APIVersion.supported_versions()
              }
            })
        end
    end
  end

  @doc """
  Get available LLM providers and their status.
  """
  def providers(conn, _params) do
    with {:ok, _current_user} <- ensure_authenticated(conn) do
      providers = Service.get_available_providers()
      version = get_api_version(conn)

      conn
      |> put_status(:ok)
      |> put_resp_header("api-version", version)
      |> json(%{
        success: true,
        providers: providers,
        message: "Available LLM providers",
        _api: %{
          version: version,
          supported_versions: APIVersion.supported_versions()
        }
      })
    end
  end

  @doc """
  Get LLM service configuration.
  """
  def config(conn, _params) do
    with {:ok, _current_user} <- ensure_authenticated(conn) do
      config = Service.get_config()
      version = get_api_version(conn)

      conn
      |> put_status(:ok)
      |> put_resp_header("api-version", version)
      |> json(%{
        success: true,
        config: config,
        message: "Current LLM configuration",
        _api: %{
          version: version,
          supported_versions: APIVersion.supported_versions()
        }
      })
    end
  end

  # Private functions

  defp get_api_version(conn) do
    # Extract version from request path (e.g., /api/v1/scrape_job -> v1)
    case String.split(conn.request_path, "/") do
      [_, "api", "v1" | _] -> "v1"
      [_, "api", "v2" | _] -> "v2"
      # Default to v1 for legacy /api/* routes
      [_, "api" | _] -> "v1"
      _ -> APIVersion.current_version()
    end
  end

  defp ensure_authenticated(conn) do
    case Accounts.get_authenticated_user(conn) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized", message: "Authentication required"})
        |> halt()

      user ->
        {:ok, user}
    end
  end

  defp do_scrape(url, mode, provider, save, current_user) do
    # Validate URL
    case validate_scrape_request(url) do
      {:error, reason} ->
        {:error, reason}

      :ok ->
        # Extract job data
        extraction_mode = String.to_atom(mode || "generic")
        provider_atom = parse_provider(provider)

        case Service.extract_job_data_from_url(url, extraction_mode, provider: provider_atom) do
          {:ok, job_data} ->
            if save == "true" do
              create_job_interest_from_data(job_data, current_user)
            else
              {:ok, job_data}
            end

          {:error, reason} ->
            {:error, map_error_reason(reason)}
        end
    end
  end

  defp validate_scrape_request(url) do
    cond do
      !url || String.trim(url) == "" ->
        {:error, "URL is required"}

      !String.starts_with?(url, "http://") && !String.starts_with?(url, "https://") ->
        {:error, "URL must start with http:// or https://"}

      byte_size(url) > 2000 ->
        {:error, "URL is too long (max 2000 characters)"}

      true ->
        :ok
    end
  end

  defp parse_provider(nil), do: nil
  defp parse_provider("openai"), do: :openai
  defp parse_provider("anthropic"), do: :anthropic
  defp parse_provider("mistral"), do: :mistral
  defp parse_provider(_), do: nil

  defp map_error_reason(reason) do
    ErrorHandler.user_friendly_message(reason)
  end

  defp create_job_interest_from_data(job_data, current_user) do
    job_interest_params = %{
      user_id: current_user.id,
      company_name: job_data.company_name,
      position_title: job_data.position_title,
      job_description: job_data.job_description,
      job_url: job_data.source_url || job_data.url,
      location: job_data.location,
      work_model: job_data.work_model,
      status: "interested",
      priority: "medium",
      notes: "Imported via LLM job scraper"
    }

    case Jobs.create_job_interest(job_interest_params) do
      {:ok, job_interest} ->
        {:ok, Map.put(job_data, :job_interest_id, job_interest.id)}

      {:error, changeset} ->
        {:error, "Failed to create job interest: " <> inspect(changeset.errors)}
    end
  end
end
