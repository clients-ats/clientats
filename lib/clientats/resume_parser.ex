defmodule Clientats.ResumeParser do
  @moduledoc """
  Parses resumes into structured preference data for cold-start matching.

  Uses LLM extraction to convert resume text into structured fields,
  then generates preference vectors for the matching pipeline.

  ## Pipeline

      Resume (PDF) → extract_text → parse (LLM) → validate → bootstrap preferences

  ## Usage

      {:ok, text} = Clientats.Documents.extract_resume_text(resume)
      {:ok, parsed} = ResumeParser.parse(text)
      {:ok, prefs} = ResumeParser.bootstrap_preferences(user_id, parsed)
  """

  require Logger

  @ollama_url "http://localhost:11434"
  @ollama_model "llama3.2"

  @doc """
  Parse resume text into structured preference data.

  ## Options
    * `:provider` - `:ollama` or `:gemini` (default: auto-detect)
    * `:user_id` - User ID for Gemini API key lookup
  """
  def parse(text, opts \\ []) when is_binary(text) do
    provider = opts[:provider] || default_provider()
    prompt = build_parse_prompt(text)

    case provider do
      :ollama -> call_ollama(prompt, opts)
      :gemini -> call_gemini(prompt, opts)
    end
    |> case do
      {:ok, raw} -> validate(raw)
      error -> error
    end
  end

  @doc """
  Validate and normalize parsed resume data.
  """
  def validate(raw) when is_map(raw) do
    validated = %{
      current_title: get_string(raw, "current_title"),
      target_titles: get_list(raw, "target_titles"),
      skills_primary: get_list(raw, "skills_primary"),
      skills_secondary: get_list(raw, "skills_secondary"),
      years_experience: get_integer(raw, "years_experience"),
      industries: get_list(raw, "industries"),
      education: normalize_education(raw),
      preferred_work_model: get_enum(raw, "preferred_work_model", ~w(remote hybrid onsite)),
      salary_expectation_min: get_integer(raw, "salary_expectation_min"),
      salary_expectation_max: get_integer(raw, "salary_expectation_max"),
      career_trajectory: get_string(raw, "career_trajectory"),
      certifications: get_list(raw, "certifications"),
      seniority_level: infer_seniority(raw)
    }

    if validated.current_title || validated.skills_primary != [] do
      {:ok, validated}
    else
      {:error, :insufficient_data}
    end
  end

  @doc """
  Generate vectorization-ready text from parsed resume data.

  Returns a map with text strings for embedding generation:
  - `:skills` - Primary + secondary skills
  - `:roles` - Current title + target titles
  - `:experience` - Career trajectory narrative
  """
  def vector_texts(parsed) when is_map(parsed) do
    %{
      skills: build_skills_text(parsed),
      roles: build_roles_text(parsed),
      experience: build_experience_text(parsed)
    }
  end

  @doc """
  Bootstrap user preferences from parsed resume data.

  Creates UserPreference records for the user from the parsed resume,
  providing cold-start data for the matching pipeline.
  """
  def bootstrap_preferences(user_id, parsed) when is_map(parsed) do
    alias Clientats.Feedback

    results =
      [
        if parsed.skills_primary != [] || parsed.skills_secondary != [] do
          Feedback.set_preference(user_id, "skills", %{
            "list" => (parsed.skills_primary ++ parsed.skills_secondary) |> Enum.uniq()
          })
        end,
        if parsed.industries != [] do
          Feedback.set_preference(user_id, "industries", %{
            "list" => parsed.industries
          })
        end,
        if parsed.seniority_level do
          Feedback.set_preference(user_id, "seniority", %{
            "level" => parsed.seniority_level
          })
        end,
        if parsed.preferred_work_model do
          Feedback.set_preference(user_id, "work_model", %{
            "preferred" => parsed.preferred_work_model
          })
        end,
        if parsed.salary_expectation_min || parsed.salary_expectation_max do
          Feedback.set_preference(user_id, "salary", %{
            "min" => parsed.salary_expectation_min,
            "max" => parsed.salary_expectation_max
          })
        end,
        if parsed.target_titles != [] do
          Feedback.set_preference(user_id, "roles", %{
            "current" => parsed.current_title,
            "targets" => parsed.target_titles
          })
        end
      ]
      |> Enum.reject(&is_nil/1)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, length(results)}
    else
      {:error, errors}
    end
  end

  # --- Prompt ---

  defp build_parse_prompt(text) do
    """
    Parse this resume into structured JSON. Extract all relevant career information.

    RESUME TEXT:
    ```
    #{String.slice(text, 0, 8000)}
    ```

    Extract these fields as JSON:

    {
      "current_title": "Most recent job title",
      "target_titles": ["Titles this person would likely be looking for"],
      "skills_primary": ["Core technical skills with strong experience"],
      "skills_secondary": ["Secondary/supporting skills"],
      "years_experience": integer (total years of professional experience),
      "industries": ["Industries worked in (e.g. fintech, healthcare, saas)"],
      "education": [{"degree": "BS/MS/PhD/etc", "field": "Computer Science/etc"}],
      "preferred_work_model": "remote, hybrid, or onsite (infer from work history, null if unclear)",
      "salary_expectation_min": null (or integer if mentioned),
      "salary_expectation_max": null (or integer if mentioned),
      "career_trajectory": "Brief 1-2 sentence description of career path and growth",
      "certifications": ["Professional certifications"]
    }

    Rules:
    - For skills, separate individual technologies (e.g. ["React", "TypeScript"] not ["React/TypeScript"])
    - Infer target_titles from career trajectory (e.g. if current is "Senior Developer", targets might include "Staff Engineer", "Tech Lead")
    - years_experience: count total years from earliest to latest job
    - Industries should be lowercase domain names (fintech, healthcare, gaming, etc.)
    - Return ONLY valid JSON, no markdown fences or commentary
    """
  end

  # --- Provider Implementations ---

  defp call_ollama(prompt, opts) do
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
      response = Req.post!(url, json: body, receive_timeout: 90_000)

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

  defp call_gemini(prompt, opts) do
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
            receive_timeout: opts[:timeout] || 60_000
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

  # --- Validation Helpers ---

  defp get_string(map, key) do
    case Map.get(map, key) do
      s when is_binary(s) and s != "" -> s
      _ -> nil
    end
  end

  defp get_list(map, key) do
    case Map.get(map, key) do
      list when is_list(list) -> Enum.map(list, &to_string/1) |> Enum.reject(&(&1 == ""))
      _ -> []
    end
  end

  defp get_integer(map, key) do
    case Map.get(map, key) do
      n when is_integer(n) -> n
      n when is_float(n) -> round(n)
      s when is_binary(s) ->
        case Integer.parse(s) do
          {n, _} -> n
          :error -> nil
        end
      _ -> nil
    end
  end

  defp get_enum(map, key, valid) do
    case get_string(map, key) do
      nil -> nil
      val ->
        normalized = String.downcase(val)
        if normalized in valid, do: normalized, else: nil
    end
  end

  defp normalize_education(raw) do
    case Map.get(raw, "education") do
      list when is_list(list) ->
        Enum.map(list, fn
          %{"degree" => d, "field" => f} -> %{degree: to_string(d), field: to_string(f)}
          %{"degree" => d} -> %{degree: to_string(d), field: nil}
          other when is_binary(other) -> %{degree: other, field: nil}
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp infer_seniority(raw) do
    years = get_integer(raw, "years_experience")
    title = get_string(raw, "current_title") || ""
    title_lower = String.downcase(title)

    cond do
      String.contains?(title_lower, "principal") or String.contains?(title_lower, "staff") ->
        "staff"
      String.contains?(title_lower, "senior") or String.contains?(title_lower, "sr.") ->
        "senior"
      String.contains?(title_lower, "lead") or String.contains?(title_lower, "architect") ->
        "senior"
      String.contains?(title_lower, "junior") or String.contains?(title_lower, "jr.") ->
        "junior"
      String.contains?(title_lower, "intern") ->
        "intern"
      String.contains?(title_lower, "director") or String.contains?(title_lower, "vp") ->
        "director"
      is_integer(years) and years >= 8 -> "senior"
      is_integer(years) and years >= 3 -> "mid"
      is_integer(years) and years >= 0 -> "junior"
      true -> "mid"
    end
  end

  # --- Vector Text Building ---

  defp build_skills_text(parsed) do
    (parsed.skills_primary ++ parsed.skills_secondary)
    |> Enum.uniq_by(&String.downcase/1)
    |> Enum.join(", ")
  end

  defp build_roles_text(parsed) do
    titles = [parsed.current_title | parsed.target_titles]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.join(", ")

    industries = Enum.join(parsed.industries, ", ")

    [titles, industries]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" | ")
  end

  defp build_experience_text(parsed) do
    parts = []

    parts =
      if parsed.career_trajectory,
        do: [parsed.career_trajectory | parts],
        else: parts

    parts =
      if parsed.years_experience,
        do: ["#{parsed.years_experience} years experience" | parts],
        else: parts

    parts =
      if parsed.seniority_level,
        do: ["#{parsed.seniority_level} level" | parts],
        else: parts

    parts =
      if parsed.education != [] do
        edu_text =
          Enum.map(parsed.education, fn e ->
            if e.field, do: "#{e.degree} in #{e.field}", else: e.degree
          end)
          |> Enum.join(", ")

        ["Education: #{edu_text}" | parts]
      else
        parts
      end

    parts
    |> Enum.reverse()
    |> Enum.join(". ")
  end
end
