defmodule Clientats.Jobs.SearchTest do
  use Clientats.DataCase

  alias Clientats.Jobs.Search
  alias Clientats.Jobs

  setup do
    # Create test user
    {:ok, user} =
      Clientats.Accounts.register_user(%{
        email: "search_test_#{System.unique_integer()}@example.com",
        password: "password123",
        first_name: "Search",
        last_name: "Tester"
      })

    # Create test job interests
    {:ok, interest1} =
      Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: "Tech Corp",
        position_title: "Senior React Engineer",
        location: "San Francisco, CA",
        work_model: "remote",
        status: "interested",
        priority: "high",
        salary_min: 150_000,
        salary_max: 200_000,
        job_description: "We are looking for an experienced React developer"
      })

    {:ok, interest2} =
      Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: "StartupXYZ",
        position_title: "Backend Engineer",
        location: "New York, NY",
        work_model: "hybrid",
        status: "ready_to_apply",
        priority: "medium",
        salary_min: 120_000,
        salary_max: 160_000,
        job_description: "Python and Django experience required"
      })

    {:ok, interest3} =
      Jobs.create_job_interest(%{
        user_id: user.id,
        company_name: "OtherCorp",
        position_title: "DevOps Engineer",
        location: "Remote",
        work_model: "remote",
        status: "not_a_fit",
        priority: "low",
        salary_min: 100_000,
        salary_max: 130_000
      })

    # Create job applications
    {:ok, app1} =
      Jobs.create_job_application(%{
        user_id: user.id,
        job_interest_id: interest1.id,
        company_name: "Tech Corp",
        position_title: "Senior React Engineer",
        application_date: Date.utc_today(),
        status: "interviewed"
      })

    {:ok, app2} =
      Jobs.create_job_application(%{
        user_id: user.id,
        job_interest_id: interest2.id,
        company_name: "StartupXYZ",
        position_title: "Backend Engineer",
        application_date: Date.add(Date.utc_today(), -5),
        status: "applied"
      })

    {:ok,
     user: user,
     interests: [interest1, interest2, interest3],
     applications: [app1, app2]}
  end

  describe "search_job_interests/2" do
    test "returns all job interests for a user", %{user: user, interests: interests} do
      results = Search.search_job_interests(user.id)

      assert length(results) == 3
      assert Enum.any?(results, fn i -> i.id == List.first(interests).id end)
    end

    test "filters by status", %{user: user} do
      results = Search.search_job_interests(user.id, status: "interested")

      assert length(results) == 1
      assert List.first(results).status == "interested"
    end

    test "filters by priority", %{user: user} do
      results = Search.search_job_interests(user.id, priority: "high")

      assert length(results) == 1
      assert List.first(results).priority == "high"
    end

    test "filters by minimum salary", %{user: user} do
      results = Search.search_job_interests(user.id, min_salary: 140_000)

      assert Enum.all?(results, fn i -> i.salary_min >= 140_000 end)
    end

    test "filters by maximum salary", %{user: user} do
      results = Search.search_job_interests(user.id, max_salary: 130_000)

      assert Enum.all?(results, fn i -> i.salary_max <= 130_000 end)
    end

    test "filters by work model", %{user: user} do
      results = Search.search_job_interests(user.id, work_model: "remote")

      assert length(results) == 2
      assert Enum.all?(results, fn i -> i.work_model == "remote" end)
    end

    test "searches by location", %{user: user} do
      results = Search.search_job_interests(user.id, location: "San Francisco")

      assert length(results) >= 1
      assert Enum.any?(results, fn i -> String.contains?(i.location, "San Francisco") end)
    end

    test "full-text search across fields", %{user: user} do
      results = Search.search_job_interests(user.id, search: "React")

      assert length(results) >= 1
      assert Enum.any?(results, fn i ->
        String.contains?(i.position_title, "React") or
          String.contains?(i.job_description || "", "React")
      end)
    end

    test "sorts by company name ascending", %{user: user} do
      results = Search.search_job_interests(user.id, sort_by: :company, sort_order: :asc)

      companies = Enum.map(results, & &1.company_name)
      assert companies == Enum.sort(companies)
    end

    test "sorts by company name descending", %{user: user} do
      results = Search.search_job_interests(user.id, sort_by: :company, sort_order: :desc)

      companies = Enum.map(results, & &1.company_name)
      assert companies == Enum.sort(companies, :desc)
    end

    test "paginates results", %{user: user} do
      page1 = Search.search_job_interests(user.id, limit: 2, offset: 0)
      page2 = Search.search_job_interests(user.id, limit: 2, offset: 2)

      assert length(page1) == 2
      assert length(page2) == 1
    end

    test "respects default pagination", %{user: user} do
      results = Search.search_job_interests(user.id)

      assert length(results) <= 50
    end

    test "combines multiple filters", %{user: user} do
      results =
        Search.search_job_interests(user.id,
          work_model: "remote",
          priority: "high",
          min_salary: 100_000
        )

      assert length(results) >= 1
      assert Enum.all?(results, fn i ->
        i.work_model == "remote" and i.priority == "high" and i.salary_min >= 100_000
      end)
    end

    test "returns empty list for non-matching search", %{user: user} do
      results = Search.search_job_interests(user.id, search: "NonexistentCompany")

      assert results == []
    end
  end

  describe "count_job_interests/2" do
    test "counts all job interests", %{user: user} do
      count = Search.count_job_interests(user.id)

      assert count == 3
    end

    test "counts filtered interests", %{user: user} do
      count = Search.count_job_interests(user.id, priority: "high")

      assert count == 1
    end

    test "counts with search", %{user: user} do
      count = Search.count_job_interests(user.id, search: "Engineer")

      assert count >= 2
    end
  end

  describe "search_job_applications/2" do
    test "returns all applications for a user", %{user: user, applications: apps} do
      results = Search.search_job_applications(user.id)

      assert length(results) >= 2
      assert Enum.any?(results, fn a -> a.id == List.first(apps).id end)
    end

    test "filters applications by status", %{user: user} do
      results = Search.search_job_applications(user.id, status: "interviewed")

      assert length(results) >= 1
      assert Enum.any?(results, fn a -> a.status == "interviewed" end)
    end

    test "searches applications by company", %{user: user} do
      results = Search.search_job_applications(user.id, search: "Tech")

      assert length(results) >= 1
    end

    test "filters by date range", %{user: user} do
      from_date = Date.add(Date.utc_today(), -10)
      to_date = Date.utc_today()

      results = Search.search_job_applications(user.id, from_date: from_date, to_date: to_date)

      assert length(results) >= 1
      assert Enum.all?(results, fn a ->
        Date.compare(a.application_date, from_date) in [:eq, :gt] and
          Date.compare(a.application_date, to_date) in [:eq, :lt]
      end)
    end

    test "sorts applications by date descending", %{user: user} do
      results = Search.search_job_applications(user.id, sort_by: :applied_date, sort_order: :desc)

      dates = Enum.map(results, & &1.application_date)
      assert dates == Enum.sort(dates, {:desc, Date})
    end

    test "paginates applications", %{user: user} do
      page1 = Search.search_job_applications(user.id, limit: 1, offset: 0)
      page2 = Search.search_job_applications(user.id, limit: 1, offset: 1)

      assert length(page1) == 1
      assert length(page2) >= 0
    end
  end

  describe "count_job_applications/2" do
    test "counts all applications", %{user: user} do
      count = Search.count_job_applications(user.id)

      assert count >= 2
    end

    test "counts with filters", %{user: user} do
      count = Search.count_job_applications(user.id, status: "interviewed")

      assert count >= 1
    end
  end

  describe "get_interest_stats/1" do
    test "returns interest statistics", %{user: user} do
      stats = Search.get_interest_stats(user.id)

      assert stats.total == 3
    end

    test "includes salary averages", %{user: user} do
      stats = Search.get_interest_stats(user.id)

      # Should have some salary data
      assert stats[:avg_salary_min] || stats[:avg_salary_max]
    end
  end

  describe "get_application_stats/1" do
    test "returns application statistics", %{user: user} do
      stats = Search.get_application_stats(user.id)

      assert stats.total >= 2
    end

    test "includes date information", %{user: user} do
      stats = Search.get_application_stats(user.id)

      # Should have date info
      assert stats[:oldest_application] || stats[:newest_application]
    end
  end
end
