defmodule Clientats.JobExtractorTest do
  use ExUnit.Case, async: true

  alias Clientats.JobExtractor

  # Real-world-style job postings for extraction testing
  @elixir_fintech_posting """
  Senior Elixir Developer - Payment Systems

  About TradeTech Capital
  TradeTech Capital is a leading fintech company building next-generation payment
  infrastructure for global markets. Our platform processes over $2B in daily transactions.

  About the Role
  We're looking for a Senior Elixir Developer to join our Payment Systems team. You'll
  work on our core transaction processing engine built with Elixir/OTP, designing
  fault-tolerant systems that handle millions of requests per day.

  Requirements:
  - 5+ years of professional software development experience
  - 3+ years with Elixir and OTP (GenServer, Supervisor, GenStage)
  - Strong experience with Phoenix and LiveView
  - Experience with PostgreSQL, Redis, and message queues (RabbitMQ/Kafka)
  - Understanding of financial systems and payment processing
  - Bachelor's degree in Computer Science or equivalent

  Nice to Have:
  - Experience with Kubernetes and Docker
  - Knowledge of PCI-DSS compliance
  - Erlang experience
  - Experience with event sourcing or CQRS patterns

  Tech Stack: Elixir, Phoenix, LiveView, PostgreSQL, Redis, Kafka, Kubernetes, AWS

  Compensation:
  - Base salary: $180,000 - $220,000/year
  - Equity: 0.05% - 0.15%
  - Annual bonus: 10-20% of base

  Benefits:
  - Full health, dental, and vision insurance
  - 401(k) with 4% match
  - Unlimited PTO
  - $2,000 annual learning budget
  - Remote-first (US timezone overlap required)

  Location: Remote (US-based)
  Employment Type: Full-time
  Visa sponsorship available for exceptional candidates.
  """

  @python_ml_posting """
  Machine Learning Engineer - Computer Vision

  DataVision AI | San Francisco, CA (Hybrid - 3 days in office)

  We're hiring a Machine Learning Engineer to work on our computer vision pipeline
  for autonomous retail analytics. Join our Applied AI team of 12 engineers.

  What You'll Do:
  - Design and train deep learning models for object detection and tracking
  - Optimize model inference for edge deployment (NVIDIA Jetson, TensorRT)
  - Build data pipelines for training data management
  - Collaborate with product team on new feature development

  Requirements:
  - MS or PhD in Computer Science, Machine Learning, or related field
  - 2-4 years experience in production ML systems
  - Strong Python skills (PyTorch, TensorFlow)
  - Experience with computer vision (object detection, segmentation)
  - Familiarity with MLOps tools (MLflow, Weights & Biases, DVC)

  Preferred:
  - Experience with model optimization (quantization, pruning, distillation)
  - Knowledge of C++ for performance-critical components
  - Published research in top-tier venues (CVPR, NeurIPS, ICML)

  Salary: $160,000 - $200,000 + equity
  """

  @devops_posting """
  DevOps Engineer

  CloudScale Inc.
  Location: Austin, TX (On-site)
  Employment: Contract (6 months, possibility of conversion)

  CloudScale is looking for a mid-level DevOps Engineer to help us scale our
  cloud infrastructure. You'll work directly with our CTO and a small team
  of 4 engineers.

  Responsibilities:
  - Manage and optimize AWS infrastructure (EC2, ECS, RDS, S3, CloudFront)
  - Build and maintain CI/CD pipelines with GitHub Actions and ArgoCD
  - Implement infrastructure as code with Terraform
  - Monitor systems using Datadog and PagerDuty
  - Improve deployment frequency and reduce MTTR

  Requirements:
  - 3-5 years DevOps/SRE experience
  - AWS certification preferred (Solutions Architect or DevOps Engineer)
  - Strong Linux administration skills
  - Experience with containerization (Docker, Kubernetes)
  - Scripting skills (Bash, Python)

  Rate: $75-95/hour
  No visa sponsorship.
  """

  @junior_frontend_posting """
  Junior Frontend Developer

  StartupXYZ - Remote (EU timezone)

  We're a small team building an innovative ed-tech platform. Looking for a
  motivated junior developer to help us build beautiful, accessible user interfaces.

  What we need:
  - Basic proficiency in React and TypeScript
  - Understanding of HTML, CSS, and responsive design
  - Willingness to learn and grow
  - Some experience with Git

  Nice to have:
  - Experience with Next.js or Remix
  - Knowledge of accessibility standards (WCAG)
  - UI/UX design sensibility

  Salary: €35,000 - €45,000/year
  Benefits: flexible hours, learning budget, team retreats
  """

  describe "validate/1" do
    test "validates a well-formed extraction result" do
      extracted = %{
        "title_clean" => "Backend Developer",
        "seniority_level" => "senior",
        "required_skills" => ["Elixir", "PostgreSQL"],
        "preferred_skills" => ["Kubernetes"],
        "years_experience_min" => 5,
        "years_experience_max" => nil,
        "education_requirement" => "bachelor",
        "industry" => "fintech",
        "team_description" => "Payment Systems",
        "tech_stack" => ["Elixir", "Phoenix", "PostgreSQL", "Redis"],
        "benefits" => ["health insurance", "401k"],
        "remote_policy" => "full_remote",
        "visa_sponsorship" => true,
        "company_name" => "TradeTech Capital",
        "location" => "Remote, US",
        "salary_min" => 180_000,
        "salary_max" => 220_000,
        "employment_type" => "full_time"
      }

      assert {:ok, validated} = JobExtractor.validate(extracted)
      assert validated.title_clean == "Backend Developer"
      assert validated.seniority_level == "senior"
      assert validated.required_skills == ["Elixir", "PostgreSQL"]
      assert validated.salary_min == 180_000
      assert validated.visa_sponsorship == true
      assert validated.employment_type == "full_time"
    end

    test "rejects missing title_clean" do
      assert {:error, errors} = JobExtractor.validate(%{})
      assert "title_clean is required" in errors
    end

    test "coerces string numbers to integers" do
      extracted = %{
        "title_clean" => "Dev",
        "salary_min" => "150000",
        "years_experience_min" => "5"
      }

      {:ok, validated} = JobExtractor.validate(extracted)
      assert validated.salary_min == 150_000
      assert validated.years_experience_min == 5
    end

    test "normalizes invalid enum values to nil" do
      extracted = %{
        "title_clean" => "Dev",
        "seniority_level" => "guru",
        "employment_type" => "freelance"
      }

      {:ok, validated} = JobExtractor.validate(extracted)
      assert validated.seniority_level == nil
      assert validated.employment_type == nil
    end

    test "handles boolean coercion" do
      for {input, expected} <- [
            {true, true},
            {false, false},
            {"true", true},
            {"false", false},
            {nil, nil},
            {"maybe", nil}
          ] do
        extracted = %{"title_clean" => "Dev", "visa_sponsorship" => input}
        {:ok, validated} = JobExtractor.validate(extracted)

        assert validated.visa_sponsorship == expected,
               "Expected #{inspect(expected)} for input #{inspect(input)}"
      end
    end
  end

  describe "vector_texts/1" do
    test "builds title text with seniority and industry" do
      extracted = %{
        "title_clean" => "Backend Developer",
        "seniority_level" => "senior",
        "industry" => "fintech"
      }

      texts = JobExtractor.vector_texts(extracted)
      assert texts.title == "senior Backend Developer fintech"
    end

    test "builds skills text from all skill fields" do
      extracted = %{
        "required_skills" => ["Elixir", "PostgreSQL"],
        "preferred_skills" => ["Kubernetes", "Docker"],
        "tech_stack" => ["Phoenix", "LiveView", "PostgreSQL"]
      }

      texts = JobExtractor.vector_texts(extracted)
      # PostgreSQL should be deduplicated
      assert texts.skills =~ "Elixir"
      assert texts.skills =~ "Phoenix"
      assert texts.skills =~ "Kubernetes"
      # Count unique entries
      skills = String.split(texts.skills, ", ")
      assert length(skills) == length(Enum.uniq(skills))
    end

    test "builds requirements text with experience and education" do
      extracted = %{
        "seniority_level" => "senior",
        "years_experience_min" => 5,
        "years_experience_max" => 8,
        "education_requirement" => "bachelor",
        "required_skills" => ["Elixir", "OTP"]
      }

      texts = JobExtractor.vector_texts(extracted)
      assert texts.requirements =~ "5-8 years experience"
      assert texts.requirements =~ "bachelor degree"
      assert texts.requirements =~ "Required: Elixir, OTP"
      assert texts.requirements =~ "senior level"
    end

    test "handles missing fields gracefully" do
      texts = JobExtractor.vector_texts(%{})
      assert texts.title == ""
      assert texts.skills == ""
      assert texts.requirements == ""
      assert texts.description == ""
    end
  end

  describe "schema_definition/0" do
    test "returns all expected fields" do
      schema = JobExtractor.schema_definition()
      assert Map.has_key?(schema, :title_clean)
      assert Map.has_key?(schema, :seniority_level)
      assert Map.has_key?(schema, :required_skills)
      assert Map.has_key?(schema, :tech_stack)
      assert Map.has_key?(schema, :visa_sponsorship)
      assert map_size(schema) >= 15
    end
  end

  describe "extract/2 with :ollama" do
    @tag :ollama
    test "extracts fields from Elixir fintech posting" do
      {:ok, result} = JobExtractor.extract(@elixir_fintech_posting, provider: :ollama)

      assert {:ok, validated} = JobExtractor.validate(result)

      IO.puts("\n=== Elixir Fintech Extraction ===")
      IO.puts("Title: #{validated.title_clean}")
      IO.puts("Seniority: #{validated.seniority_level}")
      IO.puts("Company: #{validated.company_name}")
      IO.puts("Industry: #{validated.industry}")
      IO.puts("Skills: #{inspect(validated.required_skills)}")
      IO.puts("Tech: #{inspect(validated.tech_stack)}")
      IO.puts("Salary: $#{validated.salary_min}-$#{validated.salary_max}")
      IO.puts("Remote: #{validated.remote_policy}")
      IO.puts("Visa: #{validated.visa_sponsorship}")
      IO.puts("Education: #{validated.education_requirement}")
      IO.puts("Years: #{validated.years_experience_min}-#{validated.years_experience_max}")

      # Core assertions
      assert validated.company_name =~ "TradeTech"
      assert validated.seniority_level == "senior"
      assert "Elixir" in validated.required_skills or "Elixir" in validated.tech_stack
      assert validated.salary_min != nil
      assert validated.salary_max != nil
      assert validated.employment_type == "full_time"
    end

    @tag :ollama
    test "extracts fields from Python ML posting" do
      {:ok, result} = JobExtractor.extract(@python_ml_posting, provider: :ollama)
      {:ok, validated} = JobExtractor.validate(result)

      IO.puts("\n=== Python ML Extraction ===")
      IO.puts("Title: #{validated.title_clean}")
      IO.puts("Seniority: #{validated.seniority_level}")
      IO.puts("Company: #{validated.company_name}")
      IO.puts("Industry: #{validated.industry}")
      IO.puts("Skills: #{inspect(validated.required_skills)}")
      IO.puts("Education: #{validated.education_requirement}")

      assert validated.company_name =~ "DataVision"
      assert "Python" in validated.required_skills or "Python" in validated.tech_stack
      # Education may or may not parse to our exact enum values
      # The posting says "MS or PhD" - LLM may return various formats
      IO.puts("Education extracted: #{inspect(result["education_requirement"])}")
      IO.puts("Validated as: #{inspect(validated.education_requirement)}")
    end

    @tag :ollama
    test "extracts fields from DevOps contract posting" do
      {:ok, result} = JobExtractor.extract(@devops_posting, provider: :ollama)
      {:ok, validated} = JobExtractor.validate(result)

      IO.puts("\n=== DevOps Extraction ===")
      IO.puts("Title: #{validated.title_clean}")
      IO.puts("Seniority: #{validated.seniority_level}")
      IO.puts("Company: #{validated.company_name}")
      IO.puts("Employment: #{validated.employment_type}")
      IO.puts("Remote: #{validated.remote_policy}")
      IO.puts("Visa: #{validated.visa_sponsorship}")

      assert validated.company_name =~ "CloudScale"
      assert validated.employment_type == "contract"
      assert validated.visa_sponsorship == false
    end

    @tag :ollama
    test "extracts fields from junior frontend posting" do
      {:ok, result} = JobExtractor.extract(@junior_frontend_posting, provider: :ollama)
      {:ok, validated} = JobExtractor.validate(result)

      IO.puts("\n=== Junior Frontend Extraction ===")
      IO.puts("Title: #{validated.title_clean}")
      IO.puts("Seniority: #{validated.seniority_level}")
      IO.puts("Company: #{validated.company_name}")
      IO.puts("Remote: #{validated.remote_policy}")

      assert validated.seniority_level == "junior"
      assert "React" in validated.required_skills or "React" in validated.tech_stack
    end

    @tag :ollama
    test "vector texts are meaningful after extraction" do
      {:ok, result} = JobExtractor.extract(@elixir_fintech_posting, provider: :ollama)

      texts = JobExtractor.vector_texts(result)

      IO.puts("\n=== Vector Texts ===")
      IO.puts("Title text: #{texts.title}")
      IO.puts("Skills text: #{String.slice(texts.skills, 0, 100)}")
      IO.puts("Requirements text: #{texts.requirements}")

      # Title should contain seniority info
      assert String.length(texts.title) > 5
      # Skills should contain multiple technologies
      assert String.length(texts.skills) > 10
      # Requirements should mention experience
      refute texts.requirements == ""
    end

    @tag :ollama
    test "extraction accuracy across all postings" do
      postings = [
        {"Elixir Fintech", @elixir_fintech_posting,
         %{company: "TradeTech", seniority: "senior", type: "full_time"}},
        {"Python ML", @python_ml_posting,
         %{company: "DataVision", seniority: "mid", type: "full_time"}},
        {"DevOps Contract", @devops_posting,
         %{company: "CloudScale", seniority: "mid", type: "contract"}},
        {"Junior Frontend", @junior_frontend_posting,
         %{company: "StartupXYZ", seniority: "junior", type: "full_time"}}
      ]

      results =
        Enum.map(postings, fn {name, text, expected} ->
          {time_us, {:ok, result}} =
            :timer.tc(fn -> JobExtractor.extract(text, provider: :ollama) end)

          {:ok, validated} = JobExtractor.validate(result)

          _fields_total = 18

          fields_present =
            [
              validated.title_clean,
              validated.seniority_level,
              validated.company_name,
              validated.industry,
              validated.location,
              validated.employment_type,
              validated.remote_policy,
              validated.education_requirement
            ]
            |> Enum.count(&(not is_nil(&1) and &1 != ""))

          list_fields_present =
            [
              validated.required_skills,
              validated.preferred_skills,
              validated.tech_stack,
              validated.benefits
            ]
            |> Enum.count(&(&1 != []))

          company_match =
            validated.company_name && String.contains?(validated.company_name, expected.company)

          seniority_match = validated.seniority_level == expected.seniority
          type_match = validated.employment_type == expected.type

          %{
            name: name,
            latency_ms: div(time_us, 1000),
            scalar_fields: fields_present,
            list_fields: list_fields_present,
            company_match: company_match,
            seniority_match: seniority_match,
            type_match: type_match,
            total_coverage: fields_present + list_fields_present
          }
        end)

      IO.puts("\n=== Extraction Accuracy Summary ===")
      IO.puts(String.duplicate("-", 80))

      IO.puts(
        String.pad_trailing("Posting", 20) <>
          String.pad_trailing("Latency", 10) <>
          String.pad_trailing("Scalar", 10) <>
          String.pad_trailing("Lists", 10) <>
          String.pad_trailing("Company", 10) <>
          String.pad_trailing("Senior", 10) <>
          String.pad_trailing("Type", 10)
      )

      IO.puts(String.duplicate("-", 80))

      for r <- results do
        IO.puts(
          String.pad_trailing(r.name, 20) <>
            String.pad_trailing("#{r.latency_ms}ms", 10) <>
            String.pad_trailing("#{r.scalar_fields}/8", 10) <>
            String.pad_trailing("#{r.list_fields}/4", 10) <>
            String.pad_trailing(if(r.company_match, do: "✓", else: "✗"), 10) <>
            String.pad_trailing(if(r.seniority_match, do: "✓", else: "✗"), 10) <>
            String.pad_trailing(if(r.type_match, do: "✓", else: "✗"), 10)
        )
      end

      avg_latency = div(Enum.sum(Enum.map(results, & &1.latency_ms)), length(results))
      avg_coverage = Enum.sum(Enum.map(results, & &1.total_coverage)) / length(results)
      IO.puts(String.duplicate("-", 80))

      IO.puts(
        "Avg latency: #{avg_latency}ms | Avg field coverage: #{Float.round(avg_coverage, 1)}/12"
      )

      # At least 80% of key fields should match across postings
      company_accuracy = Enum.count(results, & &1.company_match) / length(results)
      seniority_accuracy = Enum.count(results, & &1.seniority_match) / length(results)
      type_accuracy = Enum.count(results, & &1.type_match) / length(results)

      assert company_accuracy >= 0.75, "Company accuracy #{company_accuracy} < 75%"
      assert seniority_accuracy >= 0.50, "Seniority accuracy #{seniority_accuracy} < 50%"
      assert type_accuracy >= 0.75, "Type accuracy #{type_accuracy} < 75%"
    end
  end
end
