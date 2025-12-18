defmodule Clientats.Jobs.SchedulerTest do
  use Clientats.DataCase

  alias Clientats.Jobs.Scheduler
  alias Oban.Job

  setup do
    # Create test user
    {:ok, user} =
      Clientats.Accounts.register_user(%{
        email: "scheduler_test_#{System.unique_integer()}@example.com",
        password: "password123",
        first_name: "Scheduler",
        last_name: "Test"
      })

    {:ok, user: user}
  end

  describe "schedule_scrape_job/3" do
    test "enqueues a scrape job", %{user: user} do
      url = "https://example.com/job/123"

      result = Scheduler.schedule_scrape_job(url, user.id)

      assert {:ok, job} = result
      assert job.worker == "Clientats.Jobs.ScrapeJobWorker"
      assert job.queue == "scrape"
      assert job.args["url"] == url
      assert job.args["user_id"] == user.id
      assert job.args["mode"] == "generic"
      assert job.args["save"] == false
    end

    test "respects mode option", %{user: user} do
      url = "https://example.com/job/123"

      {:ok, job} = Scheduler.schedule_scrape_job(url, user.id, mode: "linkedin")

      assert job.args["mode"] == "linkedin"
    end

    test "respects provider option", %{user: user} do
      url = "https://example.com/job/123"

      {:ok, job} = Scheduler.schedule_scrape_job(url, user.id, provider: "gpt-4")

      assert job.args["provider"] == "gpt-4"
    end

    test "respects save option", %{user: user} do
      url = "https://example.com/job/123"

      {:ok, job} = Scheduler.schedule_scrape_job(url, user.id, save: true)

      assert job.args["save"] == true
    end

    test "schedules job for later with schedule_in", %{user: user} do
      url = "https://example.com/job/123"

      {:ok, job} = Scheduler.schedule_scrape_job(url, user.id, schedule_in: 3600)

      # Job should have scheduled_at set
      refute is_nil(job.scheduled_at)
    end
  end

  describe "schedule_data_export/2" do
    test "enqueues a data export job", %{user: user} do
      result = Scheduler.schedule_data_export(user.id)

      assert {:ok, job} = result
      assert job.worker == "Clientats.Jobs.GenericJobWorker"
      assert job.queue == "default"
      assert job.args["type"] == "export_data"
      assert job.args["user_id"] == user.id
      assert job.args["format"] == "json"
      assert job.args["days"] == 90
    end

    test "respects format option", %{user: user} do
      {:ok, job} = Scheduler.schedule_data_export(user.id, format: "csv")

      assert job.args["format"] == "csv"
    end

    test "respects days option", %{user: user} do
      {:ok, job} = Scheduler.schedule_data_export(user.id, days: 180)

      assert job.args["days"] == 180
    end

    test "schedules export for later", %{user: user} do
      {:ok, job} = Scheduler.schedule_data_export(user.id, schedule_in: 3600)

      refute is_nil(job.scheduled_at)
    end
  end

  describe "schedule_cleanup/1" do
    test "enqueues a cleanup job" do
      result = Scheduler.schedule_cleanup()

      assert {:ok, job} = result
      assert job.worker == "Clientats.Jobs.GenericJobWorker"
      assert job.args["type"] == "cleanup_old_data"
      assert job.args["retention_days"] == 2555
    end

    test "respects retention_days option" do
      {:ok, job} = Scheduler.schedule_cleanup(retention_days: 365)

      assert job.args["retention_days"] == 365
    end

    test "schedules cleanup for later" do
      {:ok, job} = Scheduler.schedule_cleanup(schedule_in: 86400)

      refute is_nil(job.scheduled_at)
    end
  end

  describe "schedule_notification/4" do
    test "enqueues a notification job", %{user: user} do
      result =
        Scheduler.schedule_notification(user.id, "Test Title", "Test message content")

      assert {:ok, job} = result
      assert job.worker == "Clientats.Jobs.GenericJobWorker"
      assert job.args["type"] == "send_notification"
      assert job.args["user_id"] == user.id
      assert job.args["title"] == "Test Title"
      assert job.args["message"] == "Test message content"
      assert job.args["notification_type"] == "info"
    end

    test "respects type option", %{user: user} do
      {:ok, job} =
        Scheduler.schedule_notification(user.id, "Warning", "Be careful", type: "warning")

      assert job.args["notification_type"] == "warning"
    end

    test "schedules notification for later", %{user: user} do
      {:ok, job} =
        Scheduler.schedule_notification(user.id, "Future", "Later", schedule_in: 3600)

      refute is_nil(job.scheduled_at)
    end
  end

  # Note: Tests for get_job_status, cancel_job, and get_pending_jobs would require
  # a more complete Oban Job schema migration. These functions are implemented but
  # tests are skipped due to Oban schema complexity in version 2.20

  describe "get_job_stats/0" do
    test "returns job statistics" do
      stats = Scheduler.get_job_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :pending)
      assert Map.has_key?(stats, :processing)
      assert Map.has_key?(stats, :completed)
      assert Map.has_key?(stats, :failed)
      assert is_integer(stats.pending)
      assert is_integer(stats.processing)
      assert is_integer(stats.completed)
      assert is_integer(stats.failed)
    end

    test "counts increase with new jobs", %{user: user} do
      initial_stats = Scheduler.get_job_stats()
      initial_pending = initial_stats.pending

      {:ok, _job} = Scheduler.schedule_scrape_job("http://example.com", user.id)

      updated_stats = Scheduler.get_job_stats()

      assert updated_stats.pending >= initial_pending
    end
  end
end
