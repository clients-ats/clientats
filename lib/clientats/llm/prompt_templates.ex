defmodule Clientats.LLM.PromptTemplates do
  @moduledoc """
  LLM prompt templates for job data extraction.

  Provides optimized prompts for different extraction modes and job board types.
  """

  @doc """
  Build a job extraction prompt based on content, URL, and mode.
  """
  def build_job_extraction_prompt(content, url, mode) do
    source = detect_source(url)

    case mode do
      :specific -> specific_mode_prompt(content, source)
      :generic -> generic_mode_prompt(content, source)
    end
  end

  @doc """
  Build a job extraction prompt for image-based extraction (multimodal).

  ## Parameters
    - _image_path: Path to the screenshot image (the image is passed to LLM, path is for context)
    - url: Original URL for context
    - mode: :specific or :generic extraction mode
  """
  def build_image_extraction_prompt(_image_path, url, mode) do
    source = detect_source(url)

    case mode do
      :specific -> image_specific_mode_prompt(source)
      :generic -> image_generic_mode_prompt(source)
    end
  end

  @doc """
  System prompt for job extraction tasks.
  """
  def system_prompt do
    """
    You are an expert job posting analysis system. Your task is to extract structured 
    information from job postings with high accuracy. Always return valid JSON 
    with the specified fields. If information is not available, use null values.

    Guidelines:
    - Extract exact text when possible
    - Normalize job titles and company names
    - Infer missing information when reasonable
    - Handle different date formats consistently
    - Return clean, well-formatted JSON only
    """
  end

  @doc """
  Specific mode prompt optimized for known job boards.
  """
  def specific_mode_prompt(content, source) do
    job_board = job_board_name(source)

    """
    Extract job posting information from this #{job_board} content.

    Content:
    ```
    #{truncate_content(content)}
    ```

    Extract the following fields:
    - company_name (required)
    - position_title (required) 
    - job_description (required, full text)
    - location (city, state/country)
    - work_model (remote, hybrid, or on_site)
    - salary_min (numeric, if available)
    - salary_max (numeric, if available)
    - currency (USD, EUR, etc., if available)
    - salary_period (hourly, yearly, etc., if available)
    - skills (array of required skills)
    - posting_date (YYYY-MM-DD format if available)
    - application_deadline (YYYY-MM-DD format if available)
    - employment_type (full_time, part_time, contract, internship)
    - seniority_level (entry, mid, senior, executive if available)

    Important: Return ONLY valid JSON with the extracted data.
    """
  end

  @doc """
  Generic mode prompt for any job posting content.
  """
  def generic_mode_prompt(content, source) do
    job_board = job_board_name(source)

    """
    Extract job posting information from this content. The source is: #{job_board}

    Content:
    ```
    #{truncate_content(content)}
    ```

    Extract the following fields:
    - company_name (required) - The hiring company name
    - position_title (required) - The job title
    - job_description (required) - Full job description text
    - location - Where the job is located (city, state/country)
    - work_model - remote, hybrid, or on_site
    - salary_min - Minimum salary if mentioned (numeric)
    - salary_max - Maximum salary if mentioned (numeric)
    - currency - Currency if salary mentioned (USD, EUR, etc.)
    - salary_period - hourly, yearly, etc. if salary mentioned
    - skills - Array of required skills/technologies
    - posting_date - When job was posted (YYYY-MM-DD if available)
    - application_deadline - Application deadline (YYYY-MM-DD if available)
    - employment_type - full_time, part_time, contract, or internship
    - seniority_level - entry, mid, senior, or executive if mentioned

    Important rules:
    1. Always return valid JSON
    2. Required fields must be present
    3. If information is not available, use null
    4. Extract exact text when possible
    5. Normalize company names and job titles
    """
  end

  @doc """
  Prompt for extracting company information from job postings.
  """
  def company_info_prompt(content) do
    """
    Extract detailed company information from this job posting:

    #{truncate_content(content)}

    Fields to extract:
    - company_name
    - industry
    - company_size
    - founded_year
    - headquarters_location
    - company_description
    - benefits (array)
    - culture_highlights (array)

    Return only JSON.
    """
  end

  @doc """
  Prompt for salary analysis and benchmarking.
  """
  def salary_analysis_prompt(job_data, location) do
    """
    Analyze this job posting salary information:

    Job: #{job_data.position_title}
    Location: #{location}
    Description: #{truncate_content(job_data.job_description)}

    Provide:
    - salary_range_analysis (low/medium/high for this role and location)
    - market_comparison (how this compares to market rates)
    - salary_negotiation_tips (3-5 bullet points)
    - additional_benefits_analysis

    Return only JSON.
    """
  end

  @doc """
  Image-specific mode prompt for known job boards.
  """
  def image_specific_mode_prompt(source) do
    job_board = job_board_name(source)

    """
    Extract job posting information from this #{job_board} screenshot.

    Please analyze the visible job posting on the screen and extract:
    - company_name (required) - The hiring company name
    - position_title (required) - The job title displayed
    - job_description (required) - The full job description visible
    - location - Job location (city, state/country)
    - work_model - remote, hybrid, or on_site based on what's shown
    - salary_min - Minimum salary if visible
    - salary_max - Maximum salary if visible
    - currency - Currency symbol or code if salary is shown
    - salary_period - hourly, yearly, etc. if salary period is shown
    - skills - Array of required skills/technologies listed
    - posting_date - When the job was posted if visible
    - application_deadline - Application deadline if visible
    - employment_type - full_time, part_time, contract, or internship
    - seniority_level - entry, mid, senior, or executive if mentioned

    Return ONLY valid JSON with the extracted data. Use null for missing fields.
    """
  end

  @doc """
  Image generic mode prompt for any job posting screenshot.
  """
  def image_generic_mode_prompt(_source) do
    """
    Analyze this screenshot of a job posting and extract structured information.

    Based on what you see in the image, extract these fields:
    - company_name (required) - The hiring company name
    - position_title (required) - The job title
    - job_description (required) - Full job description text
    - location - Where the job is located
    - work_model - remote, hybrid, or on_site
    - salary_min - Minimum salary if mentioned
    - salary_max - Maximum salary if mentioned
    - currency - Currency (USD, EUR, etc.)
    - salary_period - hourly, yearly, etc.
    - skills - Array of required skills
    - posting_date - When job was posted (YYYY-MM-DD format if possible)
    - application_deadline - Application deadline (YYYY-MM-DD format if possible)
    - employment_type - full_time, part_time, contract, or internship
    - seniority_level - entry, mid, senior, or executive if mentioned

    Important:
    1. Extract only what is visible in the image
    2. Return only valid JSON
    3. Use null for fields that are not visible
    4. Extract salary ranges exactly as shown
    5. Preserve original job description text
    """
  end

  @doc """
  Prompt for generating a cover letter.
  """
  def build_cover_letter_prompt(job_description, user_context) do
    """
    Generate a professional cover letter for the following job:

    Job Description:
    #{truncate_content(job_description)}

    Candidate Profile:
    Name: #{user_context.first_name} #{user_context.last_name}
    Resume/Experience:
    #{user_context.resume_text || "Not provided"}

    Instructions:
    - Write a compelling cover letter tailored to this specific job and company.
    - Highlight relevant skills from the candidate's profile that match the job requirements.
    - Keep it professional, concise, and engaging.
    - Use a standard cover letter format.
    - Do not include placeholders like "[Your Name]" - use the candidate's name provided.
    - If specific details (like hiring manager name) are missing, use generic professional greetings.

    Return ONLY the cover letter text, no other commentary.
    """
  end

  # Private helper functions

  defp detect_source(url) do
    cond do
      String.contains?(url, "linkedin.com") -> :linkedin
      String.contains?(url, "indeed.com") -> :indeed
      String.contains?(url, "glassdoor.com") -> :glassdoor
      String.contains?(url, "angel.co") -> :angel
      String.contains?(url, "lever.co") -> :lever
      String.contains?(url, "greenhouse.io") -> :greenhouse
      true -> :unknown
    end
  end

  defp job_board_name(:linkedin), do: "LinkedIn"
  defp job_board_name(:indeed), do: "Indeed"
  defp job_board_name(:glassdoor), do: "Glassdoor"
  defp job_board_name(:angel), do: "AngelList"
  defp job_board_name(:lever), do: "Lever"
  defp job_board_name(:greenhouse), do: "Greenhouse"
  defp job_board_name(_), do: "unknown job board"

  defp truncate_content(content) when byte_size(content) > 8000 do
    truncated = String.slice(content, 0, 8000)
    truncated <> "... [truncated]"
  end

  defp truncate_content(content), do: content
end
