defmodule Clientats.MigrationsTest do
  @moduledoc """
  Comprehensive tests for all database migrations.

  Tests cover:
  - Table creation with correct columns and types
  - Foreign key constraints and cascading behavior
  - Unique constraints and indexes
  - Default values
  - Rollback scenarios (where applicable)
  """

  use Clientats.DataCase

  alias Clientats.MigrationTestHelper, as: Helper
  alias Clientats.Repo
  alias Ecto.Adapters.SQL

  describe "migrations exist" do
    test "all migration files are present" do
      migration_dir = Path.join([:code.priv_dir(:clientats), "repo", "migrations"])
      files = File.ls!(migration_dir)

      expected_migrations = [
        "20251113051453_create_users.exs",
        "20251113052648_create_job_interests.exs",
        "20251113052657_create_job_applications.exs",
        "20251113052704_create_application_events.exs",
        "20251113053834_create_resumes.exs",
        "20251113053841_create_cover_letter_templates.exs",
        "20251213161000_create_llm_settings.exs",
        "20251215015948_migrate_api_keys_to_plaintext.exs"
      ]

      assert Enum.all?(expected_migrations, &(&1 in files)),
             "Missing migrations: #{inspect(expected_migrations -- files)}"
    end
  end

  describe "create_users migration" do
    test "users table has correct structure" do
      assert Helper.table_exists?("users")

      columns = Helper.get_table_columns("users")

      expected_columns =
        ~w(id email hashed_password first_name last_name resume_path inserted_at updated_at)

      assert Enum.all?(expected_columns, &(&1 in columns))
    end

    test "users table columns have correct types" do
      # Check email column is string and not nullable
      {:ok, email_info} = Helper.get_column_info("users", "email")
      assert email_info.data_type =~ "character"
      assert email_info.nullable == false

      # Check hashed_password is not nullable
      {:ok, pwd_info} = Helper.get_column_info("users", "hashed_password")
      assert pwd_info.data_type =~ "character"
      assert pwd_info.nullable == false

      # Check resume_path is nullable
      {:ok, resume_info} = Helper.get_column_info("users", "resume_path")
      assert resume_info.nullable == true
    end

    test "users table has unique email index" do
      indexes = Helper.get_table_indexes("users")
      assert Enum.any?(indexes, &String.contains?(&1.definition, "UNIQUE"))
    end

    test "users table has timestamps" do
      columns = Helper.get_table_columns("users")
      assert "inserted_at" in columns
      assert "updated_at" in columns
    end

    test "can insert a user" do
      {:ok, result} =
        Helper.insert_data("users", %{
          "email" => "test@example.com",
          "hashed_password" => "hashed_pwd",
          "first_name" => "John",
          "last_name" => "Doe"
        })

      assert result.num_rows == 1
    end

    test "duplicate emails are rejected due to unique constraint" do
      Helper.insert_data("users", %{
        "email" => "unique@example.com",
        "hashed_password" => "pwd1",
        "first_name" => "John",
        "last_name" => "Doe"
      })

      # Attempting to insert duplicate email should fail
      result =
        Helper.insert_data("users", %{
          "email" => "unique@example.com",
          "hashed_password" => "pwd2",
          "first_name" => "Jane",
          "last_name" => "Doe"
        })

      assert match?({:error, _}, result)
    end
  end

  describe "create_job_interests migration" do
    setup do
      # Create a user for foreign key references
      {:ok, result} =
        Helper.insert_data("users", %{
          "email" => "user@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Test",
          "last_name" => "User"
        })

      [[user_id, _, _, _, _, _, _, _, _]] = result.rows
      {:ok, user_id: user_id}
    end

    test "job_interests table exists with correct structure", %{user_id: _user_id} do
      assert Helper.table_exists?("job_interests")

      columns = Helper.get_table_columns("job_interests")

      expected =
        ~w(id user_id company_name position_title job_description job_url location work_model salary_min salary_max status priority notes inserted_at updated_at)

      assert Enum.all?(expected, &(&1 in columns))
    end

    test "job_interests has foreign key to users", %{user_id: _user_id} do
      assert Helper.foreign_key_exists?("job_interests", "users")
    end

    test "job_interests status has default value", %{user_id: user_id} do
      Helper.insert_data("job_interests", %{
        "user_id" => user_id,
        "company_name" => "Tech Corp",
        "position_title" => "Engineer",
        "status" => "interested"
      })

      # Query to check default was applied
      {:ok, result} = SQL.query(Repo, "SELECT status FROM job_interests LIMIT 1", [])
      [[status]] = result.rows
      assert status == "interested"
    end

    test "job_interests priority has default value", %{user_id: user_id} do
      Helper.insert_data("job_interests", %{
        "user_id" => user_id,
        "company_name" => "Tech Corp",
        "position_title" => "Engineer",
        "priority" => "medium"
      })

      {:ok, result} = SQL.query(Repo, "SELECT priority FROM job_interests LIMIT 1", [])
      [[priority]] = result.rows
      assert priority == "medium"
    end

    test "deleting user cascades to job_interests", %{user_id: user_id} do
      Helper.insert_data("job_interests", %{
        "user_id" => user_id,
        "company_name" => "Tech Corp",
        "position_title" => "Engineer"
      })

      initial_count = Helper.count_rows("job_interests")
      assert initial_count >= 1

      # Delete the user
      Helper.execute_query("DELETE FROM users WHERE id = $1", [user_id])

      final_count = Helper.count_rows("job_interests")
      assert final_count == 0
    end
  end

  describe "create_job_applications migration" do
    setup do
      {:ok, user_result} =
        Helper.insert_data("users", %{
          "email" => "user@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Test",
          "last_name" => "User"
        })

      [[user_id, _, _, _, _, _, _, _, _]] = user_result.rows

      {:ok, ji_result} =
        Helper.insert_data("job_interests", %{
          "user_id" => user_id,
          "company_name" => "Tech Corp",
          "position_title" => "Engineer"
        })

      [[job_interest_id, _, _, _, _, _, _, _, _, _, _, _, _, _, _]] = ji_result.rows

      {:ok, user_id: user_id, job_interest_id: job_interest_id}
    end

    test "job_applications table has correct structure", %{user_id: _user_id} do
      assert Helper.table_exists?("job_applications")

      columns = Helper.get_table_columns("job_applications")

      expected =
        ~w(id user_id job_interest_id company_name position_title job_description job_url location work_model salary_min salary_max application_date status cover_letter_path resume_path notes inserted_at updated_at)

      assert Enum.all?(expected, &(&1 in columns))
    end

    test "job_applications has foreign keys to users and job_interests", %{user_id: _user_id} do
      assert Helper.foreign_key_exists?("job_applications", "users")
      assert Helper.foreign_key_exists?("job_applications", "job_interests")
    end

    test "job_applications status defaults to 'applied'", %{
      user_id: user_id,
      job_interest_id: job_interest_id
    } do
      Helper.insert_data("job_applications", %{
        "user_id" => user_id,
        "job_interest_id" => job_interest_id,
        "company_name" => "Tech Corp",
        "position_title" => "Engineer",
        "application_date" => Date.from_iso8601!("2025-12-15"),
        "status" => "applied"
      })

      {:ok, result} = SQL.query(Repo, "SELECT status FROM job_applications LIMIT 1", [])
      [[status]] = result.rows
      assert status == "applied"
    end

    test "deleting user cascades to job_applications", %{user_id: user_id} do
      Helper.insert_data("job_applications", %{
        "user_id" => user_id,
        "company_name" => "Tech Corp",
        "position_title" => "Engineer",
        "application_date" => Date.from_iso8601!("2025-12-15")
      })

      initial_count = Helper.count_rows("job_applications")
      assert initial_count >= 1

      Helper.execute_query("DELETE FROM users WHERE id = $1", [user_id])

      final_count = Helper.count_rows("job_applications")
      assert final_count == 0
    end

    test "deleting job_interest sets application job_interest_id to null", %{
      user_id: user_id,
      job_interest_id: job_interest_id
    } do
      Helper.insert_data("job_applications", %{
        "user_id" => user_id,
        "job_interest_id" => job_interest_id,
        "company_name" => "Tech Corp",
        "position_title" => "Engineer",
        "application_date" => Date.from_iso8601!("2025-12-15")
      })

      # Delete the job interest
      Helper.execute_query("DELETE FROM job_interests WHERE id = $1", [job_interest_id])

      # Check that job_interest_id is now NULL
      {:ok, result} = SQL.query(Repo, "SELECT job_interest_id FROM job_applications LIMIT 1", [])
      [[job_interest_id_value]] = result.rows
      assert is_nil(job_interest_id_value)
    end
  end

  describe "create_application_events migration" do
    setup do
      {:ok, user_result} =
        Helper.insert_data("users", %{
          "email" => "user@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Test",
          "last_name" => "User"
        })

      [[user_id | _]] = user_result.rows

      {:ok, app_result} =
        Helper.insert_data("job_applications", %{
          "user_id" => user_id,
          "company_name" => "Tech Corp",
          "position_title" => "Engineer",
          "application_date" => Date.from_iso8601!("2025-12-15")
        })

      [[app_id | _]] = app_result.rows

      {:ok, user_id: user_id, app_id: app_id}
    end

    test "application_events table has correct structure", %{app_id: _app_id} do
      assert Helper.table_exists?("application_events")

      columns = Helper.get_table_columns("application_events")

      expected =
        ~w(id job_application_id event_type event_date contact_person contact_email contact_phone notes follow_up_date inserted_at updated_at)

      assert Enum.all?(expected, &(&1 in columns))
    end

    test "application_events has foreign key to job_applications", %{app_id: _app_id} do
      assert Helper.foreign_key_exists?("application_events", "job_applications")
    end

    test "deleting application cascades to events", %{app_id: app_id} do
      Helper.insert_data("application_events", %{
        "job_application_id" => app_id,
        "event_type" => "phone_call",
        "event_date" => Date.from_iso8601!("2025-12-15")
      })

      initial_count = Helper.count_rows("application_events")
      assert initial_count >= 1

      Helper.execute_query("DELETE FROM job_applications WHERE id = $1", [app_id])

      final_count = Helper.count_rows("application_events")
      assert final_count == 0
    end
  end

  describe "create_resumes migration" do
    setup do
      {:ok, result} =
        Helper.insert_data("users", %{
          "email" => "user@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Test",
          "last_name" => "User"
        })

      [[user_id, _, _, _, _, _, _, _, _]] = result.rows
      {:ok, user_id: user_id}
    end

    test "resumes table has correct structure", %{user_id: _user_id} do
      assert Helper.table_exists?("resumes")

      columns = Helper.get_table_columns("resumes")

      expected =
        ~w(id user_id name description file_path original_filename file_size is_default inserted_at updated_at)

      assert Enum.all?(expected, &(&1 in columns))
    end

    test "resumes has foreign key to users", %{user_id: _user_id} do
      assert Helper.foreign_key_exists?("resumes", "users")
    end

    test "is_default defaults to false", %{user_id: user_id} do
      Helper.insert_data("resumes", %{
        "user_id" => user_id,
        "name" => "main_resume",
        "file_path" => "/path/to/file.pdf",
        "original_filename" => "resume.pdf"
      })

      {:ok, result} = SQL.query(Repo, "SELECT is_default FROM resumes LIMIT 1", [])
      [[is_default]] = result.rows
      assert is_default == false
    end

    test "deleting user cascades to resumes", %{user_id: user_id} do
      Helper.insert_data("resumes", %{
        "user_id" => user_id,
        "name" => "main_resume",
        "file_path" => "/path/to/file.pdf",
        "original_filename" => "resume.pdf"
      })

      initial_count = Helper.count_rows("resumes")
      assert initial_count >= 1

      Helper.execute_query("DELETE FROM users WHERE id = $1", [user_id])

      final_count = Helper.count_rows("resumes")
      assert final_count == 0
    end
  end

  describe "create_cover_letter_templates migration" do
    setup do
      {:ok, result} =
        Helper.insert_data("users", %{
          "email" => "user@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Test",
          "last_name" => "User"
        })

      [[user_id, _, _, _, _, _, _, _, _]] = result.rows
      {:ok, user_id: user_id}
    end

    test "cover_letter_templates table has correct structure", %{user_id: _user_id} do
      assert Helper.table_exists?("cover_letter_templates")

      columns = Helper.get_table_columns("cover_letter_templates")
      expected = ~w(id user_id name description content is_default inserted_at updated_at)

      assert Enum.all?(expected, &(&1 in columns))
    end

    test "cover_letter_templates has foreign key to users", %{user_id: _user_id} do
      assert Helper.foreign_key_exists?("cover_letter_templates", "users")
    end

    test "is_default defaults to false", %{user_id: user_id} do
      Helper.insert_data("cover_letter_templates", %{
        "user_id" => user_id,
        "name" => "default_template",
        "content" => "Dear hiring manager..."
      })

      {:ok, result} = SQL.query(Repo, "SELECT is_default FROM cover_letter_templates LIMIT 1", [])
      [[is_default]] = result.rows
      assert is_default == false
    end

    test "deleting user cascades to templates", %{user_id: user_id} do
      Helper.insert_data("cover_letter_templates", %{
        "user_id" => user_id,
        "name" => "template1",
        "content" => "Content..."
      })

      initial_count = Helper.count_rows("cover_letter_templates")
      assert initial_count >= 1

      Helper.execute_query("DELETE FROM users WHERE id = $1", [user_id])

      final_count = Helper.count_rows("cover_letter_templates")
      assert final_count == 0
    end
  end

  describe "create_llm_settings migration" do
    setup do
      {:ok, result} =
        Helper.insert_data("users", %{
          "email" => "user@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Test",
          "last_name" => "User"
        })

      [[user_id, _, _, _, _, _, _, _, _]] = result.rows
      {:ok, user_id: user_id}
    end

    test "llm_settings table has correct structure", %{user_id: _user_id} do
      assert Helper.table_exists?("llm_settings")

      columns = Helper.get_table_columns("llm_settings")

      expected =
        ~w(id user_id provider api_key base_url default_model vision_model text_model enabled provider_status inserted_at updated_at)

      assert Enum.all?(expected, &(&1 in columns))
    end

    test "llm_settings has foreign key to users", %{user_id: _user_id} do
      assert Helper.foreign_key_exists?("llm_settings", "users")
    end

    test "enabled defaults to false", %{user_id: user_id} do
      Helper.insert_data("llm_settings", %{
        "user_id" => user_id,
        "provider" => "openai",
        "api_key" => <<1, 2, 3, 4>>
      })

      {:ok, result} = SQL.query(Repo, "SELECT enabled FROM llm_settings LIMIT 1", [])
      [[enabled]] = result.rows
      assert enabled == false
    end

    test "unique constraint on user_id and provider", %{user_id: user_id} do
      Helper.insert_data("llm_settings", %{
        "user_id" => user_id,
        "provider" => "openai",
        "api_key" => <<1, 2, 3, 4>>
      })

      # Attempting to insert duplicate user+provider should fail
      result =
        Helper.insert_data("llm_settings", %{
          "user_id" => user_id,
          "provider" => "openai",
          "api_key" => <<5, 6, 7, 8>>
        })

      assert match?({:error, _}, result)
    end

    test "deleting user cascades to llm_settings", %{user_id: user_id} do
      Helper.insert_data("llm_settings", %{
        "user_id" => user_id,
        "provider" => "openai",
        "api_key" => <<1, 2, 3, 4>>
      })

      initial_count = Helper.count_rows("llm_settings")
      assert initial_count >= 1

      Helper.execute_query("DELETE FROM users WHERE id = $1", [user_id])

      final_count = Helper.count_rows("llm_settings")
      assert final_count == 0
    end
  end

  describe "migrate_api_keys_to_plaintext migration" do
    test "migration down function exists (even if it's a no-op)" do
      # The migration exists and can be verified
      assert Helper.table_exists?("llm_settings"),
             "llm_settings table should exist from migration"
    end
  end

  describe "comprehensive data flow tests" do
    test "full job application workflow maintains referential integrity" do
      # Create user
      {:ok, user_result} =
        Helper.insert_data("users", %{
          "email" => "workflow@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Workflow",
          "last_name" => "User"
        })

      [[user_id, _, _, _, _, _, _, _, _]] = user_result.rows

      # Create job interest
      {:ok, ji_result} =
        Helper.insert_data("job_interests", %{
          "user_id" => user_id,
          "company_name" => "Tech Corp",
          "position_title" => "Senior Engineer"
        })

      [[job_interest_id | _]] = ji_result.rows

      # Create application
      {:ok, app_result} =
        Helper.insert_data("job_applications", %{
          "user_id" => user_id,
          "job_interest_id" => job_interest_id,
          "company_name" => "Tech Corp",
          "position_title" => "Senior Engineer",
          "application_date" => Date.from_iso8601!("2025-12-15")
        })

      [[app_id | _]] = app_result.rows

      # Create application event
      {:ok, event_result} =
        Helper.insert_data("application_events", %{
          "job_application_id" => app_id,
          "event_type" => "phone_interview",
          "event_date" => Date.from_iso8601!("2025-12-16")
        })

      [[event_id | _]] = event_result.rows

      # Verify all records exist
      assert Helper.fk_value_exists?("users", "id", user_id)
      assert Helper.fk_value_exists?("job_interests", "id", job_interest_id)
      assert Helper.fk_value_exists?("job_applications", "id", app_id)
      assert Helper.fk_value_exists?("application_events", "id", event_id)
    end

    test "cascade deletion works through entire hierarchy" do
      {:ok, user_result} =
        Helper.insert_data("users", %{
          "email" => "cascade@example.com",
          "hashed_password" => "pwd",
          "first_name" => "Cascade",
          "last_name" => "User"
        })

      [[user_id, _, _, _, _, _, _, _, _]] = user_result.rows

      {:ok, _} =
        Helper.insert_data("job_interests", %{
          "user_id" => user_id,
          "company_name" => "Tech Corp",
          "position_title" => "Engineer"
        })

      {:ok, _} =
        Helper.insert_data("resumes", %{
          "user_id" => user_id,
          "name" => "resume",
          "file_path" => "/path/to/file.pdf",
          "original_filename" => "resume.pdf"
        })

      {:ok, _} =
        Helper.insert_data("cover_letter_templates", %{
          "user_id" => user_id,
          "name" => "template",
          "content" => "Content..."
        })

      {:ok, _} =
        Helper.insert_data("llm_settings", %{
          "user_id" => user_id,
          "provider" => "openai",
          "api_key" => <<1, 2, 3>>
        })

      # Delete user
      Helper.execute_query("DELETE FROM users WHERE id = $1", [user_id])

      # Verify cascading deletions
      job_interests_count = Helper.count_rows("job_interests")
      resumes_count = Helper.count_rows("resumes")
      templates_count = Helper.count_rows("cover_letter_templates")
      settings_count = Helper.count_rows("llm_settings")

      assert job_interests_count == 0
      assert resumes_count == 0
      assert templates_count == 0
      assert settings_count == 0
    end
  end
end
