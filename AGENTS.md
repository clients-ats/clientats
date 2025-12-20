# Clientats - Job Application Tracker

A comprehensive Phoenix LiveView application for tracking job interests, applications, and communications.

## Project Setup

### Database

The project uses PostgreSQL running in a Podman container:

```bash
# Start the PostgreSQL container
podman run -d --name clientats-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=clientats_dev \
  -p 5432:5432 \
  postgres:16-alpine

# Stop the container
podman stop clientats-db

# Start existing container
podman start clientats-db

# Remove the container (if needed)
podman rm -f clientats-db
```

### Development Commands

```bash
# Install dependencies
mix deps.get

# Create database (first time only)
mix ecto.create

# Run migrations
mix ecto.migrate

# Start the Phoenix server
mix phx.server

# Run in interactive mode
iex -S mix phx.server
```

The application will be available at http://localhost:4000

### Testing

```bash
# Run all tests (excludes feature tests)
mix test

# Run specific test file
mix test test/path/to/test_file.exs

# Run previously failed tests
mix test --failed

# Run with coverage report
mix test --cover

# Run browser-based feature tests (requires ChromeDriver)
# Install: sudo dnf install chromedriver (or appropriate package manager)
mix test --only feature
```

**Browser Testing Setup:**
- Feature tests use Wallaby for browser-based E2E testing
- Requires ChromeDriver to be installed on your system
- Tests are tagged with `@moduletag :feature` and excluded by default
- Run `mix test --only feature` to run browser tests separately

### Code Quality

```bash
# Run all precommit checks (compile, format, test)
mix precommit

# Format code
mix format

# Check compilation warnings
mix compile --warnings-as-errors
```

## Project Structure

- `lib/clientats/` - Business logic and contexts
- `lib/clientats_web/` - Web interface (LiveViews, components, controllers)
- `lib/clientats_web/live/` - LiveView modules
- `priv/repo/migrations/` - Database migrations
- `test/` - Test files

## Tech Stack

- **Framework**: Phoenix 1.8 with LiveView
- **Database**: PostgreSQL 16 (via Podman)
- **CSS**: Tailwind CSS
- **Build**: esbuild
- **Components**: Phoenix Core Components with Heroicons

## Issue Tracking

This project uses **Beads** for issue tracking. AI agents should use the `bd` CLI tool to manage tasks.

### Beads Commands

```bash
# List all issues
bd list

# Show ready-to-work issues
bd ready

# Create a new issue
bd create "Task description" -p [1|2|3] -t task -l label1,label2

# Update issue status
bd update <issue-id> --status [open|in_progress|closed]

# Close an issue
bd close <issue-id> --reason "Reason for closing"

# Show issue details
bd show <issue-id>

# Add dependencies
bd dep add <blocker-id> <blocked-id> --type blocks
```

### Workflow

1. At session start: Run `bd ready` to see available work
2. Before starting work: Update issue to `in_progress`
3. After completing work: Close the issue with `bd close`
4. Issues are stored in `.beads/issues.jsonl` and auto-synced via Git

## Code Conventions

- Use LiveView for interactive pages
- Use streams for collections to avoid memory issues
- Always use `to_form/2` for forms in LiveViews
- Use `<.input>` component from core_components for form inputs
- Follow the existing code style and patterns
- No comments unless code is complex or user requests them

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
