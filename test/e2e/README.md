# E2E Testing Guide

This directory contains end-to-end (E2E) tests for Clientats using Wallaby and ChromeDriver.

## Directory Structure

```
test/e2e/
├── auth/              # Authentication and authorization flows
├── job_applications/  # Job application workflows and events
├── job_interests/     # Job interest management workflows
├── resumes/          # Resume upload and management workflows
├── cover_letters/    # Cover letter template workflows
├── help/             # Help system and tutorials
├── support/          # Shared test fixtures and helpers
│   ├── user_fixtures.ex       # User creation and login helpers
│   ├── job_fixtures.ex        # Job-related fixtures
│   └── document_fixtures.ex   # Resume and cover letter fixtures
└── README.md         # This file
```

## Prerequisites

### ChromeDriver Installation

E2E tests require ChromeDriver to be installed and available in your PATH.

**macOS:**
```bash
brew install chromedriver
```

**Linux:**
```bash
# Download and install ChromeDriver
wget https://chromedriver.storage.googleapis.com/LATEST_RELEASE
VERSION=$(cat LATEST_RELEASE)
wget https://chromedriver.storage.googleapis.com/$VERSION/chromedriver_linux64.zip
unzip chromedriver_linux64.zip
sudo mv chromedriver /usr/local/bin/
sudo chmod +x /usr/local/bin/chromedriver
```

**Windows:**
- Download from https://chromedriver.chromium.org/downloads
- Add to PATH

### Verify Installation
```bash
chromedriver --version
```

## Running E2E Tests

### Run All E2E Tests
```bash
mix test --only feature
```

### Run Specific E2E Test File
```bash
mix test test/e2e/job_applications/job_application_flow_test.exs
```

### Run with Visual Browser (Non-Headless)
```bash
HEADLESS=false mix test --only feature
```

### Run in Headless Mode (CI)
```bash
HEADLESS=true mix test --only feature
# or
CI=true mix test --only feature
```

## Writing E2E Tests

### Basic Test Structure

```elixir
defmodule ClientatsWeb.E2E.MyFeatureTest do
  use ClientatsWeb.FeatureCase, async: false

  import Wallaby.Query
  import ClientatsWeb.E2E.UserFixtures
  import ClientatsWeb.E2E.JobFixtures

  @moduletag :feature

  test "my feature workflow", %{session: session} do
    # Create and login user
    user = create_user_and_login(session)

    # Navigate and interact with the application
    session
    |> visit("/dashboard")
    |> assert_has(css("h1", text: "Dashboard"))
    |> click(button("Add New"))
    |> fill_in(css("input[name='title']"), with: "Test Title")
    |> click(button("Save"))
    |> assert_has(css(".success", text: "Saved successfully"))
  end
end
```

### Using Fixtures

The `test/e2e/support/` directory contains shared fixtures:

**User Fixtures:**
```elixir
import ClientatsWeb.E2E.UserFixtures

# Create user and login
user = create_user_and_login(session)

# Create user without login
user = create_user()
```

**Job Fixtures:**
```elixir
import ClientatsWeb.E2E.JobFixtures

# Create job interest
interest = create_job_interest(user.id)

# Create job application
app = create_job_application(user.id)

# Create application from interest
app = create_job_application_from_interest(user.id, interest.id)

# Create application event
event = create_application_event(app.id, %{event_type: "interview"})
```

**Document Fixtures:**
```elixir
import ClientatsWeb.E2E.DocumentFixtures

# Create resume
resume = create_resume(user.id)

# Create cover letter template
template = create_cover_letter(user.id)
```

### Common Wallaby Patterns

**Finding Elements:**
```elixir
# By CSS selector
css("input[name='email']")
css(".btn-primary")
css("h1", text: "Welcome")

# By button text
button("Sign in")

# By link text
link("Dashboard")
```

**Interactions:**
```elixir
session
|> click(button("Submit"))
|> fill_in(css("input[name='email']"), with: "user@example.com")
|> select(css("select[name='priority']"), option: "High")
|> check(css("input[type='checkbox']"))
|> attach_file(css("input[type='file']"), path: "/path/to/file.pdf")
```

**Assertions:**
```elixir
session
|> assert_has(css("h1", text: "Success"))
|> refute_has(css(".error-message"))
|> assert_text("Welcome back")
```

## Test Best Practices

1. **Use `async: false`**: E2E tests should not run in parallel due to shared database state
2. **Tag with `:feature`**: All E2E tests must have `@moduletag :feature`
3. **Use Fixtures**: Reuse fixture functions from `test/e2e/support/` instead of duplicating code
4. **Clear Test Names**: Use descriptive test names that explain the user workflow
5. **Isolate Tests**: Each test should be independent and set up its own data
6. **Clean Up**: The database sandbox handles cleanup automatically
7. **Screenshots on Failure**: Wallaby automatically takes screenshots when tests fail (saved to `screenshots/`)

## Debugging

### View Browser During Tests
```bash
HEADLESS=false mix test test/e2e/path/to/test.exs
```

### Add Debugging Pauses
```elixir
import IEx

test "my test", %{session: session} do
  session
  |> visit("/dashboard")
  |> IO.inspect(label: "After visit")  # Inspect session state

  IEx.pry()  # Pause execution for debugging

  session
  |> click(button("Submit"))
end
```

### Check Screenshots
Failed tests automatically save screenshots to:
```
screenshots/<timestamp>_<test_name>.png
```

## CI/CD Integration

E2E tests run automatically in CI when ChromeDriver is available.

**GitHub Actions Example:**
```yaml
- name: Install ChromeDriver
  run: |
    wget -q https://chromedriver.storage.googleapis.com/$(curl -s https://chromedriver.storage.googleapis.com/LATEST_RELEASE)/chromedriver_linux64.zip
    unzip chromedriver_linux64.zip
    sudo mv chromedriver /usr/local/bin/
    sudo chmod +x /usr/local/bin/chromedriver

- name: Run E2E Tests
  run: mix test --only feature
  env:
    CI: true
```

## Troubleshooting

### ChromeDriver Version Mismatch
Ensure ChromeDriver version matches your Chrome browser version:
```bash
google-chrome --version
chromedriver --version
```

### Port Already in Use
The test server runs on port 4002. If you get port conflicts:
```bash
lsof -ti:4002 | xargs kill -9
```

### Database Locked
If tests hang with database locks:
```bash
rm clientats_test*.db*
mix test --only feature
```

### Session Timeout
Increase timeout in test if needed:
```elixir
config :wallaby,
  hackney_options: [timeout: :infinity, recv_timeout: :infinity]
```

## Additional Resources

- [Wallaby Documentation](https://hexdocs.pm/wallaby/)
- [ChromeDriver Downloads](https://chromedriver.chromium.org/downloads)
- [Phoenix Testing Guide](https://hexdocs.pm/phoenix/testing.html)
