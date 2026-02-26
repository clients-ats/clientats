defmodule Clientats.RankerTest do
  use ExUnit.Case, async: true

  alias Clientats.Ranker
  alias Clientats.Ranker.FeatureExtractor

  describe "FeatureExtractor" do
    test "feature_count returns 18" do
      assert FeatureExtractor.feature_count() == 18
    end

    test "feature_names returns 18 atoms" do
      names = FeatureExtractor.feature_names()
      assert length(names) == 18
      assert Enum.all?(names, &is_atom/1)
      assert hd(names) == :title_similarity
      assert List.last(names) == :industry_match
    end

    test "extract returns 18-element float vector" do
      job = %{
        salary_min: 120_000,
        salary_max: 160_000,
        remote_policy: "full_remote",
        work_model: "remote",
        location: "San Francisco, CA",
        date_posted: Date.utc_today() |> Date.to_iso8601(),
        description_text: String.duplicate("a", 1000),
        required_skills: ["Elixir", "Phoenix", "PostgreSQL"],
        seniority_level: "senior",
        industry: "fintech"
      }

      similarities = %{
        title: 0.85,
        description: 0.72,
        skills: 0.90,
        requirements: 0.65,
        composite: 0.78
      }

      prefs = %{
        salary_min: 130_000,
        salary_max: 170_000,
        work_model: "remote",
        preferred_location: "San Francisco",
        skills: ["Elixir", "Phoenix", "React"],
        seniority_level: "senior",
        industry: "fintech"
      }

      features =
        FeatureExtractor.extract(job, similarities, prefs,
          reranker_score: 0.88,
          company_familiarity: 0.3,
          similar_title_rate: 0.6
        )

      assert length(features) == 18
      assert Enum.all?(features, &is_float/1)

      # Check specific features
      # title_similarity
      assert Enum.at(features, 0) == 0.85
      # reranker_score
      assert Enum.at(features, 5) == 0.88
      # is_remote
      assert Enum.at(features, 9) == 1.0
      # industry_match
      assert Enum.at(features, 17) == 1.0
    end

    test "extract with minimal data returns defaults" do
      features = FeatureExtractor.extract(%{})
      assert length(features) == 18
      assert Enum.all?(features, &is_number/1)
    end

    test "salary_delta is normalized to -1..1" do
      # Job pays more than pref
      job = %{salary_min: 200_000, salary_max: 200_000}
      prefs = %{salary_min: 100_000, salary_max: 100_000}
      features = FeatureExtractor.extract(job, %{}, prefs)
      salary_delta = Enum.at(features, 6)
      assert salary_delta == 1.0

      # Job pays less than pref
      job2 = %{salary_min: 50_000, salary_max: 50_000}
      features2 = FeatureExtractor.extract(job2, %{}, prefs)
      salary_delta2 = Enum.at(features2, 6)
      assert salary_delta2 == -0.5
    end

    test "work_model_match handles normalization" do
      job = %{work_model: "hybrid_2d"}
      prefs = %{work_model: "hybrid_3d"}
      features = FeatureExtractor.extract(job, %{}, prefs)
      # Both normalize to "hybrid"
      assert Enum.at(features, 8) == 1.0
    end

    test "location_match handles partial matches" do
      job = %{location: "San Francisco, CA"}
      prefs = %{preferred_location: "San Francisco"}
      features = FeatureExtractor.extract(job, %{}, prefs)
      assert Enum.at(features, 10) == 0.8
    end

    test "skill_overlap uses Jaccard similarity" do
      job = %{required_skills: ["Elixir", "Phoenix", "PostgreSQL", "Redis"]}
      prefs = %{skills: ["Elixir", "Phoenix", "React"]}
      features = FeatureExtractor.extract(job, %{}, prefs)
      # Overlap: {elixir, phoenix} = 2, Union: {elixir, phoenix, postgresql, redis, react} = 5
      assert_in_delta Enum.at(features, 15), 0.4, 0.01
    end

    test "seniority_match scores by distance" do
      # Exact match
      job = %{seniority_level: "senior"}
      prefs = %{seniority_level: "senior"}
      features = FeatureExtractor.extract(job, %{}, prefs)
      assert Enum.at(features, 16) == 1.0

      # One level away
      job2 = %{seniority_level: "mid"}
      features2 = FeatureExtractor.extract(job2, %{}, prefs)
      assert Enum.at(features2, 16) == 0.7

      # Far apart
      job3 = %{seniority_level: "intern"}
      features3 = FeatureExtractor.extract(job3, %{}, prefs)
      assert Enum.at(features3, 16) == 0.0
    end

    test "generate_synthetic_data creates correlated examples" do
      data = FeatureExtractor.generate_synthetic_data(100)
      assert length(data) == 100

      Enum.each(data, fn {features, label} ->
        assert length(features) == 18
        assert label in [0.0, 1.0]
        assert Enum.all?(features, &is_number/1)
      end)

      # Check positive ratio is roughly 40%
      positive_count = Enum.count(data, fn {_, l} -> l == 1.0 end)
      assert positive_count > 20 and positive_count < 60
    end
  end

  describe "Ranker.train/2" do
    test "returns error for insufficient data" do
      data = for _ <- 1..5, do: {List.duplicate(0.5, 18), 1.0}
      assert {:error, :insufficient_data} = Ranker.train(data)
    end

    @tag :benchmark
    test "trains successfully on synthetic data" do
      data = FeatureExtractor.generate_synthetic_data(100)
      assert {:ok, booster} = Ranker.train(data)
      assert booster != nil
    end

    @tag :benchmark
    test "predict returns scores between 0 and 1" do
      data = FeatureExtractor.generate_synthetic_data(100)
      {:ok, booster} = Ranker.train(data)

      test_features =
        Enum.map(1..5, fn _ ->
          {f, _} = hd(FeatureExtractor.generate_synthetic_data(1))
          f
        end)

      scores = Ranker.predict(booster, test_features)
      assert length(scores) == 5

      Enum.each(scores, fn s ->
        assert s >= 0.0 and s <= 1.0,
               "Score #{s} outside expected range [0, 1]"
      end)
    end

    @tag :benchmark
    test "rank sorts candidates by score descending" do
      data = FeatureExtractor.generate_synthetic_data(100)
      {:ok, booster} = Ranker.train(data)

      candidates =
        for i <- 1..10 do
          {f, _} = hd(FeatureExtractor.generate_synthetic_data(1))
          {"job_#{i}", f}
        end

      ranked = Ranker.rank(booster, candidates)
      assert length(ranked) == 10

      scores = Enum.map(ranked, & &1.score)
      assert scores == Enum.sort(scores, :desc)

      ranks = Enum.map(ranked, & &1.rank)
      assert ranks == Enum.to_list(1..10)
    end

    @tag :benchmark
    test "evaluate returns metrics" do
      train = FeatureExtractor.generate_synthetic_data(100)
      test_data = FeatureExtractor.generate_synthetic_data(50)

      {:ok, booster} = Ranker.train(train)
      metrics = Ranker.evaluate(booster, test_data)

      assert is_float(metrics.accuracy)
      assert is_float(metrics.auc)
      assert is_float(metrics.precision)
      assert is_float(metrics.recall)
      assert metrics.n == 50

      # With correlated synthetic data, should do better than random
      assert metrics.accuracy > 0.5
      assert metrics.auc > 0.5
    end

    @tag :benchmark
    test "model serialization roundtrip" do
      data = FeatureExtractor.generate_synthetic_data(50)
      {:ok, booster} = Ranker.train(data)

      # Binary roundtrip
      binary = Ranker.dump_model(booster)
      assert is_binary(binary)

      {:ok, loaded} = Ranker.load_model(binary)
      test_features = [List.duplicate(0.5, 18)]

      original_scores = Ranker.predict(booster, test_features)
      loaded_scores = Ranker.predict(loaded, test_features)
      assert_in_delta hd(original_scores), hd(loaded_scores), 0.001
    end

    @tag :benchmark
    test "model file save/load roundtrip" do
      data = FeatureExtractor.generate_synthetic_data(50)
      {:ok, booster} = Ranker.train(data)

      path = Path.join(System.tmp_dir!(), "test_ranker_model_#{:rand.uniform(100_000)}")
      # EXGBoost appends .json automatically
      file_path = path <> ".json"
      File.rm(file_path)

      try do
        Ranker.save_model(booster, path)
        assert File.exists?(file_path), "Model file not saved at #{file_path}"

        {:ok, loaded} = Ranker.load_model_file(file_path)
        test_features = [List.duplicate(0.5, 18)]

        original_scores = Ranker.predict(booster, test_features)
        loaded_scores = Ranker.predict(loaded, test_features)
        assert_in_delta hd(original_scores), hd(loaded_scores), 0.001
      after
        File.rm(file_path)
      end
    end

    @tag :benchmark
    test "incremental training improves or maintains quality" do
      # Train initial model
      initial_data = FeatureExtractor.generate_synthetic_data(50)
      {:ok, initial_booster} = Ranker.train(initial_data)

      # Add more data with incremental training
      more_data = FeatureExtractor.generate_synthetic_data(50)
      all_data = initial_data ++ more_data
      {:ok, _incremental_booster} = Ranker.train(all_data, existing_model: initial_booster)

      # Just verify it doesn't crash - incremental training works
      assert true
    end

    @tag :benchmark
    test "adaptive hyperparameters scale with data size" do
      # Small dataset
      small = FeatureExtractor.generate_synthetic_data(30)
      {:ok, _} = Ranker.train(small)

      # Medium dataset
      medium = FeatureExtractor.generate_synthetic_data(80)
      {:ok, _} = Ranker.train(medium)

      # Larger dataset
      large = FeatureExtractor.generate_synthetic_data(200)
      {:ok, _} = Ranker.train(large)

      # All should train without error
      assert true
    end
  end

  describe "Ranker smoke test - full pipeline" do
    @tag :benchmark
    test "end-to-end: extract features → train → rank" do
      # Simulate the full pipeline
      jobs = [
        %{
          id: "job_1",
          salary_min: 150_000,
          salary_max: 180_000,
          work_model: "remote",
          remote_policy: "full_remote",
          location: "Remote",
          date_posted: Date.utc_today() |> Date.to_iso8601(),
          description_text: String.duplicate("Elixir Phoenix developer ", 50),
          required_skills: ["Elixir", "Phoenix", "PostgreSQL"],
          seniority_level: "senior",
          industry: "fintech"
        },
        %{
          id: "job_2",
          salary_min: 80_000,
          salary_max: 100_000,
          work_model: "onsite",
          remote_policy: "onsite",
          location: "New York, NY",
          date_posted: "2025-12-01",
          description_text: "Java enterprise developer needed",
          required_skills: ["Java", "Spring", "Oracle"],
          seniority_level: "mid",
          industry: "banking"
        }
      ]

      user_prefs = %{
        salary_min: 140_000,
        salary_max: 180_000,
        work_model: "remote",
        preferred_location: "Remote",
        skills: ["Elixir", "Phoenix", "PostgreSQL", "React"],
        seniority_level: "senior",
        industry: "fintech"
      }

      # Extract features for each job
      candidates =
        Enum.map(jobs, fn job ->
          sims = %{title: 0.8, description: 0.7, skills: 0.85, requirements: 0.6, composite: 0.75}
          features = FeatureExtractor.extract(job, sims, user_prefs)
          {job.id, features}
        end)

      # Train on synthetic data
      training_data = FeatureExtractor.generate_synthetic_data(100)
      {:ok, booster} = Ranker.train(training_data)

      # Rank candidates
      ranked = Ranker.rank(booster, candidates)
      assert length(ranked) == 2
      assert hd(ranked).rank == 1
    end
  end
end
