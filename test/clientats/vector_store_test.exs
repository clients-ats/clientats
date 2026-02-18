defmodule Clientats.VectorStoreTest do
  use Clientats.DataCase, async: false

  alias Clientats.VectorStore

  @dim 768

  # Generate a random vector of given dimension
  defp random_vec(dim \\ @dim) do
    for _ <- 1..dim, do: :rand.normal()
  end

  # Generate a vector biased toward a "topic" (deterministic seed + offset)
  defp topic_vec(seed, dim \\ @dim) do
    :rand.seed(:exsss, {seed, seed * 7, seed * 13})
    for _ <- 1..dim, do: :rand.normal()
  end

  describe "vec_version/0" do
    test "returns sqlite-vec version" do
      version = VectorStore.vec_version()
      assert version =~ "v0.1"
    end
  end

  describe "upsert and retrieve" do
    test "insert and count embeddings" do
      vec = random_vec()
      VectorStore.upsert_embedding(1, vec, vec)
      assert VectorStore.count() >= 1
    end

    test "upsert replaces existing embedding" do
      vec1 = random_vec()
      vec2 = random_vec()

      VectorStore.upsert_embedding(100, vec1, vec1)
      VectorStore.upsert_embedding(100, vec2, vec2)

      # Should still be just one row for id 100
      result = VectorStore.search_by_title(vec2, 10)
      matching = Enum.filter(result.rows, fn [id, _dist] -> id == 100 end)
      assert length(matching) == 1
    end
  end

  describe "KNN search" do
    test "finds nearest neighbors by title" do
      # Insert 3 vectors: two similar, one different
      base = topic_vec(42)
      similar = topic_vec(42) |> Enum.zip(random_vec()) |> Enum.map(fn {a, b} -> a + b * 0.1 end)
      different = topic_vec(999)

      VectorStore.upsert_embedding(10, base, base)
      VectorStore.upsert_embedding(11, similar, similar)
      VectorStore.upsert_embedding(12, different, different)

      result = VectorStore.search_by_title(base, 3)
      assert length(result.rows) == 3

      # First result should be the exact match (id 10)
      [[first_id, first_dist] | _] = result.rows
      assert first_id == 10
      assert first_dist < 0.01
    end

    test "finds nearest neighbors by description" do
      vec = random_vec()
      VectorStore.upsert_embedding(20, random_vec(), vec)

      result = VectorStore.search_by_description(vec, 5)
      assert length(result.rows) >= 1
      [[id, dist] | _] = result.rows
      assert id == 20
      assert dist < 0.01
    end
  end

  describe "delete" do
    test "removes embedding" do
      vec = random_vec()
      VectorStore.upsert_embedding(30, vec, vec)
      VectorStore.delete_embedding(30)

      result = VectorStore.search_by_title(vec, 10)
      ids = Enum.map(result.rows, fn [id, _] -> id end)
      refute 30 in ids
    end
  end

  describe "join with job_interests" do
    test "search_jobs_by_title returns job details" do
      # Create a real job_interest record
      {:ok, user} =
        Clientats.Accounts.register_user(%{
          email: "test@example.com",
          password: "password123456",
          first_name: "Test",
          last_name: "User"
        })

      {:ok, job} =
        Clientats.Jobs.create_job_interest(%{
          position_title: "Senior Elixir Developer",
          company_name: "TestCorp",
          location: "Remote",
          job_url: "https://example.com/job/1",
          status: "interested",
          user_id: user.id
        })

      vec = random_vec()
      VectorStore.upsert_embedding(job.id, vec, vec)

      result = VectorStore.search_jobs_by_title(vec, 5)
      assert length(result.rows) >= 1

      [id, position_title, company_name, location, _dist] = hd(result.rows)
      assert id == job.id
      assert position_title == "Senior Elixir Developer"
      assert company_name == "TestCorp"
      assert location == "Remote"
    end
  end

  describe "benchmarks" do
    @tag :benchmark
    test "insert and query performance at scale" do
      counts = [100, 1_000, 5_000]

      for count <- counts do
        # Clean slate - delete previous test vectors
        Ecto.Adapters.SQL.query!(Clientats.Repo, "DELETE FROM vec_job_embeddings", [])

        # Batch insert
        {insert_us, _} =
          :timer.tc(fn ->
            for i <- 1..count do
              VectorStore.upsert_embedding(i, random_vec(), random_vec())
            end
          end)

        insert_ms = insert_us / 1_000

        # Query top-10
        query_vec = random_vec()

        {query10_us, result10} =
          :timer.tc(fn ->
            VectorStore.search_by_title(query_vec, 10)
          end)

        query10_ms = query10_us / 1_000

        # Query top-100
        {query100_us, result100} =
          :timer.tc(fn ->
            VectorStore.search_by_title(query_vec, 100)
          end)

        query100_ms = query100_us / 1_000

        IO.puts("""

        === Benchmark: #{count} vectors (#{@dim}d) ===
        Insert #{count}: #{Float.round(insert_ms, 1)}ms (#{Float.round(insert_ms / count, 2)}ms/vec)
        KNN top-10:  #{Float.round(query10_ms, 2)}ms (#{length(result10.rows)} results)
        KNN top-100: #{Float.round(query100_ms, 2)}ms (#{length(result100.rows)} results)
        """)

        assert length(result10.rows) == min(10, count)
      end
    end
  end
end
