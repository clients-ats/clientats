defmodule Clientats.ResumeParserTest do
  use Clientats.DataCase, async: false

  alias Clientats.ResumeParser
  require Logger
  alias Clientats.Feedback

  # --- Sample resume data (simulating LLM parse output) ---

  @senior_elixir_parsed %{
    "current_title" => "Senior Software Engineer",
    "target_titles" => ["Staff Engineer", "Tech Lead", "Principal Engineer"],
    "skills_primary" => ["Elixir", "Phoenix", "PostgreSQL", "LiveView", "OTP"],
    "skills_secondary" => ["Docker", "AWS", "GraphQL", "React", "TypeScript"],
    "years_experience" => 8,
    "industries" => ["fintech", "saas"],
    "education" => [%{"degree" => "MS", "field" => "Computer Science"}],
    "preferred_work_model" => "remote",
    "salary_expectation_min" => 160_000,
    "salary_expectation_max" => 200_000,
    "career_trajectory" => "Progressed from backend developer to senior engineer specializing in distributed systems and real-time applications.",
    "certifications" => ["AWS Solutions Architect"]
  }

  @junior_python_parsed %{
    "current_title" => "Junior Data Analyst",
    "target_titles" => ["Data Engineer", "ML Engineer"],
    "skills_primary" => ["Python", "SQL", "Pandas", "NumPy"],
    "skills_secondary" => ["Jupyter", "Tableau", "Git"],
    "years_experience" => 2,
    "industries" => ["healthcare", "analytics"],
    "education" => [%{"degree" => "BS", "field" => "Statistics"}],
    "preferred_work_model" => "hybrid",
    "salary_expectation_min" => nil,
    "salary_expectation_max" => nil,
    "career_trajectory" => "Recent graduate with internship experience in healthcare data analysis.",
    "certifications" => []
  }

  @devops_parsed %{
    "current_title" => "DevOps Lead",
    "target_titles" => ["Platform Engineering Manager", "SRE Director"],
    "skills_primary" => ["Kubernetes", "Terraform", "AWS", "CI/CD", "Linux"],
    "skills_secondary" => ["Go", "Python", "Prometheus", "Grafana"],
    "years_experience" => 12,
    "industries" => ["cloud", "devtools", "fintech"],
    "education" => [%{"degree" => "BS", "field" => "Information Technology"}],
    "preferred_work_model" => "remote",
    "salary_expectation_min" => 180_000,
    "salary_expectation_max" => 250_000,
    "career_trajectory" => "Started as sysadmin, transitioned to DevOps, now leading platform teams.",
    "certifications" => ["CKA", "AWS DevOps Professional"]
  }

  describe "validate/1" do
    test "validates senior Elixir resume" do
      assert {:ok, parsed} = ResumeParser.validate(@senior_elixir_parsed)

      assert parsed.current_title == "Senior Software Engineer"
      assert "Staff Engineer" in parsed.target_titles
      assert "Elixir" in parsed.skills_primary
      assert "Docker" in parsed.skills_secondary
      assert parsed.years_experience == 8
      assert "fintech" in parsed.industries
      assert parsed.preferred_work_model == "remote"
      assert parsed.salary_expectation_min == 160_000
      assert parsed.salary_expectation_max == 200_000
      assert parsed.seniority_level == "senior"
    end

    test "validates junior Python resume" do
      assert {:ok, parsed} = ResumeParser.validate(@junior_python_parsed)

      assert parsed.current_title == "Junior Data Analyst"
      assert parsed.years_experience == 2
      assert parsed.seniority_level == "junior"
      assert parsed.salary_expectation_min == nil
    end

    test "validates DevOps resume" do
      assert {:ok, parsed} = ResumeParser.validate(@devops_parsed)

      assert parsed.current_title == "DevOps Lead"
      assert parsed.years_experience == 12
      assert parsed.seniority_level == "senior"
      assert length(parsed.certifications) == 2
    end

    test "returns error for empty data" do
      assert {:error, :insufficient_data} = ResumeParser.validate(%{})
    end

    test "handles missing optional fields gracefully" do
      minimal = %{"current_title" => "Developer", "skills_primary" => ["Java"]}
      assert {:ok, parsed} = ResumeParser.validate(minimal)
      assert parsed.current_title == "Developer"
      assert parsed.target_titles == []
      assert parsed.education == []
      assert parsed.preferred_work_model == nil
    end

    test "normalizes education" do
      data = %{
        "current_title" => "Dev",
        "skills_primary" => ["Go"],
        "education" => [
          %{"degree" => "PhD", "field" => "Machine Learning"},
          %{"degree" => "BS", "field" => "Math"}
        ]
      }

      assert {:ok, parsed} = ResumeParser.validate(data)
      assert length(parsed.education) == 2
      assert hd(parsed.education).degree == "PhD"
      assert hd(parsed.education).field == "Machine Learning"
    end
  end

  describe "inferred seniority" do
    test "infers from title keywords" do
      for {title, expected} <- [
            {"Staff Software Engineer", "staff"},
            {"Principal Architect", "staff"},
            {"Senior Developer", "senior"},
            {"Sr. Backend Engineer", "senior"},
            {"Tech Lead", "senior"},
            {"Junior Developer", "junior"},
            {"Engineering Intern", "intern"},
            {"VP of Engineering", "director"},
            {"Director of Platform", "director"}
          ] do
        {:ok, parsed} =
          ResumeParser.validate(%{
            "current_title" => title,
            "skills_primary" => ["test"]
          })

        assert parsed.seniority_level == expected,
               "Expected #{expected} for '#{title}', got #{parsed.seniority_level}"
      end
    end

    test "infers from years when title is generic" do
      for {years, expected} <- [
            {1, "junior"},
            {4, "mid"},
            {10, "senior"}
          ] do
        {:ok, parsed} =
          ResumeParser.validate(%{
            "current_title" => "Software Engineer",
            "skills_primary" => ["test"],
            "years_experience" => years
          })

        assert parsed.seniority_level == expected,
               "Expected #{expected} for #{years} years, got #{parsed.seniority_level}"
      end
    end
  end

  describe "vector_texts/1" do
    test "generates skills text" do
      {:ok, parsed} = ResumeParser.validate(@senior_elixir_parsed)
      texts = ResumeParser.vector_texts(parsed)

      assert texts.skills =~ "Elixir"
      assert texts.skills =~ "Phoenix"
      assert texts.skills =~ "Docker"
    end

    test "generates roles text with industries" do
      {:ok, parsed} = ResumeParser.validate(@senior_elixir_parsed)
      texts = ResumeParser.vector_texts(parsed)

      assert texts.roles =~ "Senior Software Engineer"
      assert texts.roles =~ "Staff Engineer"
      assert texts.roles =~ "fintech"
    end

    test "generates experience text" do
      {:ok, parsed} = ResumeParser.validate(@senior_elixir_parsed)
      texts = ResumeParser.vector_texts(parsed)

      assert texts.experience =~ "8 years"
      assert texts.experience =~ "senior"
      assert texts.experience =~ "distributed systems"
      assert texts.experience =~ "MS in Computer Science"
    end

    test "handles minimal data" do
      {:ok, parsed} =
        ResumeParser.validate(%{
          "current_title" => "Developer",
          "skills_primary" => ["Python"]
        })

      texts = ResumeParser.vector_texts(parsed)
      assert texts.skills == "Python"
      assert texts.roles =~ "Developer"
    end
  end

  describe "bootstrap_preferences/2" do
    setup do
      user = insert_user()
      %{user: user}
    end

    test "creates preferences from senior Elixir resume", %{user: user} do
      {:ok, parsed} = ResumeParser.validate(@senior_elixir_parsed)
      assert {:ok, count} = ResumeParser.bootstrap_preferences(user.id, parsed)
      assert count >= 5

      # Verify stored preferences
      skills = Feedback.get_preference(user.id, "skills")
      assert "Elixir" in skills.value["list"]
      assert "Docker" in skills.value["list"]

      seniority = Feedback.get_preference(user.id, "seniority")
      assert seniority.value["level"] == "senior"

      work = Feedback.get_preference(user.id, "work_model")
      assert work.value["preferred"] == "remote"

      salary = Feedback.get_preference(user.id, "salary")
      assert salary.value["min"] == 160_000
      assert salary.value["max"] == 200_000

      roles = Feedback.get_preference(user.id, "roles")
      assert roles.value["current"] == "Senior Software Engineer"
      assert "Staff Engineer" in roles.value["targets"]

      industries = Feedback.get_preference(user.id, "industries")
      assert "fintech" in industries.value["list"]
    end

    test "handles resume with no salary info", %{user: user} do
      {:ok, parsed} = ResumeParser.validate(@junior_python_parsed)
      assert {:ok, _count} = ResumeParser.bootstrap_preferences(user.id, parsed)

      assert Feedback.get_preference(user.id, "salary") == nil
      assert Feedback.get_preference(user.id, "skills") != nil
    end

    test "preferences are idempotent (upsert)", %{user: user} do
      {:ok, parsed} = ResumeParser.validate(@senior_elixir_parsed)

      ResumeParser.bootstrap_preferences(user.id, parsed)
      ResumeParser.bootstrap_preferences(user.id, parsed)

      prefs = Feedback.get_all_preferences(user.id)
      skills_prefs = Enum.filter(prefs, &(&1.preference_type == "skills"))
      assert length(skills_prefs) == 1
    end
  end

  describe "parse/2 with Ollama" do
    @tag :ollama
    test "parses a senior engineer resume" do
      text = """
      JANE SMITH
      Senior Software Engineer | San Francisco, CA | jane@email.com

      EXPERIENCE

      Senior Software Engineer, TechCorp (2020 - Present)
      - Led development of real-time data pipeline processing 10M events/day
      - Built microservices architecture using Elixir, Phoenix, and PostgreSQL
      - Mentored team of 4 junior developers
      - Implemented CI/CD pipeline with GitHub Actions and Docker

      Software Engineer, StartupXYZ (2017 - 2020)
      - Full-stack development with React, Node.js, and MongoDB
      - Built payment integration processing $2M/month
      - Reduced API response times by 60% through caching optimization

      Junior Developer, WebAgency (2015 - 2017)
      - Frontend development with JavaScript, HTML, CSS
      - Client-facing web applications for e-commerce clients

      EDUCATION
      B.S. Computer Science, UC Berkeley, 2015

      SKILLS
      Languages: Elixir, JavaScript, TypeScript, Python, SQL
      Frameworks: Phoenix, React, Node.js, LiveView
      Tools: Docker, Kubernetes, AWS, PostgreSQL, Redis, Git
      """

      assert {:ok, parsed} = ResumeParser.parse(text, provider: :ollama)

      # Core fields should be extracted
      assert parsed.current_title != nil
      assert length(parsed.skills_primary) >= 3
      assert parsed.years_experience >= 7
      assert length(parsed.industries) >= 1

      # Seniority should be senior or staff
      assert parsed.seniority_level in ["senior", "staff"]

      Logger.info("""
      [ResumeParser] Ollama parse results:
        Title: #{parsed.current_title}
        Target: #{inspect(parsed.target_titles)}
        Primary skills: #{inspect(parsed.skills_primary)}
        Secondary: #{inspect(parsed.skills_secondary)}
        Years: #{parsed.years_experience}
        Industries: #{inspect(parsed.industries)}
        Seniority: #{parsed.seniority_level}
        Education: #{inspect(parsed.education)}
        Trajectory: #{parsed.career_trajectory}
      """)
    end

    @tag :ollama
    test "parses a career changer resume" do
      text = """
      ALEX JOHNSON
      Data Analyst | Remote

      EXPERIENCE

      Data Analyst, HealthData Inc (2023 - Present)
      - Analyzed patient outcome data using Python and SQL
      - Built dashboards in Tableau for executive reporting
      - Automated ETL pipelines with Apache Airflow

      High School Math Teacher, Lincoln High (2018 - 2022)
      - Taught AP Statistics and Calculus
      - Developed data-driven curriculum assessments

      EDUCATION
      M.S. Data Science, Georgia Tech (Online), 2023
      B.A. Mathematics, State University, 2018

      CERTIFICATIONS
      Google Data Analytics Professional Certificate
      AWS Cloud Practitioner

      SKILLS
      Python, SQL, Pandas, NumPy, Scikit-learn, Tableau, Excel, Airflow
      """

      assert {:ok, parsed} = ResumeParser.parse(text, provider: :ollama)

      assert parsed.current_title != nil
      assert "Python" in parsed.skills_primary or "python" in Enum.map(parsed.skills_primary, &String.downcase/1)
      assert parsed.years_experience != nil

      Logger.info("""
      [ResumeParser] Career changer results:
        Title: #{parsed.current_title}
        Seniority: #{parsed.seniority_level}
        Years: #{parsed.years_experience}
        Skills: #{inspect(parsed.skills_primary)}
      """)
    end

    @tag :ollama
    test "parses a minimal/early career resume" do
      text = """
      Chris Lee
      chris.lee@email.com | GitHub: github.com/chrislee

      Education
      B.S. Computer Science, MIT, Expected May 2025

      Experience
      Software Engineering Intern, BigTech Co (Summer 2024)
      - Developed REST APIs in Go for internal tooling
      - Wrote unit tests achieving 90% coverage

      Projects
      - Personal blog engine built with Rust and WebAssembly
      - Contributing to open-source Kubernetes operator

      Skills: Go, Rust, Python, JavaScript, Kubernetes, Docker, Git
      """

      assert {:ok, parsed} = ResumeParser.parse(text, provider: :ollama)

      assert parsed.seniority_level in ["intern", "junior"]
      assert length(parsed.skills_primary) >= 2

      Logger.info("""
      [ResumeParser] Early career results:
        Title: #{parsed.current_title}
        Seniority: #{parsed.seniority_level}
        Years: #{parsed.years_experience}
      """)
    end
  end

  # --- Test Helpers ---

  defp insert_user do
    {:ok, user} =
      %Clientats.Accounts.User{}
      |> Clientats.Accounts.User.registration_changeset(%{
        email: "test_#{System.unique_integer([:positive])}@example.com",
        password: "password123456",
        password_confirmation: "password123456",
        first_name: "Test",
        last_name: "User"
      })
      |> Clientats.Repo.insert()

    user
  end
end
