defmodule Clientats.SearchPipelineTest do
  @moduledoc """
  End-to-end test for the vector search pipeline.
  Spike azyf: embed jobs → store in sqlite-vec → search by query.
  """
  use Clientats.DataCase, async: false

  alias Clientats.{Embedding, VectorStore}

  @sample_jobs [
    %{
      position_title: "Senior Elixir/Phoenix Developer",
      company_name: "PayStream",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 150_000,
      salary_max: 200_000,
      job_description:
        "Build payment infrastructure using Elixir/Phoenix. Work on real-time transaction processing, distributed systems, and API design. Experience with financial systems required."
    },
    %{
      position_title: "Senior Elixir Backend Engineer",
      company_name: "MedTech Solutions",
      location: "Boston, MA",
      work_model: "hybrid",
      salary_min: 140_000,
      salary_max: 180_000,
      job_description:
        "Healthcare SaaS platform built on Elixir/OTP. Work on HIPAA-compliant data pipelines, distributed event processing, and real-time patient monitoring systems."
    },
    %{
      position_title: "Elixir Developer",
      company_name: "GameForge Studios",
      location: "Austin, TX",
      work_model: "on_site",
      salary_min: 120_000,
      salary_max: 160_000,
      job_description:
        "Build real-time multiplayer game servers using Elixir/OTP. WebSocket management, matchmaking systems, and leaderboard services. Gaming industry experience a plus."
    },
    %{
      position_title: "Junior Python Developer",
      company_name: "DataViz Inc",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 70_000,
      salary_max: 95_000,
      job_description:
        "Data analytics startup looking for Python developer. Work with pandas, scikit-learn, and matplotlib. Build data pipelines and dashboards for business intelligence."
    },
    %{
      position_title: "Staff Frontend Engineer",
      company_name: "ShopRight",
      location: "San Francisco, CA",
      work_model: "hybrid",
      salary_min: 180_000,
      salary_max: 250_000,
      job_description:
        "Lead frontend architecture for e-commerce platform. React, TypeScript, design systems, micro-frontends. Mentor junior engineers and drive technical strategy."
    },
    %{
      position_title: "Senior Elixir Developer",
      company_name: "TeleConnect",
      location: "Remote, EU",
      work_model: "remote",
      salary_min: 130_000,
      salary_max: 170_000,
      job_description:
        "Telecom company building high-availability messaging platform. Elixir/OTP for distributed message routing, fault tolerance, and carrier-grade uptime requirements."
    },
    %{
      position_title: "DevOps Engineer",
      company_name: "CloudScale",
      location: "Seattle, WA",
      work_model: "hybrid",
      salary_min: 140_000,
      salary_max: 190_000,
      job_description:
        "Kubernetes, Terraform, CI/CD pipelines. Manage infrastructure for a SaaS platform serving millions of users. On-call rotation and incident response."
    },
    %{
      position_title: "Senior Elixir Developer",
      company_name: "TradeTech Capital",
      location: "New York, NY",
      work_model: "hybrid",
      salary_min: 170_000,
      salary_max: 220_000,
      job_description:
        "Financial services firm building next-gen trading platform. Elixir for low-latency order processing, market data streaming, and risk calculation engines."
    },
    %{
      position_title: "Machine Learning Engineer",
      company_name: "AutoDrive AI",
      location: "Palo Alto, CA",
      work_model: "on_site",
      salary_min: 200_000,
      salary_max: 300_000,
      job_description:
        "PyTorch, computer vision, autonomous vehicle perception systems. Train and deploy deep learning models for object detection and scene understanding."
    },
    %{
      position_title: "Senior Elixir/Phoenix Developer",
      company_name: "LearnHub",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 140_000,
      salary_max: 185_000,
      job_description:
        "EdTech startup building real-time collaboration platform. Elixir/Phoenix LiveView for interactive learning experiences, video streaming, and content management."
    },
    %{
      position_title: "Rust Systems Engineer",
      company_name: "SecureCore",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 160_000,
      salary_max: 210_000,
      job_description:
        "Build high-performance security infrastructure in Rust. Memory-safe network protocols, cryptographic libraries, and zero-trust architecture components."
    },
    %{
      position_title: "Senior Go Developer",
      company_name: "DistributeDB",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 155_000,
      salary_max: 200_000,
      job_description:
        "Distributed database company. Build consensus algorithms, storage engines, and replication systems in Go. Experience with Raft/Paxos preferred."
    },
    %{
      position_title: "Elixir/Phoenix Full Stack Developer",
      company_name: "InsureTech Pro",
      location: "Chicago, IL",
      work_model: "hybrid",
      salary_min: 130_000,
      salary_max: 165_000,
      job_description:
        "Insurance technology platform. Build LiveView interfaces for policy management, claims processing, and underwriting workflows. PostgreSQL and Elixir experience required."
    },
    %{
      position_title: "Senior Java Developer",
      company_name: "BigBank Corp",
      location: "Charlotte, NC",
      work_model: "on_site",
      salary_min: 140_000,
      salary_max: 180_000,
      job_description:
        "Enterprise banking systems. Spring Boot microservices, Oracle database, message queues. Maintain and modernize legacy core banking platform."
    },
    %{
      position_title: "Senior Elixir Engineer",
      company_name: "StreamFlow",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 145_000,
      salary_max: 195_000,
      job_description:
        "Real-time data streaming platform. Elixir/OTP for high-throughput event processing, GenStage pipelines, and Broadway consumers. Handle millions of events per second."
    },
    %{
      position_title: "iOS Developer",
      company_name: "AppMakers",
      location: "Los Angeles, CA",
      work_model: "hybrid",
      salary_min: 130_000,
      salary_max: 175_000,
      job_description:
        "Build consumer mobile apps in Swift/SwiftUI. Work on social features, push notifications, and in-app purchases. App Store optimization experience preferred."
    },
    %{
      position_title: "Data Engineer",
      company_name: "AnalyticsNow",
      location: "Denver, CO",
      work_model: "remote",
      salary_min: 135_000,
      salary_max: 175_000,
      job_description:
        "Build data pipelines using Apache Spark, Airflow, and dbt. Data warehouse design, ETL optimization, and real-time analytics for a marketing analytics platform."
    },
    %{
      position_title: "Senior Elixir Developer",
      company_name: "HealthPulse",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 150_000,
      salary_max: 190_000,
      job_description:
        "Health tech startup. Elixir/Phoenix for FHIR-compliant API servers, patient data integration, and clinical workflow automation. Healthcare domain experience valued."
    },
    %{
      position_title: "Platform Engineer",
      company_name: "ScaleUp Inc",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 160_000,
      salary_max: 210_000,
      job_description:
        "Internal developer platform team. Build deployment pipelines, service meshes, and observability infrastructure. Kubernetes, Istio, Prometheus, Grafana."
    },
    %{
      position_title: "Senior Elixir/Nerves IoT Engineer",
      company_name: "SmartFactory",
      location: "Detroit, MI",
      work_model: "hybrid",
      salary_min: 140_000,
      salary_max: 180_000,
      job_description:
        "Industrial IoT platform using Elixir/Nerves. Build firmware for edge devices, MQTT message brokers, and real-time sensor data processing for manufacturing."
    },
    %{
      position_title: "Senior Ruby on Rails Developer",
      company_name: "ShopTool",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 140_000,
      salary_max: 180_000,
      job_description:
        "E-commerce platform built on Rails. Inventory management, order processing, payment integrations. High-traffic system serving millions of daily transactions."
    },
    %{
      position_title: "Elixir/LiveView Developer",
      company_name: "FinanceFlow",
      location: "Remote, USA",
      work_model: "remote",
      salary_min: 135_000,
      salary_max: 175_000,
      job_description:
        "Personal finance management app. Build interactive LiveView dashboards for budgeting, investment tracking, and financial goal planning. Strong UI/UX sensibility."
    }
  ]

  setup do
    # Create a user for FK constraints
    {:ok, user} =
      Clientats.Accounts.register_user(%{
        email: "pipeline-test@example.com",
        password: "password123456",
        first_name: "Pipeline",
        last_name: "Test"
      })

    # Insert all sample jobs into DB
    jobs =
      Enum.map(@sample_jobs, fn attrs ->
        {:ok, job} =
          Clientats.Jobs.create_job_interest(
            Map.merge(attrs, %{user_id: user.id, status: "interested"})
          )

        job
      end)

    # Generate embeddings for all jobs
    titles = Enum.map(@sample_jobs, & &1.position_title)
    descriptions = Enum.map(@sample_jobs, & &1.job_description)

    {:ok, title_embeddings} = Embedding.embed_batch(titles, provider: :ollama)
    {:ok, desc_embeddings} = Embedding.embed_batch(descriptions, provider: :ollama)

    # Store in sqlite-vec
    Enum.zip([jobs, title_embeddings, desc_embeddings])
    |> Enum.each(fn {job, title_emb, desc_emb} ->
      VectorStore.upsert_embedding(job.id, title_emb, desc_emb)
    end)

    %{user: user, jobs: jobs, title_embeddings: title_embeddings, desc_embeddings: desc_embeddings}
  end

  describe "natural language search over 20+ jobs" do
    @tag :ollama
    test "query returns semantically relevant results", %{jobs: jobs} do
      {:ok, query_vec} =
        Embedding.embed("Elixir developer with financial services experience", provider: :ollama)

      result = VectorStore.search_by_title(query_vec, 10)
      assert length(result.rows) == 10

      top_5_ids = result.rows |> Enum.take(5) |> Enum.map(fn [id, _] -> id end)
      top_5_titles = Enum.map(top_5_ids, fn id ->
        Enum.find(jobs, &(&1.id == id)).position_title
      end)

      IO.puts("\n=== Query: 'Elixir developer with financial services' ===")
      for {[id, dist], idx} <- Enum.with_index(Enum.take(result.rows, 10)) do
        job = Enum.find(jobs, &(&1.id == id))
        IO.puts("  #{idx + 1}. [#{Float.round(dist, 4)}] #{job.position_title} @ #{job.company_name}")
      end

      # Verify: Elixir jobs should dominate top 5
      elixir_in_top5 = Enum.count(top_5_titles, &String.contains?(&1, "Elixir"))
      assert elixir_in_top5 >= 3, "Expected >=3 Elixir jobs in top 5, got #{elixir_in_top5}"
    end

    @tag :ollama
    test "different queries surface different results", %{jobs: jobs} do
      {:ok, ml_query} = Embedding.embed("machine learning computer vision deep learning", provider: :ollama)
      {:ok, devops_query} = Embedding.embed("kubernetes infrastructure deployment pipelines", provider: :ollama)

      ml_results = VectorStore.search_by_title(ml_query, 5)
      devops_results = VectorStore.search_by_title(devops_query, 5)

      ml_top = hd(ml_results.rows) |> hd()
      devops_top = hd(devops_results.rows) |> hd()

      ml_job = Enum.find(jobs, &(&1.id == ml_top))
      devops_job = Enum.find(jobs, &(&1.id == devops_top))

      IO.puts("\n=== ML query top result: #{ml_job.position_title} @ #{ml_job.company_name}")
      IO.puts("=== DevOps query top result: #{devops_job.position_title} @ #{devops_job.company_name}")

      assert String.contains?(ml_job.position_title, "Machine Learning") or
               String.contains?(ml_job.job_description || "", "deep learning")

      assert String.contains?(devops_job.position_title, "DevOps") or
               String.contains?(devops_job.position_title, "Platform") or
               String.contains?(devops_job.job_description || "", "Kubernetes")
    end
  end

  describe "multi-vector search" do
    @tag :ollama
    test "weighted title + description search improves results", %{jobs: jobs} do
      # Query that's more specific in description than title
      {:ok, title_query} = Embedding.embed("Elixir developer", provider: :ollama)
      {:ok, desc_query} =
        Embedding.embed(
          "payment processing financial transactions low-latency trading",
          provider: :ollama
        )

      # Title-only search
      title_results = VectorStore.search_by_title(title_query, 10)

      # Multi-vector search (title 0.3, description 0.7)
      multi_results =
        VectorStore.search_multi_vector(title_query, desc_query, 10,
          title_weight: 0.3,
          desc_weight: 0.7
        )

      IO.puts("\n=== Title-only search: 'Elixir developer' ===")
      for {[id, dist], idx} <- Enum.with_index(Enum.take(title_results.rows, 5)) do
        job = Enum.find(jobs, &(&1.id == id))
        IO.puts("  #{idx + 1}. [#{Float.round(dist, 4)}] #{job.position_title} @ #{job.company_name}")
      end

      IO.puts("\n=== Multi-vector (title=0.3 + desc=0.7): 'payment/financial/trading' ===")
      for {{id, combined, _td, _dd}, idx} <- Enum.with_index(Enum.take(multi_results, 5)) do
        job = Enum.find(jobs, &(&1.id == id))
        IO.puts("  #{idx + 1}. [#{Float.round(combined, 4)}] #{job.position_title} @ #{job.company_name}")
      end

      # Multi-vector should prioritize financial Elixir jobs higher
      multi_top_3_ids = multi_results |> Enum.take(3) |> Enum.map(fn {id, _, _, _} -> id end)
      multi_top_3_companies =
        Enum.map(multi_top_3_ids, fn id -> Enum.find(jobs, &(&1.id == id)).company_name end)

      financial_in_top3 =
        Enum.count(multi_top_3_companies, fn c ->
          c in ["PayStream", "TradeTech Capital", "FinanceFlow"]
        end)

      assert financial_in_top3 >= 1,
             "Expected financial companies in multi-vector top 3, got: #{inspect(multi_top_3_companies)}"
    end
  end

  describe "hard filter + vector search" do
    @tag :ollama
    test "filter by work_model=remote narrows results", %{jobs: jobs} do
      {:ok, query_vec} = Embedding.embed("Elixir developer", provider: :ollama)

      # Unfiltered
      unfiltered = VectorStore.search_filtered(query_vec, 10)
      # Filtered to remote only
      remote_only = VectorStore.search_filtered(query_vec, 10, %{work_model: "remote"})

      IO.puts("\n=== Unfiltered search: #{length(unfiltered.rows)} results ===")
      for [id, title, company, loc, wm, _, _, dist] <- Enum.take(unfiltered.rows, 5) do
        IO.puts("  [#{Float.round(dist, 4)}] #{title} @ #{company} (#{wm || "?"}, #{loc})")
      end

      IO.puts("\n=== Remote-only filter: #{length(remote_only.rows)} results ===")
      for [id, title, company, loc, wm, _, _, dist] <- Enum.take(remote_only.rows, 5) do
        IO.puts("  [#{Float.round(dist, 4)}] #{title} @ #{company} (#{wm || "?"}, #{loc})")
      end

      # All remote results should have work_model = "remote"
      remote_work_models =
        Enum.map(remote_only.rows, fn [_, _, _, _, wm, _, _, _] -> wm end)

      assert Enum.all?(remote_work_models, &(&1 == "remote")),
             "Expected all remote, got: #{inspect(remote_work_models)}"

      # Remote results should be fewer than unfiltered
      assert length(remote_only.rows) <= length(unfiltered.rows)
    end

    @tag :ollama
    test "filter by salary minimum", %{jobs: _jobs} do
      {:ok, query_vec} = Embedding.embed("senior developer", provider: :ollama)

      high_salary = VectorStore.search_filtered(query_vec, 10, %{salary_min: 160_000})

      # All results should have salary_max >= 160K (or null)
      for [_, _, _, _, _, _, salary_max, _] <- high_salary.rows do
        assert is_nil(salary_max) or salary_max >= 160_000
      end
    end

    @tag :ollama
    test "filter by excluded companies", %{jobs: _jobs} do
      {:ok, query_vec} = Embedding.embed("Elixir developer", provider: :ollama)

      excluded =
        VectorStore.search_filtered(query_vec, 10, %{
          exclude_companies: ["PayStream", "TradeTech Capital"]
        })

      company_names = Enum.map(excluded.rows, fn [_, _, company, _, _, _, _, _] -> company end)
      refute "PayStream" in company_names
      refute "TradeTech Capital" in company_names
    end

    @tag :ollama
    test "location filter", %{jobs: _jobs} do
      {:ok, query_vec} = Embedding.embed("software developer", provider: :ollama)

      ny_results = VectorStore.search_filtered(query_vec, 10, %{location: "New York"})

      for [_, _, _, loc, _, _, _, _] <- ny_results.rows do
        assert String.contains?(loc, "New York"),
               "Expected New York location, got: #{loc}"
      end
    end
  end

  describe "end-to-end latency" do
    @tag :ollama
    @tag :benchmark
    test "full pipeline under 2 seconds", %{jobs: jobs} do
      query = "Senior Elixir developer at a fintech company building payment systems"

      {total_us, results} =
        :timer.tc(fn ->
          # Step 1: Embed the query
          {:ok, query_vec} = Embedding.embed(query, provider: :ollama)

          # Step 2: KNN search
          search_result = VectorStore.search_by_title(query_vec, 10)

          # Step 3: Enrich with job details (simulating real use)
          Enum.map(search_result.rows, fn [id, distance] ->
            job = Enum.find(jobs, &(&1.id == id))
            %{id: id, distance: distance, title: job.position_title, company: job.company_name}
          end)
        end)

      total_ms = total_us / 1_000

      IO.puts("\n=== E2E Pipeline Latency ===")
      IO.puts("Total: #{Float.round(total_ms, 1)}ms")
      IO.puts("Results: #{length(results)} jobs")
      for r <- Enum.take(results, 5) do
        IO.puts("  [#{Float.round(r.distance, 4)}] #{r.title} @ #{r.company}")
      end

      assert total_ms < 2_000, "E2E pipeline took #{total_ms}ms, expected < 2000ms"
    end

    @tag :ollama
    @tag :benchmark
    test "multi-vector pipeline latency", %{jobs: jobs} do
      {total_us, results} =
        :timer.tc(fn ->
          {:ok, title_vec} = Embedding.embed("Elixir developer", provider: :ollama)
          {:ok, desc_vec} = Embedding.embed("distributed systems real-time processing", provider: :ollama)

          VectorStore.search_multi_vector(title_vec, desc_vec, 10,
            title_weight: 0.4,
            desc_weight: 0.6
          )
        end)

      IO.puts("\n=== Multi-Vector Pipeline Latency ===")
      IO.puts("Total: #{Float.round(total_us / 1_000, 1)}ms (includes 2 embeds + 2 KNN queries + merge)")

      assert total_us / 1_000 < 2_000
    end
  end

  describe "purge scenario" do
    @tag :ollama
    test "deleting jobs removes them from search results", %{jobs: jobs} do
      {:ok, query_vec} = Embedding.embed("Elixir developer", provider: :ollama)

      # Get results before delete
      before = VectorStore.search_by_title(query_vec, length(jobs))
      before_count = length(before.rows)

      # Delete first 3 jobs' embeddings
      delete_ids = Enum.take(jobs, 3) |> Enum.map(& &1.id)
      Enum.each(delete_ids, &VectorStore.delete_embedding/1)

      # Get results after delete
      after_result = VectorStore.search_by_title(query_vec, length(jobs))
      after_count = length(after_result.rows)

      assert after_count == before_count - 3
      after_ids = Enum.map(after_result.rows, fn [id, _] -> id end)
      for id <- delete_ids, do: refute(id in after_ids)
    end
  end
end
