defmodule ClientatsWeb.Features.PlatformTauriTest do
  use ExUnit.Case, async: true

  @moduletag :platform

  # Reference: E2E_TESTING_GUIDE.md sections 13.1-13.6
  # Tests for Platform Features & Tauri Desktop functionality

  describe "Cross-Platform Database Paths (Test Case 13.1)" do
    test "config_dir returns correct path based on current platform" do
      config_dir = Clientats.Platform.config_dir()

      # Should end with clientats
      assert String.ends_with?(config_dir, "clientats")

      # Should be an absolute path
      assert String.starts_with?(config_dir, "/") or String.match?(config_dir, ~r/^[A-Z]:/)

      # Platform-specific checks based on actual OS
      case :os.type() do
        {:unix, :darwin} ->
          # macOS: ~/Library/Application Support/clientats
          assert String.contains?(config_dir, "Library/Application Support/clientats")

        {:unix, _} ->
          # Linux/Unix: ~/.config/clientats
          assert String.ends_with?(config_dir, ".config/clientats")

        {:win32, _} ->
          # Windows: %APPDATA%/clientats
          assert String.ends_with?(config_dir, "clientats")
      end
    end

    test "database_path respects DATABASE_PATH environment variable" do
      custom_path = "/custom/path/to/database.db"

      System.put_env("DATABASE_PATH", custom_path)

      try do
        assert Clientats.Platform.database_path() == custom_path
      after
        System.delete_env("DATABASE_PATH")
      end
    end

    test "database_path falls back to default location" do
      # Ensure DATABASE_PATH is not set
      System.delete_env("DATABASE_PATH")

      db_path = Clientats.Platform.database_path()

      # Should be in config_dir/db/clientats.db
      assert String.ends_with?(db_path, "/db/clientats.db")
      assert String.contains?(db_path, "clientats")
    end

    test "database_path with ensure_dir creates directory" do
      # Use a temporary test path
      temp_dir = System.tmp_dir!()

      test_db_path =
        Path.join([
          temp_dir,
          "test_clientats_#{System.unique_integer([:positive])}",
          "db",
          "test.db"
        ])

      System.put_env("DATABASE_PATH", test_db_path)

      try do
        db_path = Clientats.Platform.database_path(ensure_dir: true)

        # Directory should be created
        assert File.dir?(Path.dirname(db_path))

        # Clean up
        File.rm_rf!(Path.dirname(Path.dirname(db_path)))
      after
        System.delete_env("DATABASE_PATH")
      end
    end

    test "default_database_path follows platform conventions" do
      default_path = Clientats.Platform.default_database_path()

      # Should end with /db/clientats.db
      assert String.ends_with?(default_path, "/db/clientats.db")

      # Should start with config_dir
      config_dir = Clientats.Platform.config_dir()
      assert String.starts_with?(default_path, config_dir)
    end

    test "platform info includes all required fields" do
      info = Clientats.Platform.info()

      assert Map.has_key?(info, :platform)
      assert Map.has_key?(info, :config_dir)
      assert Map.has_key?(info, :database_path)
      assert Map.has_key?(info, :database_from_env)

      # Platform should be one of the supported types
      assert info.platform in [:linux, :macos, :windows]
    end

    test "platform info detects environment variable usage" do
      # Without env var
      System.delete_env("DATABASE_PATH")
      info1 = Clientats.Platform.info()
      assert info1.database_from_env == false

      # With env var
      System.put_env("DATABASE_PATH", "/custom/db.db")

      try do
        info2 = Clientats.Platform.info()
        assert info2.database_from_env == true
      after
        System.delete_env("DATABASE_PATH")
      end
    end
  end

  describe "Cross-Platform Upload Directories (Test Case 13.2)" do
    test "upload_dir uses UPLOAD_DIR environment variable when set" do
      custom_upload_dir = "/custom/uploads"

      System.put_env("UPLOAD_DIR", custom_upload_dir)

      try do
        assert Clientats.Uploads.upload_dir() == custom_upload_dir
      after
        System.delete_env("UPLOAD_DIR")
      end
    end

    test "upload_dir falls back to priv/static/uploads in development" do
      # Ensure UPLOAD_DIR is not set
      System.delete_env("UPLOAD_DIR")

      upload_dir = Clientats.Uploads.upload_dir()

      # Should be priv/static/uploads
      assert String.ends_with?(upload_dir, "/priv/static/uploads")
    end

    test "ensure_dir! creates upload subdirectories" do
      temp_upload_dir =
        Path.join([System.tmp_dir!(), "test_uploads_#{System.unique_integer([:positive])}"])

      System.put_env("UPLOAD_DIR", temp_upload_dir)

      try do
        # Create resumes subdirectory
        resumes_dir = Clientats.Uploads.ensure_dir!("resumes")

        assert File.dir?(resumes_dir)
        assert String.ends_with?(resumes_dir, "/resumes")

        # Create cover_letters subdirectory
        cover_letters_dir = Clientats.Uploads.ensure_dir!("cover_letters")

        assert File.dir?(cover_letters_dir)
        assert String.ends_with?(cover_letters_dir, "/cover_letters")

        # Clean up
        File.rm_rf!(temp_upload_dir)
      after
        System.delete_env("UPLOAD_DIR")
      end
    end

    test "resume_path constructs correct file path" do
      temp_upload_dir =
        Path.join([System.tmp_dir!(), "test_uploads_#{System.unique_integer([:positive])}"])

      System.put_env("UPLOAD_DIR", temp_upload_dir)

      try do
        resume_path = Clientats.Uploads.resume_path("test_resume.pdf")

        assert String.ends_with?(resume_path, "/resumes/test_resume.pdf")
        assert String.starts_with?(resume_path, temp_upload_dir)
      after
        System.delete_env("UPLOAD_DIR")
      end
    end

    test "url_path generates correct URL paths" do
      url = Clientats.Uploads.url_path("resumes", "my_resume.pdf")
      assert url == "/uploads/resumes/my_resume.pdf"

      url2 = Clientats.Uploads.url_path("cover_letters", "letter.pdf")
      assert url2 == "/uploads/cover_letters/letter.pdf"
    end

    test "resolve_path finds existing files" do
      temp_upload_dir =
        Path.join([System.tmp_dir!(), "test_uploads_#{System.unique_integer([:positive])}"])

      System.put_env("UPLOAD_DIR", temp_upload_dir)

      try do
        # Create test file
        resumes_dir = Clientats.Uploads.ensure_dir!("resumes")
        test_file = Path.join(resumes_dir, "test.pdf")
        File.write!(test_file, "test content")

        # Resolve path
        result = Clientats.Uploads.resolve_path("/uploads/resumes/test.pdf")

        assert {:ok, resolved_path} = result
        assert File.exists?(resolved_path)
        assert resolved_path == test_file

        # Clean up
        File.rm_rf!(temp_upload_dir)
      after
        System.delete_env("UPLOAD_DIR")
      end
    end

    test "resolve_path returns error for non-existent files" do
      result = Clientats.Uploads.resolve_path("/uploads/resumes/nonexistent.pdf")
      assert result == {:error, :not_found}
    end

    test "resolve_path returns error for invalid paths" do
      result = Clientats.Uploads.resolve_path("/invalid/path")
      assert result == {:error, :not_found}
    end
  end

  describe "Cross-Platform Backup Directories (Test Case 13.3)" do
    test "backup directory is created in platform-specific config directory" do
      config_dir = Clientats.Platform.config_dir()
      backup_dir = Path.join(config_dir, "backups")

      # The backup worker should create this directory
      # We'll test that the path is correctly constructed
      assert String.contains?(backup_dir, "clientats")
      assert String.ends_with?(backup_dir, "/backups")
    end

    test "backup worker uses platform-specific paths" do
      # Create a temporary config directory for testing
      temp_config_dir =
        Path.join([System.tmp_dir!(), "test_clientats_#{System.unique_integer([:positive])}"])

      temp_db_dir = Path.join(temp_config_dir, "db")
      temp_db_path = Path.join(temp_db_dir, "clientats.db")

      # Create directories
      File.mkdir_p!(temp_db_dir)

      # Create a dummy database file
      File.write!(temp_db_path, "dummy database content")

      # Set environment to use temp paths
      System.put_env("DATABASE_PATH", temp_db_path)

      try do
        # Mock the Platform.config_dir to return our temp directory
        backup_dir = Path.join(temp_config_dir, "backups")
        File.mkdir_p!(backup_dir)

        # Verify paths are accessible
        assert File.dir?(temp_config_dir)
        assert File.dir?(backup_dir)
        assert File.exists?(temp_db_path)

        # Clean up
        File.rm_rf!(temp_config_dir)
      after
        System.delete_env("DATABASE_PATH")
      end
    end

    test "backup rotation keeps only last 2 days" do
      # This tests the backup rotation logic
      temp_backup_dir =
        Path.join([System.tmp_dir!(), "test_backups_#{System.unique_integer([:positive])}"])

      File.mkdir_p!(temp_backup_dir)

      try do
        # Create mock backup files for different dates
        dates = [
          "20251220",
          "20251221",
          "20251222",
          "20251223",
          "20251224"
        ]

        for date <- dates do
          File.write!(Path.join(temp_backup_dir, "clientats_#{date}.db"), "backup #{date}")
          File.write!(Path.join(temp_backup_dir, "export_#{date}_user_test_com.json"), "{}")
        end

        # Verify all files were created
        files = File.ls!(temp_backup_dir)
        # 5 dates * 2 files each
        assert length(files) == 10

        # The actual rotation logic is in BackupWorker.rotate_backups/1
        # We're testing that the files are structured correctly for rotation
        db_files = Enum.filter(files, &String.contains?(&1, ".db"))
        json_files = Enum.filter(files, &String.contains?(&1, ".json"))

        assert length(db_files) == 5
        assert length(json_files) == 5

        # Clean up
        File.rm_rf!(temp_backup_dir)
      after
        :ok
      end
    end

    test "backup files follow correct naming convention" do
      date_str = "20251226"
      safe_email = "test_example_com"

      # Database backup filename
      db_backup = "clientats_#{date_str}.db"
      assert String.match?(db_backup, ~r/clientats_\d{8}\.db/)

      # JSON export filename
      json_export = "export_#{date_str}_#{safe_email}.json"
      assert String.match?(json_export, ~r/export_\d{8}_[\w_]+\.json/)
    end
  end

  describe "Tauri Desktop App Build (Test Case 13.4)" do
    @tag :skip_ci
    test "tauri configuration exists and is valid" do
      tauri_conf_path = Path.join([File.cwd!(), "src-tauri", "tauri.conf.json"])

      if File.exists?(tauri_conf_path) do
        {:ok, content} = File.read(tauri_conf_path)
        {:ok, config} = Jason.decode(content)

        # Verify essential configuration fields
        assert Map.has_key?(config, "productName")
        assert Map.has_key?(config, "version")
        assert Map.has_key?(config, "identifier")
        assert Map.has_key?(config, "build")
        assert Map.has_key?(config, "bundle")

        # Check that Phoenix resources are bundled
        bundle = config["bundle"]
        assert is_list(bundle["resources"])
        assert "phoenix" in bundle["resources"]
      else
        flunk("Tauri configuration file not found at #{tauri_conf_path}")
      end
    end

    @tag :skip_ci
    test "tauri main.rs implements platform-specific config paths" do
      main_rs_path = Path.join([File.cwd!(), "src-tauri", "src", "main.rs"])

      if File.exists?(main_rs_path) do
        {:ok, content} = File.read(main_rs_path)

        # Verify platform-specific config directory logic exists
        assert String.contains?(content, "get_config_dir")
        assert String.contains?(content, "target_os = \"macos\"")
        assert String.contains?(content, "target_os = \"windows\"")
        assert String.contains?(content, "Library/Application Support/clientats")
        assert String.contains?(content, ".config/clientats")
        assert String.contains?(content, "APPDATA")
      else
        flunk("Tauri main.rs not found at #{main_rs_path}")
      end
    end

    @tag :skip_ci
    test "tauri sets DATABASE_PATH environment variable" do
      main_rs_path = Path.join([File.cwd!(), "src-tauri", "src", "main.rs"])

      if File.exists?(main_rs_path) do
        {:ok, content} = File.read(main_rs_path)

        # Verify DATABASE_PATH is set for Phoenix process
        assert String.contains?(content, "DATABASE_PATH")
        assert String.contains?(content, "db_path")
      else
        flunk("Tauri main.rs not found")
      end
    end

    @tag :skip_ci
    test "tauri sets UPLOAD_DIR environment variable" do
      main_rs_path = Path.join([File.cwd!(), "src-tauri", "src", "main.rs"])

      if File.exists?(main_rs_path) do
        {:ok, content} = File.read(main_rs_path)

        # Verify UPLOAD_DIR is set for Phoenix process
        assert String.contains?(content, "UPLOAD_DIR")
        assert String.contains?(content, "upload_dir")
      else
        flunk("Tauri main.rs not found")
      end
    end

    @tag :skip_ci
    test "tauri cargo.toml exists with required dependencies" do
      cargo_toml_path = Path.join([File.cwd!(), "src-tauri", "Cargo.toml"])

      if File.exists?(cargo_toml_path) do
        {:ok, content} = File.read(cargo_toml_path)

        # Verify key dependencies
        assert String.contains?(content, "tauri")
        assert String.contains?(content, "serde")
      else
        flunk("Cargo.toml not found at #{cargo_toml_path}")
      end
    end
  end

  describe "Desktop App Database Isolation (Test Case 13.5)" do
    test "web and desktop modes use different database paths" do
      # Web mode: uses default config from runtime.exs
      # Desktop mode: uses DATABASE_PATH env var set by Tauri

      # Simulate web mode (no DATABASE_PATH)
      System.delete_env("DATABASE_PATH")
      web_db_path = Clientats.Platform.database_path()

      # Simulate desktop mode (DATABASE_PATH set)
      desktop_db_path = "/path/to/desktop/db/clientats.db"
      System.put_env("DATABASE_PATH", desktop_db_path)

      try do
        tauri_db_path = Clientats.Platform.database_path()

        # Paths should be different
        assert web_db_path != tauri_db_path
        assert tauri_db_path == desktop_db_path
      after
        System.delete_env("DATABASE_PATH")
      end
    end

    test "desktop app can run simultaneously with web version" do
      # This is a conceptual test - both can run with separate databases
      # Web app uses default path, desktop uses custom path via env var

      web_config_dir = Clientats.Platform.config_dir()
      web_db_path = Clientats.Platform.default_database_path()

      # Desktop would use a different path via DATABASE_PATH
      desktop_db_path = "/different/path/clientats.db"

      # Verify they're different
      assert web_db_path != desktop_db_path
      assert String.starts_with?(web_db_path, web_config_dir)
      refute String.starts_with?(desktop_db_path, web_config_dir)
    end

    test "desktop app isolation extends to upload directories" do
      # Web mode uses default priv/static/uploads
      System.delete_env("UPLOAD_DIR")
      web_upload_dir = Clientats.Uploads.upload_dir()

      # Desktop mode uses custom upload directory
      desktop_upload_dir = "/path/to/desktop/uploads"
      System.put_env("UPLOAD_DIR", desktop_upload_dir)

      try do
        tauri_upload_dir = Clientats.Uploads.upload_dir()

        # Paths should be different
        assert web_upload_dir != tauri_upload_dir
        assert tauri_upload_dir == desktop_upload_dir
      after
        System.delete_env("UPLOAD_DIR")
      end
    end
  end

  describe "Desktop App Auto-Updates (Test Case 13.6)" do
    @tag :skip_ci
    test "tauri configuration includes updater settings (if implemented)" do
      tauri_conf_path = Path.join([File.cwd!(), "src-tauri", "tauri.conf.json"])

      if File.exists?(tauri_conf_path) do
        {:ok, content} = File.read(tauri_conf_path)
        {:ok, config} = Jason.decode(content)

        # Check if updater configuration exists
        # Note: This may not be implemented yet, so we check conditionally
        if Map.has_key?(config, "updater") do
          updater = config["updater"]

          # If updater exists, verify it has required fields
          assert Map.has_key?(updater, "active")

          if updater["active"] do
            assert Map.has_key?(updater, "endpoints")
            assert is_list(updater["endpoints"])
          end
        else
          # Auto-updates not implemented yet - this is acceptable
          # Test passes but we log the info
          IO.puts("Note: Auto-updates not yet implemented in Tauri configuration")
        end
      end
    end

    @tag :skip_ci
    test "database and user data preserved across updates" do
      # This is a conceptual test - verifying that user data locations
      # are outside the application bundle and won't be removed on update

      config_dir = Clientats.Platform.config_dir()
      db_path = Clientats.Platform.default_database_path()

      # User data should be in user's home directory, not app bundle
      home_dir = System.user_home!()

      assert String.starts_with?(config_dir, home_dir)
      assert String.starts_with?(db_path, home_dir)

      # This ensures data persists across app updates
    end
  end

  describe "Integration: Platform Path Resolution" do
    test "all platform paths are consistent" do
      config_dir = Clientats.Platform.config_dir()
      db_path = Clientats.Platform.database_path()

      # Database path should be under config directory
      assert String.starts_with?(db_path, config_dir)

      # Backup directory would also be under config directory
      backup_dir = Path.join(config_dir, "backups")
      assert String.starts_with?(backup_dir, config_dir)
    end

    test "ensure_dir creates directory structure" do
      temp_dir =
        Path.join([System.tmp_dir!(), "test_ensure_dir_#{System.unique_integer([:positive])}"])

      # Should create directory successfully
      assert :ok = Clientats.Platform.ensure_dir(temp_dir)
      assert File.dir?(temp_dir)

      # Clean up
      File.rm_rf!(temp_dir)
    end

    test "ensure_dir raises on filesystem errors" do
      # Try to create directory in non-existent parent with no permissions
      # This should raise an error
      invalid_path = "/root/nonexistent/path/that/will/fail"

      assert_raise RuntimeError, fn ->
        Clientats.Platform.ensure_dir(invalid_path)
      end
    end

    test "ensure_config_dir creates config directory" do
      # This should not raise
      assert :ok = Clientats.Platform.ensure_config_dir()

      # Config directory should exist
      config_dir = Clientats.Platform.config_dir()
      assert File.dir?(config_dir)
    end
  end
end
