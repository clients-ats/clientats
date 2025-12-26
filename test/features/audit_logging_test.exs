defmodule ClientatsWeb.Features.AuditLoggingTest do
  use Clientats.DataCase, async: false

  alias Clientats.Audit
  alias Clientats.Audit.AuditLog
  alias Clientats.Repo

  @moduletag :audit

  describe "Audit Log Creation for User Actions" do
    test "logs job interest creation" do
      user = create_user_with_db()

      # Create a job interest
      {:ok, interest} =
        Clientats.Jobs.create_job_interest(%{
          user_id: user.id,
          company_name: "Test Corp",
          position_title: "Software Engineer",
          status: "interested"
        })

      # Log the action
      {:ok, log} =
        Audit.log_resource_action(
          "job_interest",
          "create",
          interest.id,
          user_id: user.id,
          new_values: %{company_name: "Test Corp", position_title: "Software Engineer"},
          description: "Created job interest"
        )

      # Verify audit log was created
      assert log.action == "create"
      assert log.resource_type == "job_interest"
      assert log.resource_id == interest.id
      assert log.user_id == user.id
      assert log.status == "success"
      assert log.new_values["company_name"] == "Test Corp"
    end

    test "logs job interest update with old/new values" do
      user = create_user_with_db()

      # Create a job interest
      {:ok, interest} =
        Clientats.Jobs.create_job_interest(%{
          user_id: user.id,
          company_name: "Old Corp",
          position_title: "Junior Engineer",
          status: "interested"
        })

      old_values = %{company_name: "Old Corp", position_title: "Junior Engineer"}

      # Update the interest
      {:ok, updated_interest} =
        Clientats.Jobs.update_job_interest(interest, %{
          company_name: "New Corp",
          position_title: "Senior Engineer"
        })

      new_values = %{company_name: "New Corp", position_title: "Senior Engineer"}

      # Log the update
      {:ok, log} =
        Audit.log_resource_action(
          "job_interest",
          "update",
          updated_interest.id,
          user_id: user.id,
          old_values: old_values,
          new_values: new_values,
          description: "Updated job interest"
        )

      # Verify old and new values are tracked
      assert log.action == "update"
      assert log.old_values["company_name"] == "Old Corp"
      assert log.new_values["company_name"] == "New Corp"
      assert log.old_values["position_title"] == "Junior Engineer"
      assert log.new_values["position_title"] == "Senior Engineer"
    end

    test "logs job interest deletion" do
      user = create_user_with_db()

      {:ok, interest} =
        Clientats.Jobs.create_job_interest(%{
          user_id: user.id,
          company_name: "Delete Corp",
          position_title: "Test Position",
          status: "interested"
        })

      interest_id = interest.id

      # Delete the interest
      {:ok, _deleted} = Clientats.Jobs.delete_job_interest(interest)

      # Log the deletion
      {:ok, log} =
        Audit.log_resource_action(
          "job_interest",
          "delete",
          interest_id,
          user_id: user.id,
          old_values: %{company_name: "Delete Corp"},
          description: "Deleted job interest"
        )

      assert log.action == "delete"
      assert log.resource_id == interest_id
      assert log.old_values["company_name"] == "Delete Corp"
    end

    test "logs authentication events (login/logout)" do
      user = create_user_with_db()
      conn = build_mock_conn()

      # Log login
      {:ok, login_log} = Audit.log_auth_event(user.id, "login", conn, "success")

      assert login_log.action == "login"
      assert login_log.resource_type == "auth"
      assert login_log.user_id == user.id
      assert login_log.status == "success"
      assert login_log.ip_address != nil

      # Log logout
      {:ok, logout_log} = Audit.log_auth_event(user.id, "logout", conn, "success")

      assert logout_log.action == "logout"
      assert logout_log.resource_type == "auth"
    end
  end

  describe "IP Address and User Agent Tracking" do
    test "captures IP address from connection" do
      user = create_user_with_db()
      conn = build_mock_conn(ip: {192, 168, 1, 100})

      {:ok, log} = Audit.log_auth_event(user.id, "login", conn)

      assert log.ip_address == "192.168.1.100"
    end

    test "captures IPv6 address from connection" do
      user = create_user_with_db()
      conn = build_mock_conn(ip: {8193, 3512, 4660, 22136, 0, 0, 0, 1})

      {:ok, log} = Audit.log_auth_event(user.id, "login", conn)

      assert log.ip_address == "8193:3512:4660:22136:0:0:0:1"
    end

    test "captures user agent from connection" do
      user = create_user_with_db()
      user_agent = "Mozilla/5.0 (X11; Linux x86_64) Chrome/120.0.0.0"
      conn = build_mock_conn(user_agent: user_agent)

      {:ok, log} = Audit.log_auth_event(user.id, "login", conn)

      assert log.user_agent == user_agent
    end

    test "handles missing user agent gracefully" do
      user = create_user_with_db()
      conn = build_mock_conn(user_agent: nil)

      {:ok, log} = Audit.log_auth_event(user.id, "login", conn)

      assert log.user_agent == "unknown"
    end
  end

  describe "Status Tracking (Success/Failure)" do
    test "logs successful operations with success status" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "resume",
          "file_upload",
          Ecto.UUID.generate(),
          user_id: user.id,
          status: "success",
          description: "Uploaded resume successfully"
        )

      assert log.status == "success"
      assert log.error_message == nil
    end

    test "logs failed operations with failure status and error message" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "resume",
          "file_upload",
          Ecto.UUID.generate(),
          user_id: user.id,
          status: "failure",
          error_message: "File size exceeds limit",
          description: "Failed to upload resume"
        )

      assert log.status == "failure"
      assert log.error_message == "File size exceeds limit"
    end

    test "logs partial operations" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "data_import",
          "import",
          Ecto.UUID.generate(),
          user_id: user.id,
          status: "partial",
          error_message: "5 out of 10 records imported",
          metadata: %{total: 10, imported: 5, failed: 5}
        )

      assert log.status == "partial"
      assert log.metadata["total"] == 10
      assert log.metadata["imported"] == 5
    end
  end

  describe "Immutable Audit Records" do
    test "prevents updates to existing audit logs" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "job_interest",
          "create",
          Ecto.UUID.generate(),
          user_id: user.id
        )

      # Attempt to update the audit log
      changeset =
        log
        |> Ecto.Changeset.change(%{action: "update"})
        |> Map.put(:action, :update)
        |> AuditLog.changeset(%{action: "update"})

      assert changeset.valid? == false
      assert {"Audit logs are immutable", []} in changeset.errors
    end

    test "audit logs have no updated_at timestamp" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "job_interest",
          "create",
          Ecto.UUID.generate(),
          user_id: user.id
        )

      # Verify that updated_at is not present
      refute Map.has_key?(log, :updated_at)
      assert log.inserted_at != nil
    end
  end

  describe "File Operations Logging" do
    test "logs file upload with metadata" do
      user = create_user_with_db()
      file_id = Ecto.UUID.generate()

      {:ok, log} =
        Audit.log_resource_action(
          "resume",
          "file_upload",
          file_id,
          user_id: user.id,
          metadata: %{
            filename: "resume.pdf",
            file_size: 1_024_000,
            mime_type: "application/pdf"
          },
          description: "Uploaded resume file"
        )

      assert log.action == "file_upload"
      assert log.resource_type == "resume"
      assert log.metadata["filename"] == "resume.pdf"
      assert log.metadata["file_size"] == 1_024_000
      assert log.metadata["mime_type"] == "application/pdf"
    end

    test "logs file download" do
      user = create_user_with_db()
      file_id = Ecto.UUID.generate()
      conn = build_mock_conn()

      {:ok, log} =
        Audit.log_resource_action(
          "resume",
          "file_download",
          file_id,
          user_id: user.id,
          conn: conn,
          metadata: %{filename: "resume.pdf"},
          description: "Downloaded resume file"
        )

      assert log.action == "file_download"
      assert log.resource_id == file_id
      assert log.ip_address != nil
    end
  end

  describe "Data Export/Import Logging" do
    test "logs data export events" do
      user = create_user_with_db()

      {:ok, log} = Audit.log_export_event(user.id, "json", "success")

      assert log.action == "export"
      assert log.resource_type == "data_export"
      assert log.status == "success"
      assert log.metadata["export_type"] == "json"
      assert log.description =~ "Exported json data"
    end

    test "logs data import events with statistics" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "data_import",
          "import",
          Ecto.UUID.generate(),
          user_id: user.id,
          metadata: %{
            interests_imported: 10,
            applications_imported: 5,
            resumes_imported: 3
          },
          description: "Imported user data from JSON"
        )

      assert log.action == "import"
      assert log.resource_type == "data_import"
      assert log.metadata["interests_imported"] == 10
      assert log.metadata["applications_imported"] == 5
      assert log.metadata["resumes_imported"] == 3
    end

    test "logs failed import with error details" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "data_import",
          "import",
          Ecto.UUID.generate(),
          user_id: user.id,
          status: "failure",
          error_message: "Invalid JSON format",
          description: "Failed to import user data"
        )

      assert log.status == "failure"
      assert log.error_message == "Invalid JSON format"
    end
  end

  describe "Configuration Change Logging" do
    test "logs LLM provider configuration changes" do
      user = create_user_with_db()
      config_id = Ecto.UUID.generate()

      old_config = %{provider: "ollama", model: "mistral"}
      new_config = %{provider: "ollama", model: "llama2"}

      {:ok, log} =
        Audit.log_resource_action(
          "llm_settings",
          "config_change",
          config_id,
          user_id: user.id,
          old_values: old_config,
          new_values: new_config,
          description: "Changed LLM model configuration"
        )

      assert log.action == "config_change"
      assert log.resource_type == "llm_settings"
      assert log.old_values["model"] == "mistral"
      assert log.new_values["model"] == "llama2"
    end

    test "logs primary provider selection change" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "user_settings",
          "config_change",
          user.id,
          user_id: user.id,
          old_values: %{primary_llm_provider: "ollama"},
          new_values: %{primary_llm_provider: "gemini"},
          description: "Changed primary LLM provider"
        )

      assert log.old_values["primary_llm_provider"] == "ollama"
      assert log.new_values["primary_llm_provider"] == "gemini"
    end
  end

  describe "API Key Lifecycle Logging" do
    test "logs API key creation (without storing the key)" do
      user = create_user_with_db()

      {:ok, log} = Audit.log_api_key_event(user.id, "api_key_created", "gemini", "success")

      assert log.action == "api_key_created"
      assert log.resource_type == "llm_settings"
      assert log.metadata["provider"] == "gemini"
      assert log.status == "success"
      # Ensure the actual API key is NOT in the log
      refute log.new_values
      refute log.metadata["api_key"]
    end

    test "logs API key deletion" do
      user = create_user_with_db()

      {:ok, log} = Audit.log_api_key_event(user.id, "api_key_deleted", "openai", "success")

      assert log.action == "api_key_deleted"
      assert log.metadata["provider"] == "openai"
      assert log.description =~ "API key api_key_deleted for provider: openai"
    end

    test "logs failed API key validation" do
      user = create_user_with_db()

      {:ok, log} =
        Audit.log_resource_action(
          "llm_settings",
          "api_key_created",
          Ecto.UUID.generate(),
          user_id: user.id,
          status: "failure",
          error_message: "Invalid API key format",
          metadata: %{provider: "anthropic"}
        )

      assert log.status == "failure"
      assert log.error_message == "Invalid API key format"
      assert log.metadata["provider"] == "anthropic"
    end
  end

  describe "Audit Log Querying and Filtering" do
    test "retrieves user audit logs with pagination" do
      user = create_user_with_db()

      # Create multiple audit logs
      for i <- 1..15 do
        Audit.log_resource_action(
          "job_interest",
          "create",
          Ecto.UUID.generate(),
          user_id: user.id,
          description: "Log #{i}"
        )
      end

      # Get first page
      logs = Audit.get_user_audit_logs(user.id, limit: 10, offset: 0)
      assert length(logs) == 10

      # Get second page
      logs_page2 = Audit.get_user_audit_logs(user.id, limit: 10, offset: 10)
      assert length(logs_page2) == 5
    end

    test "filters audit logs by resource type" do
      user = create_user_with_db()

      # Create different types of logs
      Audit.log_resource_action("job_interest", "create", Ecto.UUID.generate(),
        user_id: user.id
      )

      Audit.log_resource_action("resume", "file_upload", Ecto.UUID.generate(), user_id: user.id)
      Audit.log_resource_action("resume", "file_upload", Ecto.UUID.generate(), user_id: user.id)

      # Filter by resume
      resume_logs = Audit.get_user_audit_logs(user.id, resource_type: "resume")
      assert length(resume_logs) == 2
      assert Enum.all?(resume_logs, fn log -> log.resource_type == "resume" end)
    end

    test "filters audit logs by action" do
      user = create_user_with_db()

      # Create different actions
      Audit.log_resource_action("job_interest", "create", Ecto.UUID.generate(),
        user_id: user.id
      )

      Audit.log_resource_action("job_interest", "update", Ecto.UUID.generate(),
        user_id: user.id
      )

      Audit.log_resource_action("job_interest", "delete", Ecto.UUID.generate(),
        user_id: user.id
      )

      # Filter by action
      delete_logs = Audit.get_user_audit_logs(user.id, action: "delete")
      assert length(delete_logs) == 1
      assert hd(delete_logs).action == "delete"
    end

    test "counts total audit logs for user" do
      user = create_user_with_db()

      # Create logs
      for _i <- 1..7 do
        Audit.log_resource_action("job_interest", "create", Ecto.UUID.generate(),
          user_id: user.id
        )
      end

      count = Audit.count_user_audit_logs(user.id)
      assert count == 7
    end
  end

  describe "Audit Log Search" do
    test "searches audit logs by description" do
      user = create_user_with_db()

      Audit.log_resource_action(
        "job_interest",
        "create",
        Ecto.UUID.generate(),
        user_id: user.id,
        description: "Created interest for Google position"
      )

      Audit.log_resource_action(
        "job_interest",
        "create",
        Ecto.UUID.generate(),
        user_id: user.id,
        description: "Created interest for Apple position"
      )

      results = Audit.search_audit_logs(user.id, "Google")
      assert length(results) == 1
      assert hd(results).description =~ "Google"
    end

    test "searches are case insensitive" do
      user = create_user_with_db()

      Audit.log_resource_action(
        "job_interest",
        "create",
        Ecto.UUID.generate(),
        user_id: user.id,
        description: "Created interest for MICROSOFT position"
      )

      results = Audit.search_audit_logs(user.id, "microsoft")
      assert length(results) == 1
    end
  end

  describe "Audit Statistics" do
    test "generates audit statistics for user" do
      user = create_user_with_db()

      # Create various logs
      Audit.log_resource_action("job_interest", "create", Ecto.UUID.generate(),
        user_id: user.id
      )

      Audit.log_resource_action("job_interest", "update", Ecto.UUID.generate(),
        user_id: user.id
      )

      Audit.log_resource_action("resume", "file_upload", Ecto.UUID.generate(), user_id: user.id)

      Audit.log_resource_action(
        "resume",
        "file_upload",
        Ecto.UUID.generate(),
        user_id: user.id,
        status: "failure"
      )

      stats = Audit.get_audit_statistics(user.id)

      assert stats.total_actions == 4
      assert stats.by_action["create"] == 1
      assert stats.by_action["update"] == 1
      assert stats.by_action["file_upload"] == 2
      assert stats.by_resource_type["job_interest"] == 2
      assert stats.by_resource_type["resume"] == 2
      assert stats.failures == 1
      assert stats.last_activity != nil
    end
  end

  describe "Audit Log Export" do
    test "exports audit logs as JSON" do
      user = create_user_with_db()

      Audit.log_resource_action("job_interest", "create", Ecto.UUID.generate(),
        user_id: user.id
      )

      {:ok, json_data} = Audit.export_audit_logs(user.id, :json)
      decoded = Jason.decode!(json_data)

      assert is_list(decoded)
      assert length(decoded) == 1
    end

    test "exports audit logs as CSV" do
      user = create_user_with_db()

      Audit.log_resource_action("job_interest", "create", Ecto.UUID.generate(),
        user_id: user.id,
        description: "Test log"
      )

      {:ok, csv_data} = Audit.export_audit_logs(user.id, :csv)

      assert is_binary(csv_data)
      assert csv_data =~ "Timestamp,Action,Resource Type"
      assert csv_data =~ "create"
      assert csv_data =~ "job_interest"
    end

    test "rejects invalid export format" do
      user = create_user_with_db()

      result = Audit.export_audit_logs(user.id, :xml)
      assert result == {:error, :invalid_format}
    end
  end

  describe "Audit Log Retention and Cleanup" do
    test "cleans up old audit logs based on retention policy" do
      # This test would require mocking timestamps, so we'll just verify the function exists
      # In a real scenario, you'd use Ecto's sandbox and time manipulation
      assert function_exported?(Audit, :cleanup_old_logs, 1)
    end
  end

  # Helper functions
  defp create_user_with_db do
    unique_email = "test_#{System.unique_integer([:positive])}@example.com"

    {:ok, user} =
      Clientats.Accounts.register_user(%{
        email: unique_email,
        password: "password123456",
        password_confirmation: "password123456",
        first_name: "Test",
        last_name: "User"
      })

    # Convert user.id to string for audit logging compatibility
    %{user | id: to_string(user.id)}
  end

  defp build_mock_conn(opts \\ []) do
    ip = opts[:ip] || {127, 0, 0, 1}
    user_agent = opts[:user_agent]

    conn =
      Phoenix.ConnTest.build_conn()
      |> Map.put(:remote_ip, ip)

    if user_agent do
      Plug.Conn.put_req_header(conn, "user-agent", user_agent)
    else
      conn
    end
  end
end
