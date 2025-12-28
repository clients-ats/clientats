ExUnit.start(exclude: [:feature, :browser, :production_paths])
Ecto.Adapters.SQL.Sandbox.mode(Clientats.Repo, :manual)

# Load migration test helper
Code.require_file("support/migration_test_helper.exs", __DIR__)

# Load E2E support modules
Code.require_file("e2e/support/user_fixtures.ex", __DIR__)
Code.require_file("e2e/support/job_fixtures.ex", __DIR__)
Code.require_file("e2e/support/document_fixtures.ex", __DIR__)
