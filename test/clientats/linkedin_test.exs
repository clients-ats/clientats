defmodule Clientats.LinkedInTest do
  use ExUnit.Case, async: true

  alias Clientats.LinkedIn

  describe "build_search_url/2" do
    test "basic query with defaults" do
      url = LinkedIn.build_search_url("Elixir developer")
      assert url =~ "linkedin.com/jobs/search/"
      assert url =~ "keywords=Elixir"
      assert url =~ "location=United+States"
    end

    test "with remote filter" do
      url = LinkedIn.build_search_url("Elixir developer", remote: true)
      assert url =~ "f_WT=2"
    end

    test "with time posted filter" do
      url = LinkedIn.build_search_url("Elixir", time_posted: :week)
      assert url =~ "f_TPR=r604800"
    end

    test "with experience levels" do
      url = LinkedIn.build_search_url("Elixir", experience: [:mid_senior, :director])
      assert url =~ "f_E=4%2C5"
    end

    test "with job types" do
      url = LinkedIn.build_search_url("Elixir", job_type: [:full_time, :contract])
      assert url =~ "f_JT=F%2CC"
    end

    test "with sort by date" do
      url = LinkedIn.build_search_url("Elixir", sort_by: :date)
      assert url =~ "sortBy=DD"
    end

    test "with custom location" do
      url = LinkedIn.build_search_url("Elixir", location: "San Francisco, CA")
      assert url =~ "location=San+Francisco"
    end

    test "combines multiple filters" do
      url = LinkedIn.build_search_url("Elixir developer",
        location: "United States",
        remote: true,
        time_posted: :month,
        experience: [:mid_senior],
        job_type: [:full_time],
        sort_by: :date
      )

      assert url =~ "keywords=Elixir"
      assert url =~ "f_WT=2"
      assert url =~ "f_TPR=r2592000"
      assert url =~ "f_E=4"
      assert url =~ "f_JT=F"
      assert url =~ "sortBy=DD"
    end
  end

  describe "dedup_fingerprint/3" do
    test "generates consistent fingerprint" do
      fp1 = LinkedIn.dedup_fingerprint("TestCorp", "Senior Elixir Dev", "Remote")
      fp2 = LinkedIn.dedup_fingerprint("TestCorp", "Senior Elixir Dev", "Remote")
      assert fp1 == fp2
    end

    test "normalizes case and whitespace" do
      fp1 = LinkedIn.dedup_fingerprint("TestCorp", "Senior Elixir Dev", "Remote")
      fp2 = LinkedIn.dedup_fingerprint("TESTCORP", "senior elixir dev", "REMOTE")
      assert fp1 == fp2
    end

    test "strips special characters" do
      fp1 = LinkedIn.dedup_fingerprint("Test Corp, Inc.", "Senior Dev", "Remote")
      fp2 = LinkedIn.dedup_fingerprint("Test Corp Inc", "Senior Dev", "Remote")
      assert fp1 == fp2
    end

    test "different jobs produce different fingerprints" do
      fp1 = LinkedIn.dedup_fingerprint("TestCorp", "Senior Elixir Dev", "Remote")
      fp2 = LinkedIn.dedup_fingerprint("OtherCorp", "Junior Python Dev", "NYC")
      refute fp1 == fp2
    end

    test "handles nil values" do
      fp = LinkedIn.dedup_fingerprint(nil, "Dev", nil)
      assert is_binary(fp)
      assert String.length(fp) == 16
    end

    test "fingerprint is 16-char hex string" do
      fp = LinkedIn.dedup_fingerprint("Corp", "Dev", "NYC")
      assert String.match?(fp, ~r/^[0-9a-f]{16}$/)
    end
  end

  describe "search_jobs/2" do
    @tag :cdp
    test "returns error when CDP not available" do
      # This test verifies error handling when Chrome isn't running with debug port
      result = LinkedIn.search_jobs("test")
      assert {:error, _} = result
    end
  end

  describe "job_detail/1" do
    @tag :cdp
    test "returns error when CDP not available" do
      result = LinkedIn.job_detail("12345")
      assert {:error, _} = result
    end
  end

  describe "public_job_data/1" do
    @tag :cdp
    test "returns error when CDP not available" do
      result = LinkedIn.public_job_data("12345")
      assert {:error, _} = result
    end
  end
end
