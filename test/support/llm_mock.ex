defmodule LLMMock do
  @moduledoc """
  Mock LLM responses for testing.

  Provides predefined responses for different job scraping scenarios.
  """

  @successful_response %{
    "company_name" => "Tech Corp Inc",
    "position_title" => "Senior Software Engineer",
    "job_description" =>
      "We are looking for an experienced Software Engineer to join our growing team. You will work on cutting-edge technologies and help build our next-generation platform.",
    "location" => "San Francisco, CA",
    "work_model" => "hybrid",
    "salary_min" => 120_000,
    "salary_max" => 150_000,
    "currency" => "USD",
    "salary_period" => "yearly",
    "skills" => ["Elixir", "Phoenix", "PostgreSQL", "AWS"],
    "posting_date" => "2024-03-15",
    "employment_type" => "full_time",
    "seniority_level" => "senior"
  }

  @linkedin_response %{
    "company_name" => "LinkedIn Corporation",
    "position_title" => "Staff Software Engineer - Backend",
    "job_description" =>
      "Build the next generation of LinkedIn's professional networking platform.",
    "location" => "Sunnyvale, CA",
    "work_model" => "hybrid",
    "salary_min" => 150_000,
    "salary_max" => 180_000,
    "currency" => "USD",
    "salary_period" => "yearly",
    "skills" => ["Java", "Spring Boot", "Kafka", "Microservices"],
    "posting_date" => "2024-04-01",
    "employment_type" => "full_time",
    "seniority_level" => "staff"
  }

  @indeed_response %{
    "company_name" => "Indeed Inc",
    "position_title" => "Software Engineer - Search Team",
    "job_description" => "Work on Indeed's job search and recommendation algorithms.",
    "location" => "Austin, TX",
    "work_model" => "remote",
    "salary_min" => 110_000,
    "salary_max" => 140_000,
    "currency" => "USD",
    "salary_period" => "yearly",
    "skills" => ["Python", "Machine Learning", "Elasticsearch"],
    "posting_date" => "2024-03-20",
    "employment_type" => "full_time",
    "seniority_level" => "mid"
  }

  @minimal_response %{
    "company_name" => "Test Company",
    "position_title" => "Test Engineer",
    "job_description" => "Test job description."
  }

  @doc """
  Get a mock response based on URL and mode.
  """
  def get_mock_response(url, mode) do
    cond do
      String.contains?(url, "linkedin.com") -> @linkedin_response
      String.contains?(url, "indeed.com") -> @indeed_response
      mode == :specific -> @successful_response
      true -> @successful_response
    end
  end

  @doc """
  Get minimal response (only required fields).
  """
  def get_minimal_response do
    @minimal_response
  end

  @doc """
  Get successful response with all fields.
  """
  def get_successful_response do
    @successful_response
  end
end
