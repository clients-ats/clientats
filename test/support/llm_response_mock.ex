defmodule LLMResponseMock do
  @moduledoc """
  Mock LLM response generator for testing job import wizard.

  Generates realistic and various LLM responses for testing different scenarios:
  - Successful extractions with complete data
  - Edge cases with malformed or incomplete data
  - Responses with missing optional fields
  - Responses that would trigger retry logic
  """

  @doc """
  Generate a mock LLM response based on a screenshot scenario.

  Returns a JSON string that represents an LLM extraction response.
  """
  def generate_response(scenario \\ :successful) do
    case scenario do
      :successful -> successful_response()
      :minimal -> minimal_response()
      :malformed_json -> malformed_json_response()
      :missing_fields -> missing_fields_response()
      :invalid_salary -> invalid_salary_response()
      :partial_data -> partial_data_response()
      :empty_response -> empty_response()
      :error -> error_response()
      _ -> successful_response()
    end
  end

  @doc """
  Get a mock response as a parsed map instead of JSON string.
  """
  def generate_response_map(scenario \\ :successful) do
    response = generate_response(scenario)

    case Jason.decode(response) do
      {:ok, map} -> map
      {:error, _} -> %{}
    end
  end

  @doc """
  Generate responses for multiple scenarios to test fallback chains.
  """
  def generate_fallback_chain do
    [
      {:ok, generate_response(:successful)},
      {:ok, generate_response(:minimal)},
      {:ok, generate_response(:partial_data)}
    ]
  end

  # Private helper functions - response generators

  defp successful_response do
    Jason.encode!(%{
      "company_name" => "TechCorp Industries",
      "position_title" => "Senior Software Engineer",
      "job_description" => "Join our team to build scalable systems...",
      "location" => "San Francisco, CA",
      "work_model" => "hybrid",
      "salary_min" => 150_000,
      "salary_max" => 200_000,
      "currency" => "USD",
      "salary_period" => "yearly",
      "skills" => ["Elixir", "Phoenix", "PostgreSQL", "AWS"],
      "posting_date" => "2024-12-01",
      "application_deadline" => "2024-12-31",
      "employment_type" => "full_time",
      "seniority_level" => "senior"
    })
  end

  defp minimal_response do
    Jason.encode!(%{
      "company_name" => "Test Company",
      "position_title" => "Software Engineer",
      "job_description" => "Seeking a software engineer."
    })
  end

  defp malformed_json_response do
    # This represents what the system would see when LLM returns invalid JSON
    """
    {
      "company_name": "BadJSON Corp",
      "position_title": "Engineer",
      "job_description": "Some description with "unescaped quotes"
    """
  end

  defp missing_fields_response do
    Jason.encode!(%{
      "company_name" => "StartupXYZ",
      "position_title" => "Junior Developer",
      # Missing job_description - required field
      "location" => "Remote",
      "work_model" => "remote",
      "employment_type" => "full_time"
    })
  end

  defp invalid_salary_response do
    Jason.encode!(%{
      "company_name" => "InvalidSalary Inc",
      "position_title" => "Data Scientist",
      "job_description" => "Process large datasets...",
      "location" => "New York, NY",
      "work_model" => "on_site",
      # Invalid salary format
      "salary_min" => "not_a_number",
      "salary_max" => "also_invalid",
      "currency" => "USD",
      "salary_period" => "yearly",
      "employment_type" => "full_time"
    })
  end

  defp partial_data_response do
    Jason.encode!(%{
      "company_name" => "PartialCorp",
      "position_title" => "Product Manager",
      "job_description" => "Lead product strategy and development...",
      "location" => "Boston, MA",
      "work_model" => "hybrid",
      "salary_min" => 120_000,
      # salary_max missing - only min provided
      "currency" => "USD",
      "salary_period" => "yearly",
      "skills" => ["Product Strategy", "Analytics"],
      "employment_type" => "full_time"
      # application_deadline, posting_date, seniority_level missing
    })
  end

  defp empty_response do
    Jason.encode!(%{})
  end

  defp error_response do
    Jason.encode!(%{
      "error" => "Unable to process image",
      "error_code" => "INVALID_IMAGE"
    })
  end
end
