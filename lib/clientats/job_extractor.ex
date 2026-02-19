defmodule Clientats.JobExtractor do
  @moduledoc """
  Enhanced structured job data extraction for the matching pipeline.

  Extends the basic extraction (company, title, description) with richer
  structured fields needed for multi-vector search and faceted matching:
  - Normalized title + seniority for title vectors
  - Required/preferred skills for skills vectors
  - Tech stack, industry, benefits for description vectors
  - Vectorization-ready text fields

  Uses the existing Gemini/Ollama LLM infrastructure for extraction.

  ## Usage

      {:ok, extracted} = JobExtractor.extract(job_description_text)
      # => %{title_clean: "Backend Developer", seniority: "senior", ...}

      # Generate vector text fields
      texts = JobExtractor.vector_texts(extracted)
      # => %{title: "Senior Backend Developer", skills: "Elixir Phoenix PostgreSQL ...", ...}
  """

  require Logger

  @ollama_url "http://localhost:11434"
  @ollama_model "llama3.2"

  @schema_fields %{
    title_clean: "Normalized job title without company name, level prefix, or decorators",
    seniority_level: "One of: intern, junior, mid, senior, staff, principal, director, vp, c_level",
    required_skills: "Array of required technical skills and technologies",
    preferred_skills: "Array of nice-to-have/preferred skills",
    years_experience_min: "Minimum years of experience required (integer or null)",
    years_experience_max: "Maximum years of experience mentioned (integer or null)",
    education_requirement: "Degree requirement: none, associate, bachelor, master, phd, or null",
    industry: "Industry/domain: fintech, healthcare, gaming, ecommerce, saas, devtools, etc.",
    team_description: "What team/org within the company (e.g. 'Platform Engineering')",
    tech_stack: "Array of specific technologies, frameworks, languages mentioned",
    benefits: "Array of benefits mentioned (401k, health insurance, equity, etc.)",
    remote_policy: "Detailed remote policy: full_remote, hybrid_2d, hybrid_3d, onsite, flexible",
    visa_sponsorship: "Boolean: whether visa sponsorship is mentioned",
    company_name: "Company name",
    location: "Job location (city, state/country)",
    salary_min: "Minimum salary as integer (annual USD) or null",
    salary_max: "Maximum salary as integer (annual USD) or null",
    employment_type: "One of: full_time, part_time, contract, internship"
  }

  @doc """
  Extract enhanced structured data from job posting text.

  ## Options
    * `:provider` - `:ollama` or `:gemini` (default: auto-detect)
    * `:model` - Model to use (default: provider-specific)
    * `:user_id` - User ID for Gemini API key lookup
  """
  def extract(text, opts \\ []) when is_binary(text) do
    provider = opts[:provider] || default_provider()

    prompt = build_extraction_prompt(text)

    case provider do
      :ollama -> extract_ollama(prompt, opts)
      :gemini -> extract_gemini(prompt, opts)
    end
  end

  @doc """
  Generate vectorization-ready text from extracted fields.

  Returns a map with text strings optimized for embedding generation:
  - `:title` - Clean title with seniority for title vector
  - `:skills` - Combined required + preferred skills + tech stack
  - `:description` - Full job description (pass-through)
  - `:requirements` - Requirements summary (experience, education, skills)
  """
  def vector_texts(extracted) when is_map(extracted) do
    %{
      title: build_title_text(extracted),
      skills: build_skills_text(extracted),
      description: extracted[:description] || extracted["description"] || "",
      requirements: build_requirements_text(extracted)
    }
  end

  @doc """
  Returns the enhanced extraction schema definition.
  """
  def schema_definition, do: @schema_fields

  @doc """
  Validate extracted data against the schema.
  Returns `{:ok, validated}` with coerced types or `{:error, errors}`.
  """
  def validate(extracted) when is_map(extracted) do
    errors = []

    # Required fields
    errors =
      if blank?(extracted["title_clean"] || extracted[:title_clean]),
        do: ["title_clean is required" | errors],
        else: errors

    # Type coercion and validation
    validated = %{
      title_clean: to_string_or_nil(extracted, "title_clean"),
      seniority_level: validate_enum(extracted, "seniority_level",
        ~w(intern junior mid senior staff principal director vp c_level)),
      required_skills: to_list(extracted, "required_skills"),
      preferred_skills: to_list(extracted, "preferred_skills"),
      years_experience_min: to_integer_or_nil(extracted, "years_experience_min"),
      years_experience_max: to_integer_or_nil(extracted, "years_experience_max"),
      education_requirement: normalize_education(extracted),
      industry: to_string_or_nil(extracted, "industry"),
      team_description: to_string_or_nil(extracted, "team_description"),
      tech_stack: to_list(extracted, "tech_stack"),
      benefits: to_list(extracted, "benefits"),
      remote_policy: to_string_or_nil(extracted, "remote_policy"),
      visa_sponsorship: to_boolean(extracted, "visa_sponsorship"),
      company_name: to_string_or_nil(extracted, "company_name"),
      location: to_string_or_nil(extracted, "location"),
      salary_min: to_integer_or_nil(extracted, "salary_min"),
      salary_max: to_integer_or_nil(extracted, "salary_max"),
      employment_type: validate_enum(extracted, "employment_type",
        ~w(full_time part_time contract internship))
    }

    if errors == [] do
      {:ok, validated}
    else
      {:error, errors}
    end
  end

  # --- Prompt Building ---

  defp build_extraction_prompt(text) do
    """
    Extract structured job posting data from the following text. Be precise and thorough.

    JOB POSTING:
    ```
    #{String.slice(text, 0, 6000)}
    ```

    Extract these fields as JSON:

    {
      "title_clean": "Normalized title without company prefix or decorators (e.g. 'Backend Developer' not 'ACME Corp - Backend Developer')",
      "seniority_level": "One of: intern, junior, mid, senior, staff, principal, director, vp, c_level (infer from title/requirements if not explicit)",
      "required_skills": ["skill1", "skill2"],
      "preferred_skills": ["skill1", "skill2"],
      "years_experience_min": null or integer,
      "years_experience_max": null or integer,
      "education_requirement": "One of: none, associate, bachelor, master, phd, or null",
      "industry": "Domain like fintech, healthcare, gaming, ecommerce, saas, devtools, cybersecurity, etc.",
      "team_description": "Team or department name if mentioned, or null",
      "tech_stack": ["specific technology names"],
      "benefits": ["benefit1", "benefit2"],
      "remote_policy": "One of: full_remote, hybrid_2d, hybrid_3d, onsite, flexible, or null",
      "visa_sponsorship": true/false/null,
      "company_name": "Company name",
      "location": "City, State/Country",
      "salary_min": null or annual USD integer,
      "salary_max": null or annual USD integer,
      "employment_type": "One of: full_time, part_time, contract, internship"
    }

    Rules:
    - For skills, separate individual technologies (e.g. ["React", "TypeScript"] not ["React/TypeScript"])
    - Infer seniority from years of experience if not in title (0-2: junior, 3-5: mid, 5-8: senior, 8+: staff/principal)
    - Convert salary to annual USD (multiply hourly by 2080, monthly by 12)
    - tech_stack should be specific versions/tools, required_skills can be broader
    - Return ONLY valid JSON, no markdown fences or commentary
    """
  end

  # --- Vector Text Building ---

  defp build_title_text(extracted) do
    title = get_field(extracted, "title_clean", "")
    seniority = get_field(extracted, "seniority_level", "")
    industry = get_field(extracted, "industry", "")

    [seniority, title, industry]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" ")
  end

  defp build_skills_text(extracted) do
    required = get_list(extracted, "required_skills")
    preferred = get_list(extracted, "preferred_skills")
    tech_stack = get_list(extracted, "tech_stack")

    (required ++ preferred ++ tech_stack)
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.join(", ")
  end

  defp build_requirements_text(extracted) do
    parts = []

    years_min = get_field(extracted, "years_experience_min")
    years_max = get_field(extracted, "years_experience_max")

    parts =
      cond do
        years_min && years_max -> ["#{years_min}-#{years_max} years experience" | parts]
        years_min -> ["#{years_min}+ years experience" | parts]
        true -> parts
      end

    education = get_field(extracted, "education_requirement")
    parts = if education && education != "none", do: ["#{education} degree" | parts], else: parts

    required = get_list(extracted, "required_skills")
    parts = if required != [], do: ["Required: #{Enum.join(required, ", ")}" | parts], else: parts

    seniority = get_field(extracted, "seniority_level")
    parts = if seniority, do: ["#{seniority} level" | parts], else: parts

    parts
    |> Enum.reverse()
    |> Enum.join(". ")
  end

  # --- Provider Implementations ---

  defp extract_ollama(prompt, opts) do
    model = opts[:model] || @ollama_model
    url = "#{@ollama_url}/api/generate"

    body = %{
      "model" => model,
      "prompt" => prompt,
      "stream" => false,
      "format" => "json",
      "options" => %{"temperature" => 0.1, "num_predict" => 2048}
    }

    try do
      response = Req.post!(url, json: body, receive_timeout: 60_000)

      case response.status do
        200 ->
          text = response.body["response"] || ""

          case Jason.decode(text) do
            {:ok, parsed} -> {:ok, parsed}
            {:error, _} -> {:error, {:json_parse_error, String.slice(text, 0, 200)}}
          end

        status ->
          {:error, {:http_error, status}}
      end
    rescue
      e -> {:error, {:exception, Exception.message(e)}}
    end
  end

  defp extract_gemini(prompt, opts) do
    user_id = opts[:user_id]

    api_key = resolve_gemini_api_key(user_id)

    model =
      if user_id do
        case Clientats.LLMConfig.get_provider_config(user_id, :gemini) do
          {:ok, setting} -> setting.default_model || "gemini-2.0-flash"
          {:error, _} -> "gemini-2.0-flash"
        end
      else
        Application.get_env(:req_llm, :providers, %{})[:google][:default_model] ||
          "gemini-2.0-flash"
      end

    api_version =
      Application.get_env(:req_llm, :providers, %{})[:google][:api_version] || "v1beta"

    if !api_key do
      {:error, :missing_api_key}
    else
      url =
        "https://generativelanguage.googleapis.com/#{api_version}/models/#{model}:generateContent"

      body = %{
        "contents" => [%{"parts" => [%{"text" => prompt}]}],
        "generationConfig" => %{
          "responseMimeType" => "application/json",
          "temperature" => 0.1
        }
      }

      try do
        response =
          Req.post!(url,
            headers: [{"x-goog-api-key", api_key}],
            json: body,
            receive_timeout: opts[:timeout] || 30_000
          )

        case response.status do
          200 ->
            case response.body do
              %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text}]}} | _]} ->
                case Jason.decode(text) do
                  {:ok, parsed} -> {:ok, parsed}
                  {:error, _} -> {:error, {:json_parse_error, String.slice(text, 0, 200)}}
                end

              _ ->
                {:error, {:unexpected_response, response.body}}
            end

          status ->
            {:error, {:http_error, status, response.body}}
        end
      rescue
        e in [Req.TransportError] ->
          if e.reason == :timeout,
            do: {:error, {:timeout, "Gemini API timed out"}},
            else: {:error, {:transport_error, Exception.message(e)}}

        e ->
          {:error, {:exception, Exception.message(e)}}
      end
    end
  end

  defp resolve_gemini_api_key(user_id) do
    user_key =
      if user_id do
        case Clientats.LLMConfig.get_provider_config(user_id, :gemini) do
          {:ok, setting} -> setting.api_key
          {:error, _} -> nil
        end
      else
        nil
      end

    user_key || Application.get_env(:req_llm, :providers, %{})[:google][:api_key]
  end

  defp default_provider do
    if resolve_gemini_api_key(nil), do: :gemini, else: :ollama
  end

  # --- Field Helpers ---

  defp get_field(map, key, default \\ nil) do
    Map.get(map, key) || Map.get(map, String.to_existing_atom(key), default)
  rescue
    ArgumentError -> Map.get(map, key, default)
  end

  defp get_list(map, key) do
    case get_field(map, key) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

  defp to_string_or_nil(map, key) do
    case Map.get(map, key) || Map.get(map, String.to_atom(key)) do
      nil -> nil
      val -> to_string(val)
    end
  rescue
    ArgumentError -> nil
  end

  defp to_integer_or_nil(map, key) do
    case Map.get(map, key) || Map.get(map, String.to_atom(key)) do
      nil -> nil
      val when is_integer(val) -> val
      val when is_float(val) -> round(val)
      val when is_binary(val) ->
        case Integer.parse(val) do
          {int, _} -> int
          :error -> nil
        end
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp to_boolean(map, key) do
    val =
      case Map.get(map, key) do
        nil ->
          try do
            Map.get(map, String.to_atom(key))
          rescue
            ArgumentError -> nil
          end
        v -> v
      end

    case val do
      true -> true
      false -> false
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end

  defp to_list(map, key) do
    case Map.get(map, key) || Map.get(map, String.to_atom(key)) do
      list when is_list(list) -> Enum.map(list, &to_string/1)
      _ -> []
    end
  rescue
    ArgumentError -> []
  end

  defp normalize_education(map) do
    raw = to_string_or_nil(map, "education_requirement")
    case raw && String.downcase(raw) do
      nil -> nil
      s when s in ~w(none associate bachelor master phd) -> s
      s ->
        cond do
          String.contains?(s, "phd") or String.contains?(s, "doctorate") -> "phd"
          String.contains?(s, "master") or String.contains?(s, "ms ") or String.contains?(s, "ms/") or s == "ms" -> "master"
          String.contains?(s, "bachelor") or String.contains?(s, "bs ") or String.contains?(s, "ba ") -> "bachelor"
          String.contains?(s, "associate") -> "associate"
          true -> nil
        end
    end
  end

  defp validate_enum(map, key, valid_values) do
    val = to_string_or_nil(map, key)
    if val in valid_values, do: val, else: nil
  end
end
