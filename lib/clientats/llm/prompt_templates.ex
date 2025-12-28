defmodule Clientats.LLM.PromptTemplates do
  @moduledoc """
  LLM prompt templates for job data extraction and cover letter generation.

  Provides optimized prompts for different extraction modes, job board types,
  and customizable cover letter generation with variable substitution.
  """

  # Prompt variables available for custom cover letter prompts
  @prompt_variables [
    %{
      name: "{{JOB_DESCRIPTION}}",
      description: "The full job description text",
      example: "We are looking for a Senior Software Engineer with 5+ years of experience..."
    },
    %{
      name: "{{CANDIDATE_NAME}}",
      description: "Candidate's full name (first + last)",
      example: "John Smith"
    },
    %{
      name: "{{CANDIDATE_FIRST_NAME}}",
      description: "Candidate's first name only",
      example: "John"
    },
    %{
      name: "{{CANDIDATE_LAST_NAME}}",
      description: "Candidate's last name only",
      example: "Smith"
    },
    %{
      name: "{{RESUME_TEXT}}",
      description: "Extracted resume content (if available)",
      example: "Professional Summary: Experienced software engineer with expertise in..."
    },
    %{
      name: "{{COMPANY_NAME}}",
      description: "Company name from job application (if available)",
      example: "Acme Corporation"
    },
    %{
      name: "{{POSITION_TITLE}}",
      description: "Job position title (if available)",
      example: "Senior Software Engineer"
    }
  ]

  # Prompt injection patterns to block
  @injection_patterns [
    ~r/ignore\s+(previous|above|all)\s+instructions/i,
    ~r/disregard\s+(previous|all)/i,
    ~r/forget\s+(everything|all)/i,
    ~r/you\s+are\s+now/i,
    ~r/new\s+instructions/i,
    ~r/system\s*:/i,
    ~r/assistant\s*:/i
  ]

  @doc """
  Get available prompt variables for custom cover letter prompts.
  Returns a list of variable maps with name, description, and example.
  """
  def get_available_variables, do: @prompt_variables

  @doc """
  Get the default cover letter prompt template with variable placeholders.
  This template can be used as a starting point for customization.
  """
  def get_default_template do
    """
    Generate a professional cover letter for the following job:

    Job Description:
    {{JOB_DESCRIPTION}}

    Candidate Profile:
    Name: {{CANDIDATE_NAME}}
    Resume/Experience:
    {{RESUME_TEXT}}

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

  Supports custom prompts with variable substitution. If custom_prompt is provided,
  it will be validated and used instead of the default template.

  ## Parameters
    - job_description: The job posting text
    - user_context: Map with first_name, last_name, resume_text, company_name, position_title
    - custom_prompt: Optional custom prompt template with variables (default: nil)
    - opts: Additional options (currently unused, for future extension)

  ## Returns
    - String prompt ready for LLM
  """
  def build_cover_letter_prompt(job_description, user_context, custom_prompt \\ nil, _opts \\ []) do
    case custom_prompt do
      nil ->
        build_default_cover_letter_prompt(job_description, user_context)

      "" ->
        build_default_cover_letter_prompt(job_description, user_context)

      custom ->
        case validate_custom_prompt(custom) do
          {:ok, _} ->
            variables =
              user_context
              |> Map.put(:job_description, job_description)
              |> Map.put_new(:company_name, "")
              |> Map.put_new(:position_title, "")

            substitute_variables(custom, variables)

          {:error, _reason} ->
            # Fall back to default on validation error
            build_default_cover_letter_prompt(job_description, user_context)
        end
    end
  end

  @doc """
  Prompt for generating a cover letter when the resume is provided as a file (multimodal).

  Supports custom prompts with variable substitution. If custom_prompt is provided,
  it will be validated and used instead of the default template.

  ## Parameters
    - job_description: The job posting text
    - user_context: Map with first_name, last_name, company_name, position_title (resume is attached as file)
    - custom_prompt: Optional custom prompt template with variables (default: nil)
    - opts: Additional options (currently unused, for future extension)

  ## Returns
    - String prompt ready for LLM (resume will be attached separately as multimodal content)
  """
  def build_multimodal_cover_letter_prompt(
        job_description,
        user_context,
        custom_prompt \\ nil,
        _opts \\ []
      ) do
    case custom_prompt do
      nil ->
        build_default_multimodal_cover_letter_prompt(job_description, user_context)

      "" ->
        build_default_multimodal_cover_letter_prompt(job_description, user_context)

      custom ->
        case validate_custom_prompt(custom) do
          {:ok, _} ->
            variables =
              user_context
              |> Map.put(:job_description, job_description)
              |> Map.put_new(:company_name, "")
              |> Map.put_new(:position_title, "")
              |> Map.put(:resume_text, "[Resume attached as file]")

            substitute_variables(custom, variables)

          {:error, _reason} ->
            # Fall back to default on validation error
            build_default_multimodal_cover_letter_prompt(job_description, user_context)
        end
    end
  end

  # Private helper functions

  # Default cover letter prompts (extracted from original implementations)

  defp build_default_cover_letter_prompt(job_description, user_context) do
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

  defp build_default_multimodal_cover_letter_prompt(job_description, user_context) do
    """
    Generate a professional cover letter for the following job.
    The candidate's resume is attached as a file.

    Job Description:
    #{truncate_content(job_description)}

    Candidate Profile:
    Name: #{user_context.first_name} #{user_context.last_name}

    Instructions:
    - Analyze the attached resume and write a compelling cover letter tailored to this job and company.
    - Highlight relevant skills from the attached resume that match the job requirements.
    - Keep it professional, concise, and engaging.
    - Use a standard cover letter format.
    - Do not include placeholders like "[Your Name]" - use the candidate's name provided.
    - If specific details (like hiring manager name) are missing, use generic professional greetings.

    Return ONLY the cover letter text, no other commentary.
    """
  end

  # Custom prompt validation

  defp validate_custom_prompt(prompt) when is_binary(prompt) do
    with :ok <- validate_prompt_length(prompt),
         :ok <- validate_required_variables(prompt),
         :ok <- check_injection_patterns(prompt),
         :ok <- estimate_and_validate_tokens(prompt) do
      {:ok, prompt}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_custom_prompt(_), do: {:error, "Prompt must be a string"}

  defp validate_prompt_length(prompt) do
    length = String.length(prompt)

    cond do
      length < 50 ->
        {:error, "Prompt too short (minimum 50 characters)"}

      length > 4000 ->
        {:error, "Prompt too long (maximum 4000 characters)"}

      true ->
        :ok
    end
  end

  defp validate_required_variables(prompt) do
    if String.contains?(prompt, "{{JOB_DESCRIPTION}}") do
      :ok
    else
      {:error, "Prompt must contain {{JOB_DESCRIPTION}} variable"}
    end
  end

  defp check_injection_patterns(prompt) do
    if Enum.any?(@injection_patterns, &Regex.match?(&1, prompt)) do
      {:error, "Prompt contains potentially unsafe instructions"}
    else
      :ok
    end
  end

  defp estimate_and_validate_tokens(prompt) do
    # Rough estimation: ~4 characters per token
    estimated_tokens = div(String.length(prompt), 4)

    if estimated_tokens > 6000 do
      {:error, "Prompt may exceed token budget (estimated #{estimated_tokens} tokens, max 6000)"}
    else
      :ok
    end
  end

  # Variable substitution

  defp substitute_variables(template, variables) do
    template
    |> String.replace("{{JOB_DESCRIPTION}}", to_string(variables[:job_description] || ""))
    |> String.replace(
      "{{CANDIDATE_NAME}}",
      "#{variables[:first_name]} #{variables[:last_name]}"
    )
    |> String.replace("{{CANDIDATE_FIRST_NAME}}", to_string(variables[:first_name] || ""))
    |> String.replace("{{CANDIDATE_LAST_NAME}}", to_string(variables[:last_name] || ""))
    |> String.replace("{{RESUME_TEXT}}", to_string(variables[:resume_text] || ""))
    |> String.replace("{{COMPANY_NAME}}", to_string(variables[:company_name] || ""))
    |> String.replace("{{POSITION_TITLE}}", to_string(variables[:position_title] || ""))
  end

  # Existing private helpers

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
