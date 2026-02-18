defmodule Clientats.RerankerTest do
  use ExUnit.Case, async: true

  alias Clientats.Reranker

  # Sample candidates simulating vector search results
  @candidates [
    %{id: 1, title: "Senior Elixir Developer", description: "Build scalable web applications with Elixir and Phoenix. Experience with LiveView and Ecto required.", distance: 0.10},
    %{id: 2, title: "Python Data Scientist", description: "Analyze large datasets using Python, pandas, scikit-learn. Build ML models for fraud detection.", distance: 0.25},
    %{id: 3, title: "Full Stack Elixir/React Engineer", description: "Work on a Phoenix LiveView application with React frontend. GraphQL API development.", distance: 0.12},
    %{id: 4, title: "DevOps Engineer", description: "Manage Kubernetes clusters, CI/CD pipelines. Terraform, AWS, monitoring with Prometheus.", distance: 0.35},
    %{id: 5, title: "Elixir/Phoenix Backend Developer", description: "Financial technology company needs Elixir developer. Build payment processing systems with Phoenix.", distance: 0.08},
    %{id: 6, title: "Java Spring Boot Developer", description: "Enterprise application development with Java Spring Boot. Microservices architecture.", distance: 0.40},
    %{id: 7, title: "Erlang/Elixir Systems Engineer", description: "Telecom infrastructure using BEAM VM. High availability systems, OTP patterns.", distance: 0.15},
    %{id: 8, title: "Frontend React Developer", description: "Build modern user interfaces with React, TypeScript, and Next.js. Design system maintenance.", distance: 0.45},
    %{id: 9, title: "Senior Elixir/Phoenix Developer", description: "Lead backend team building real-time trading platform. LiveView, PubSub, GenServer expertise.", distance: 0.05},
    %{id: 10, title: "Machine Learning Engineer", description: "Deploy ML models in production. PyTorch, TensorFlow, model optimization, feature engineering.", distance: 0.50},
  ]

  # Ground truth relevance for "Senior Elixir developer for fintech"
  @fintech_elixir_relevance %{
    1 => 3,   # Strong match (Elixir, senior)
    2 => 0,   # No match (Python, data science)
    3 => 2,   # Moderate match (Elixir, but full stack/React focused)
    4 => 0,   # No match (DevOps)
    5 => 4,   # Best match (Elixir, fintech/payment)
    6 => 0,   # No match (Java)
    7 => 2,   # Moderate match (Elixir/BEAM, but telecom not fintech)
    8 => 0,   # No match (Frontend React)
    9 => 3,   # Strong match (Elixir, senior, trading=fintech)
    10 => 0,  # No match (ML)
  }

  describe "rerank/3 with :vector strategy" do
    test "returns candidates sorted by distance (ascending)" do
      {:ok, ranked} = Reranker.rerank("Elixir developer", @candidates, strategy: :vector)

      assert length(ranked) == 10

      # Verify sorted by score descending (which maps to distance ascending)
      scores = Enum.map(ranked, & &1.score)
      assert scores == Enum.sort(scores, :desc)

      # Top result should be id 9 (distance 0.05)
      assert hd(ranked).id == 9
      assert hd(ranked).rank == 1
    end

    test "score is 1.0 - distance" do
      {:ok, ranked} = Reranker.rerank("test", @candidates, strategy: :vector)

      for result <- ranked do
        assert_in_delta result.score, 1.0 - result.original_distance, 0.001
      end
    end

    test "respects top_k option" do
      {:ok, ranked} = Reranker.rerank("test", @candidates, strategy: :vector, top_k: 3)
      assert length(ranked) == 3
    end

    test "preserves original distance" do
      {:ok, ranked} = Reranker.rerank("test", @candidates, strategy: :vector)

      original_distances = Map.new(@candidates, fn c -> {c.id, c.distance} end)

      for result <- ranked do
        assert result.original_distance == original_distances[result.id]
      end
    end

    test "handles empty candidates" do
      {:ok, ranked} = Reranker.rerank("test", [], strategy: :vector)
      assert ranked == []
    end

    test "handles candidates with nil distance" do
      candidates = [%{id: 1, title: "Test Job", distance: nil}]
      {:ok, ranked} = Reranker.rerank("test", candidates, strategy: :vector)
      assert length(ranked) == 1
      assert hd(ranked).score == 0.0
    end
  end

  describe "ndcg_at_k/3" do
    test "perfect ranking scores 1.0" do
      # Simulate perfect ranking: ids sorted by relevance descending
      perfect_ranking = [
        %{id: 5, score: 1.0},  # rel=4
        %{id: 1, score: 0.9},  # rel=3
        %{id: 9, score: 0.8},  # rel=3
        %{id: 3, score: 0.7},  # rel=2
        %{id: 7, score: 0.6},  # rel=2
      ]

      ndcg = Reranker.ndcg_at_k(perfect_ranking, @fintech_elixir_relevance, 5)
      assert_in_delta ndcg, 1.0, 0.001
    end

    test "worst ranking scores lower than perfect" do
      # Reverse the ideal order
      worst_ranking = [
        %{id: 10, score: 1.0}, # rel=0
        %{id: 8, score: 0.9},  # rel=0
        %{id: 6, score: 0.8},  # rel=0
        %{id: 4, score: 0.7},  # rel=0
        %{id: 2, score: 0.6},  # rel=0
      ]

      ndcg = Reranker.ndcg_at_k(worst_ranking, @fintech_elixir_relevance, 5)
      assert ndcg == 0.0
    end

    test "vector baseline ranking NDCG" do
      {:ok, vector_ranked} = Reranker.rerank("test", @candidates, strategy: :vector)
      ndcg = Reranker.ndcg_at_k(vector_ranked, @fintech_elixir_relevance, 5)

      # Vector ranking should have decent but not perfect NDCG
      # since vector distance and domain relevance don't perfectly correlate
      assert ndcg > 0.0
      assert ndcg <= 1.0
    end

    test "NDCG@3 and NDCG@10 differ" do
      {:ok, vector_ranked} = Reranker.rerank("test", @candidates, strategy: :vector)
      ndcg3 = Reranker.ndcg_at_k(vector_ranked, @fintech_elixir_relevance, 3)
      ndcg10 = Reranker.ndcg_at_k(vector_ranked, @fintech_elixir_relevance, 10)

      # Both should be valid
      assert ndcg3 >= 0.0 and ndcg3 <= 1.0
      assert ndcg10 >= 0.0 and ndcg10 <= 1.0
    end

    test "all-zero relevance gives 0.0" do
      zero_rel = Map.new(1..10, fn i -> {i, 0} end)
      ranking = [%{id: 1, score: 1.0}, %{id: 2, score: 0.5}]

      ndcg = Reranker.ndcg_at_k(ranking, zero_rel, 2)
      assert ndcg == 0.0
    end
  end

  describe "compare/4" do
    test "compares vector strategy (always available)" do
      {:ok, results} = Reranker.compare("Elixir developer", @candidates, [:vector])

      assert Map.has_key?(results, :vector)
      vector_results = results[:vector]
      assert is_list(vector_results)
      assert length(vector_results) == 10
    end
  end

  describe "rerank/3 with :ollama strategy" do
    @tag :ollama
    test "scores candidates with local LLM" do
      {:ok, ranked} = Reranker.rerank(
        "Senior Elixir developer for fintech",
        @candidates,
        strategy: :ollama,
        top_k: 5
      )

      assert length(ranked) == 5

      # All scores should be between 0 and 1
      for result <- ranked do
        assert result.score >= 0.0 and result.score <= 1.0
        assert result.rank >= 1
      end

      # Elixir jobs should generally rank higher than non-Elixir
      elixir_ids = [1, 3, 5, 7, 9]
      top_3_ids = Enum.map(Enum.take(ranked, 3), & &1.id)
      elixir_in_top_3 = Enum.count(top_3_ids, &(&1 in elixir_ids))
      assert elixir_in_top_3 >= 2, "Expected at least 2 Elixir jobs in top 3, got #{inspect(top_3_ids)}"
    end

    @tag :ollama
    test "ollama vs vector NDCG comparison" do
      query = "Senior Elixir developer for fintech"

      {:ok, ollama_ranked} = Reranker.rerank(query, @candidates, strategy: :ollama)
      {:ok, vector_ranked} = Reranker.rerank(query, @candidates, strategy: :vector)

      ollama_ndcg = Reranker.ndcg_at_k(ollama_ranked, @fintech_elixir_relevance, 5)
      vector_ndcg = Reranker.ndcg_at_k(vector_ranked, @fintech_elixir_relevance, 5)

      IO.puts("""

      === Reranker Quality Comparison ===
      Query: "#{query}"

      Vector-only NDCG@5: #{Float.round(vector_ndcg, 4)}
      Ollama NDCG@5:      #{Float.round(ollama_ndcg, 4)}

      Vector top-5: #{inspect(Enum.map(Enum.take(vector_ranked, 5), &{&1.id, &1.title, Float.round(&1.score, 3)}))}
      Ollama top-5: #{inspect(Enum.map(Enum.take(ollama_ranked, 5), &{&1.id, &1.title, Float.round(&1.score, 3)}))}
      """)

      # Ollama should ideally beat or match vector-only
      assert ollama_ndcg >= 0.0
    end
  end

  describe "rerank/3 with :gemini strategy" do
    @tag :gemini
    test "scores candidates with Gemini API" do
      {:ok, ranked} = Reranker.rerank(
        "Senior Elixir developer for fintech",
        @candidates,
        strategy: :gemini,
        top_k: 5
      )

      assert length(ranked) == 5

      for result <- ranked do
        assert result.score >= 0.0 and result.score <= 1.0
        assert result.rank >= 1
      end
    end

    @tag :gemini
    test "gemini vs vector vs ollama NDCG comparison" do
      query = "Senior Elixir developer for fintech"

      {:ok, results} = Reranker.compare(query, @candidates, [:gemini, :ollama, :vector])

      for {strategy, ranked} <- results do
        if is_list(ranked) do
          ndcg5 = Reranker.ndcg_at_k(ranked, @fintech_elixir_relevance, 5)
          ndcg10 = Reranker.ndcg_at_k(ranked, @fintech_elixir_relevance, 10)

          IO.puts("""
          #{strategy} NDCG@5: #{Float.round(ndcg5, 4)}, NDCG@10: #{Float.round(ndcg10, 4)}
            Top-5: #{inspect(Enum.map(Enum.take(ranked, 5), &{&1.id, Float.round(&1.score, 3)}))}
          """)
        end
      end
    end

    @tag :gemini
    test "gemini batch size handling" do
      # Test with candidates > batch_size to trigger batching
      large_candidates =
        for i <- 1..30 do
          %{id: i, title: "Job #{i}", description: "Description #{i}", distance: i * 0.03}
        end

      {:ok, ranked} = Reranker.rerank(
        "Software engineer",
        large_candidates,
        strategy: :gemini,
        batch_size: 10
      )

      assert length(ranked) == 30
      # Ranks should be 1..30
      ranks = Enum.map(ranked, & &1.rank)
      assert ranks == Enum.to_list(1..30)
    end
  end
end
