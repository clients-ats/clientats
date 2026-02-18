defmodule Clientats.EmbeddingTest do
  use Clientats.DataCase, async: false

  alias Clientats.Embedding

  @sample_jobs [
    "Senior Elixir/Phoenix Developer - Remote fintech startup building payment infrastructure",
    "Senior Elixir Backend Engineer - Healthcare SaaS platform, distributed systems",
    "Senior Elixir Developer - Gaming company, real-time multiplayer systems",
    "Junior Python Developer - Data analytics startup, pandas/scikit-learn",
    "Staff Frontend Engineer - React/TypeScript, design system at e-commerce company",
    "Senior Elixir Developer - Telecom, building high-availability messaging platform",
    "DevOps Engineer - Kubernetes, Terraform, CI/CD pipelines",
    "Senior Elixir Developer - Financial services, trading platform backend",
    "Machine Learning Engineer - PyTorch, computer vision, autonomous vehicles",
    "Senior Elixir/Phoenix Developer - EdTech startup, real-time collaboration"
  ]

  describe "Ollama embeddings" do
    @tag :ollama
    test "single embedding generation" do
      {:ok, embedding} = Embedding.embed("Senior Elixir Developer", provider: :ollama)

      assert is_list(embedding)
      assert length(embedding) == 768
      assert Enum.all?(embedding, &is_float/1)
    end

    @tag :ollama
    test "batch embedding generation" do
      {:ok, embeddings} = Embedding.embed_batch(@sample_jobs, provider: :ollama)

      assert length(embeddings) == length(@sample_jobs)
      assert Enum.all?(embeddings, fn emb -> length(emb) == 768 end)
    end

    @tag :ollama
    test "similar jobs have higher cosine similarity than different ones" do
      {:ok, [elixir_fintech, elixir_health, python_data | _]} =
        Embedding.embed_batch(
          [
            "Senior Elixir Developer - Fintech startup",
            "Senior Elixir Engineer - Healthcare platform",
            "Junior Python Developer - Data analytics"
          ],
          provider: :ollama
        )

      elixir_sim = Embedding.cosine_similarity(elixir_fintech, elixir_health)
      cross_sim = Embedding.cosine_similarity(elixir_fintech, python_data)

      assert elixir_sim > cross_sim,
             "Elixir-Elixir similarity (#{elixir_sim}) should exceed Elixir-Python (#{cross_sim})"
    end

    @tag :ollama
    test "query embedding ranks similar jobs higher" do
      {:ok, embeddings} = Embedding.embed_batch(@sample_jobs, provider: :ollama)
      {:ok, query_vec} = Embedding.embed("Elixir developer financial services", provider: :ollama)

      ranked =
        embeddings
        |> Enum.with_index()
        |> Enum.map(fn {emb, idx} -> {idx, Embedding.cosine_similarity(query_vec, emb)} end)
        |> Enum.sort_by(fn {_, sim} -> -sim end)

      # Financial services Elixir job (index 7) should be in top 3
      top_3_indices = ranked |> Enum.take(3) |> Enum.map(fn {idx, _} -> idx end)
      assert 7 in top_3_indices, "Financial services job should rank in top 3, got: #{inspect(top_3_indices)}"

      # ML engineer (index 8) should be in bottom 3
      bottom_3_indices = ranked |> Enum.take(-3) |> Enum.map(fn {idx, _} -> idx end)
      assert 8 in bottom_3_indices, "ML engineer should rank in bottom 3, got: #{inspect(bottom_3_indices)}"
    end
  end

  describe "Gemini embeddings" do
    @tag :gemini
    test "single embedding generation" do
      {:ok, embedding} = Embedding.embed("Senior Elixir Developer", provider: :gemini)

      assert is_list(embedding)
      assert length(embedding) > 0
      assert Enum.all?(embedding, &is_number/1)
    end

    @tag :gemini
    test "batch embedding generation" do
      texts = Enum.take(@sample_jobs, 3)
      {:ok, embeddings} = Embedding.embed_batch(texts, provider: :gemini)

      assert length(embeddings) == 3
    end

    @tag :gemini
    test "similar jobs cluster correctly" do
      {:ok, [elixir1, elixir2, python | _]} =
        Embedding.embed_batch(
          [
            "Senior Elixir Developer - Fintech",
            "Senior Elixir Engineer - Healthcare",
            "Python Data Scientist - Machine Learning"
          ],
          provider: :gemini
        )

      elixir_sim = Embedding.cosine_similarity(elixir1, elixir2)
      cross_sim = Embedding.cosine_similarity(elixir1, python)

      assert elixir_sim > cross_sim
    end
  end

  describe "cosine_similarity/2" do
    test "identical vectors return 1.0" do
      vec = [1.0, 2.0, 3.0]
      assert_in_delta Embedding.cosine_similarity(vec, vec), 1.0, 0.001
    end

    test "orthogonal vectors return 0.0" do
      assert_in_delta Embedding.cosine_similarity([1.0, 0.0], [0.0, 1.0]), 0.0, 0.001
    end

    test "opposite vectors return -1.0" do
      assert_in_delta Embedding.cosine_similarity([1.0, 0.0], [-1.0, 0.0]), -1.0, 0.001
    end
  end

  describe "default_provider/0" do
    test "returns :ollama when no Gemini key configured" do
      # In test env, GEMINI_API_KEY is typically not set
      assert Embedding.default_provider() == :ollama
    end
  end

  describe "dimensions/1" do
    test "returns 768 for ollama" do
      assert Embedding.dimensions(provider: :ollama) == 768
    end

    test "returns 768 for gemini by default" do
      assert Embedding.dimensions(provider: :gemini) == 768
    end

    test "respects custom dimensions for gemini" do
      assert Embedding.dimensions(provider: :gemini, dimensions: 256) == 256
    end
  end

  describe "latency benchmarks" do
    @tag :benchmark
    @tag :ollama
    test "single and batch embedding latency" do
      # Single
      {single_us, {:ok, _}} = :timer.tc(fn -> Embedding.embed("test text", provider: :ollama) end)

      # Batch sizes
      for batch_size <- [5, 10, 50] do
        texts = for i <- 1..batch_size, do: "Job description number #{i} for testing embedding latency"
        {batch_us, {:ok, embeddings}} = :timer.tc(fn -> Embedding.embed_batch(texts, provider: :ollama) end)

        assert length(embeddings) == batch_size

        IO.puts("""
        Batch #{batch_size}: #{Float.round(batch_us / 1_000, 1)}ms total, #{Float.round(batch_us / 1_000 / batch_size, 1)}ms/text
        """)
      end

      IO.puts("Single: #{Float.round(single_us / 1_000, 1)}ms")
    end
  end
end
