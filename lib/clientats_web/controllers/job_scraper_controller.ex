defmodule ClientatsWeb.JobScraperController do
  @moduledoc """
  API Controller for job scraping functionality.
  
  Provides REST endpoints for extracting job data from URLs using LLM services.
  """
  
  use ClientatsWeb, :controller
  
  alias Clientats.LLM.Service
  alias Clientats.Jobs
  alias Clientats.Accounts
  
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
  def scrape(conn, %{"url" => url, "mode" => mode, "provider" => provider, "save" => save}) do
    # Validate authentication
    with {:ok, current_user} <- ensure_authenticated(conn),
         {:ok, result} <- do_scrape(url, mode, provider, save, current_user) do
      
      conn
      |> put_status(:ok)
      |> json(%{
           success: true,
           data: result,
           message: "Job data extracted successfully"
         })
    end
  end
  
  @doc """
  Get available LLM providers and their status.
  """
  def providers(conn, _params) do
    with {:ok, current_user} <- ensure_authenticated(conn) do
      providers = Service.get_available_providers()
      
      conn
      |> put_status(:ok)
      |> json(%{
           success: true,
           providers: providers,
           message: "Available LLM providers"
         })
    end
  end
  
  @doc """
  Get LLM service configuration.
  """
  def config(conn, _params) do
    with {:ok, current_user} <- ensure_authenticated(conn) do
      config = Service.get_config()
      
      conn
      |> put_status(:ok)
      |> json(%{
           success: true,
           config: config,
           message: "Current LLM configuration"
         })
    end
  end
  
  # Private functions
  
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
      {:error, reason} -> {:error, reason}
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
          
          {:error, reason} -> {:error, map_error_reason(reason)}
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
  
  defp map_error_reason({:llm_error, message}), do: "LLM Error: " <> message
  defp map_error_reason({:fetch_error, message}), do: "Fetch Error: " <> message
  defp map_error_reason({:parse_error, message}), do: "Parse Error: " <> message
  defp map_error_reason(:content_too_large), do: "Content too large for processing"
  defp map_error_reason(:invalid_url), do: "Invalid URL format"
  defp map_error_reason(:invalid_content), do: "Invalid content for processing"
  defp map_error_reason(:rate_limited), do: "Rate limited - please try again later"
  defp map_error_reason(:auth_error), do: "Authentication error with LLM provider"
  defp map_error_reason(:timeout), do: "Request timeout - please try again"
  defp map_error_reason(:all_providers_failed), do: "All LLM providers failed"
  defp map_error_reason(reason), do: "Error: " <> to_string(reason)
  
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