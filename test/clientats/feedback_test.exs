defmodule Clientats.FeedbackTest do
  use Clientats.DataCase, async: false

  alias Clientats.Feedback
  alias Clientats.Feedback.{UserFeedback, UserPreference, RankingModel}

  setup do
    user = insert_user()
    job = insert_job_interest(user)
    job2 = insert_job_interest(user, %{position_title: "Backend Developer"})
    %{user: user, job: job, job2: job2}
  end

  describe "record_feedback/1" do
    test "records a thumbs up", %{user: user, job: job} do
      assert {:ok, fb} = Feedback.thumbs_up(user.id, job.id)
      assert fb.feedback_type == "thumbs_up"
      assert fb.value == 1.0
      assert fb.user_id == user.id
      assert fb.job_interest_id == job.id
    end

    test "records a thumbs down", %{user: user, job: job} do
      assert {:ok, fb} = Feedback.thumbs_down(user.id, job.id)
      assert fb.feedback_type == "thumbs_down"
      assert fb.value == 0.0
    end

    test "records a bookmark", %{user: user, job: job} do
      assert {:ok, fb} = Feedback.bookmark(user.id, job.id)
      assert fb.feedback_type == "bookmark"
    end

    test "records a click", %{user: user, job: job} do
      assert {:ok, _} = Feedback.record_click(user.id, job.id)
    end

    test "records dwell time", %{user: user, job: job} do
      assert {:ok, fb} = Feedback.record_dwell(user.id, job.id, 45)
      assert fb.feedback_type == "dwell"
      assert fb.value == 45.0
    end

    test "records why prompt", %{user: user, job: job} do
      assert {:ok, fb} = Feedback.record_why(user.id, job.id, "Good salary range")
      assert fb.feedback_type == "why_prompt"
      assert fb.metadata["reason"] == "Good salary range"
    end

    test "upserts on duplicate signal", %{user: user, job: job} do
      assert {:ok, _} = Feedback.thumbs_up(user.id, job.id)
      assert {:ok, _} = Feedback.thumbs_up(user.id, job.id)

      feedbacks = Feedback.get_feedback(user.id, job.id)
      thumbs = Enum.filter(feedbacks, &(&1.feedback_type == "thumbs_up"))
      assert length(thumbs) == 1
    end

    test "validates feedback type" do
      assert {:error, changeset} =
               Feedback.record_feedback(%{
                 user_id: 1,
                 feedback_type: "invalid_type",
                 value: 1.0
               })

      assert errors_on(changeset).feedback_type
    end
  end

  describe "get_thumbs/2" do
    test "returns nil when no feedback", %{user: user, job: job} do
      assert Feedback.get_thumbs(user.id, job.id) == nil
    end

    test "returns :up after thumbs up", %{user: user, job: job} do
      Feedback.thumbs_up(user.id, job.id)
      assert Feedback.get_thumbs(user.id, job.id) == :up
    end

    test "returns :down after thumbs down", %{user: user, job: job} do
      Feedback.thumbs_down(user.id, job.id)
      assert Feedback.get_thumbs(user.id, job.id) == :down
    end
  end

  describe "feedback_count/1" do
    test "counts explicit signals", %{user: user, job: job, job2: job2} do
      assert Feedback.feedback_count(user.id) == 0

      Feedback.thumbs_up(user.id, job.id)
      assert Feedback.feedback_count(user.id) == 1

      Feedback.thumbs_down(user.id, job2.id)
      assert Feedback.feedback_count(user.id) == 2
    end

    test "ignores implicit signals", %{user: user, job: job} do
      Feedback.record_click(user.id, job.id)
      Feedback.record_dwell(user.id, job.id, 30)
      assert Feedback.feedback_count(user.id) == 0
    end
  end

  describe "should_prompt_why?/2" do
    test "prompts at interval", %{user: user} do
      refute Feedback.should_prompt_why?(user.id, 3)

      # Create 3 explicit feedbacks
      for i <- 1..3 do
        j = insert_job_interest(user, %{position_title: "Job #{i}"})
        Feedback.thumbs_up(user.id, j.id)
      end

      assert Feedback.should_prompt_why?(user.id, 3)
    end
  end

  describe "UserFeedback.training_label/1" do
    test "thumbs up = positive" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "thumbs_up"}) == 1.0
    end

    test "bookmark = positive" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "bookmark"}) == 1.0
    end

    test "thumbs down = negative" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "thumbs_down"}) == 0.0
    end

    test "company block = negative" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "company_block"}) == 0.0
    end

    test "click = skip (no training signal)" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "click"}) == nil
    end

    test "long dwell = positive" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "dwell", value: 45.0}) == 1.0
    end

    test "short dwell = negative" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "dwell", value: 3.0}) == 0.0
    end

    test "medium dwell = skip" do
      assert UserFeedback.training_label(%UserFeedback{feedback_type: "dwell", value: 15.0}) == nil
    end
  end

  describe "preferences" do
    test "set and get preference", %{user: user} do
      assert {:ok, pref} =
               Feedback.set_preference(user.id, "skills", %{"list" => ["Elixir", "Phoenix"]})

      assert pref.preference_type == "skills"
      assert pref.value["list"] == ["Elixir", "Phoenix"]

      fetched = Feedback.get_preference(user.id, "skills")
      assert fetched.id == pref.id
    end

    test "upserts preference", %{user: user} do
      Feedback.set_preference(user.id, "skills", %{"list" => ["Elixir"]})
      Feedback.set_preference(user.id, "skills", %{"list" => ["Elixir", "Phoenix"]})

      prefs = Feedback.get_all_preferences(user.id)
      skills_prefs = Enum.filter(prefs, &(&1.preference_type == "skills"))
      assert length(skills_prefs) == 1
      assert hd(skills_prefs).value["list"] == ["Elixir", "Phoenix"]
    end

    test "to_feature_prefs converts preferences to flat map", %{user: user} do
      Feedback.set_preference(user.id, "skills", %{"list" => ["Elixir", "Phoenix"]})
      Feedback.set_preference(user.id, "salary", %{"min" => 120_000, "max" => 180_000})
      Feedback.set_preference(user.id, "location", %{"preferred" => "Remote"})
      Feedback.set_preference(user.id, "work_model", %{"preferred" => "remote"})
      Feedback.set_preference(user.id, "seniority", %{"level" => "senior"})

      prefs = Feedback.get_all_preferences(user.id)
      map = UserPreference.to_feature_prefs(prefs)

      assert map.skills == ["Elixir", "Phoenix"]
      assert map.salary_min == 120_000
      assert map.salary_max == 180_000
      assert map.preferred_location == "Remote"
      assert map.work_model == "remote"
      assert map.seniority_level == "senior"
    end
  end

  describe "company blocks" do
    test "block and check company", %{user: user} do
      refute Feedback.company_blocked?(user.id, "BadCorp")

      assert {:ok, _} = Feedback.block_company(user.id, "BadCorp", "Poor culture")
      assert Feedback.company_blocked?(user.id, "BadCorp")
    end

    test "list blocked companies", %{user: user} do
      Feedback.block_company(user.id, "BadCorp")
      Feedback.block_company(user.id, "WorseCorp")

      blocked = Feedback.blocked_companies(user.id)
      names = Enum.map(blocked, & &1.company_name)
      assert "BadCorp" in names
      assert "WorseCorp" in names
    end

    test "unblock company", %{user: user} do
      Feedback.block_company(user.id, "BadCorp")
      assert Feedback.company_blocked?(user.id, "BadCorp")

      Feedback.unblock_company(user.id, "BadCorp")
      refute Feedback.company_blocked?(user.id, "BadCorp")
    end

    test "blocking is idempotent", %{user: user} do
      assert {:ok, _} = Feedback.block_company(user.id, "BadCorp")
      assert {:ok, _} = Feedback.block_company(user.id, "BadCorp")

      blocked = Feedback.blocked_companies(user.id)
      assert length(Enum.filter(blocked, &(&1.company_name == "BadCorp"))) == 1
    end
  end

  describe "RankingModel.phase_for_count/1" do
    test "returns correct phase" do
      assert RankingModel.phase_for_count(0) == "llm_proxy"
      assert RankingModel.phase_for_count(29) == "llm_proxy"
      assert RankingModel.phase_for_count(30) == "simple_model"
      assert RankingModel.phase_for_count(99) == "simple_model"
      assert RankingModel.phase_for_count(100) == "full_model"
      assert RankingModel.phase_for_count(500) == "full_model"
    end
  end

  describe "training pipeline" do
    test "training_data returns empty for new user", %{user: user} do
      assert Feedback.training_data(user.id) == []
    end

    test "training_data includes explicit signals", %{user: user, job: job, job2: job2} do
      Feedback.thumbs_up(user.id, job.id)
      Feedback.thumbs_down(user.id, job2.id)

      data = Feedback.training_data(user.id)
      assert length(data) == 2

      [{features1, label1}, {features2, label2}] = Enum.sort_by(data, &elem(&1, 1), :desc)
      assert label1 == 1.0
      assert label2 == 0.0
      assert length(features1) == 18
      assert length(features2) == 18
    end

    test "training_data excludes clicks", %{user: user, job: job} do
      Feedback.record_click(user.id, job.id)
      assert Feedback.training_data(user.id) == []
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

  defp insert_job_interest(user, attrs \\ %{}) do
    default = %{
      user_id: user.id,
      company_name: "TestCorp",
      position_title: "Software Engineer",
      job_description: "A great job",
      status: "interested"
    }

    {:ok, job} =
      %Clientats.Jobs.JobInterest{}
      |> Clientats.Jobs.JobInterest.changeset(Map.merge(default, attrs))
      |> Clientats.Repo.insert()

    job
  end
end
