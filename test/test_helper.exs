ExUnit.start(exclude: [:feature])
Ecto.Adapters.SQL.Sandbox.mode(Clientats.Repo, :manual)

# Load migration test helper
Code.require_file("support/migration_test_helper.exs", __DIR__)
