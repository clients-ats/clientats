# Clientats Scripts

This directory contains utility scripts for building, testing, and running the Clientats application.

## Available Scripts

### 🚀 Development

#### `start-dev.sh`
Start the application in development mode with hot-reloading.

```bash
./scripts/start-dev.sh
```

**What it does:**
- Checks and starts the PostgreSQL database container
- Creates and migrates the database
- Installs dependencies
- Sets up assets
- Starts Phoenix server on http://localhost:4000

---

### 🏗️ Production

#### `build-prod.sh`
Build a production release of the application.

```bash
./scripts/build-prod.sh
```

**What it does:**
- Installs production dependencies
- Compiles the application
- Builds and minifies assets
- Creates a production release in `_build/prod/rel/clientats`

#### `start-prod.sh`
Start the production release.

```bash
./scripts/start-prod.sh
```

**Prerequisites:** Run `build-prod.sh` first

#### `package-prod.sh`
Build a complete production package with Docker deployment.

```bash
./scripts/package-prod.sh
```

**What it does:**
- Builds production release
- Creates Dockerfile for containerization
- Generates docker-compose.yml (runs on port 4001, postgres on 5433)
- Includes deployment scripts and documentation
- Packages everything into a `.tar.gz` file in `build/` directory

**Output:** `build/clientats-prod-{version}.tar.gz`

**Deployment:**
```bash
# Extract package
tar -xzf clientats-prod-{version}.tar.gz
cd clientats-prod-{version}

# Generate secret key
docker run --rm elixir:1.17-alpine sh -c "mix local.hex --force && mix phx.gen.secret"

# Configure environment
cp .env.example .env
# Edit .env and set SECRET_KEY_BASE

# Start application
./start.sh
```

**Features:**
- Isolated from dev environment (different ports and containers)
- Complete Docker-based deployment
- Database migrations included
- Health checks configured
- Persistent data volumes

---

### 🧪 Testing

#### `test.sh`
Run the test suite with various options.

```bash
# Run all unit and integration tests
./scripts/test.sh

# Run tests with coverage report
./scripts/test.sh --coverage

# Run browser-based feature tests (requires ChromeDriver)
./scripts/test.sh --feature

# Run full precommit checks (compile, format, test)
./scripts/test.sh --precommit
```

**Options:**
- `-c, --coverage` - Generate code coverage report
- `-f, --feature` - Run browser-based E2E tests
- `-p, --precommit` - Run all precommit checks
- `-h, --help` - Show help message

---

### 🗄️ Database Management

#### `db.sh`
Manage the PostgreSQL database container and migrations.

```bash
# Start database container
./scripts/db.sh start

# Stop database container
./scripts/db.sh stop

# Restart database container
./scripts/db.sh restart

# Show database status
./scripts/db.sh status

# Run migrations
./scripts/db.sh migrate

# Rollback last migration
./scripts/db.sh rollback

# Reset database (deletes all data!)
./scripts/db.sh reset

# Show database logs
./scripts/db.sh logs

# Remove database container
./scripts/db.sh remove
```

---

## Quick Start Guide

### First Time Setup

1. **Start development server:**
   ```bash
   ./scripts/start-dev.sh
   ```
   This will automatically set up everything you need!

2. **Run tests:**
   ```bash
   ./scripts/test.sh --coverage
   ```

### Daily Development Workflow

```bash
# Start your dev environment
./scripts/start-dev.sh

# In another terminal, run tests as you code
./scripts/test.sh

# Before committing, run precommit checks
./scripts/test.sh --precommit
```

### Production Deployment

```bash
# Build production release
./scripts/build-prod.sh

# Start production server
./scripts/start-prod.sh
```

---

## Database Management Examples

```bash
# Check if database is running
./scripts/db.sh status

# View database logs
./scripts/db.sh logs

# Reset database to clean slate (careful!)
./scripts/db.sh reset

# Run new migrations
./scripts/db.sh migrate
```

---

## Troubleshooting

### Database Won't Start
```bash
# Check container status
./scripts/db.sh status

# Try restarting
./scripts/db.sh restart

# If all else fails, remove and recreate
./scripts/db.sh remove
./scripts/db.sh start
```

### Port Already in Use
If port 4000 or 5432 is already in use:
```bash
# Find what's using the port
lsof -i :4000  # or :5432

# Stop the conflicting process or change the port in config
```

### Asset Build Failures
```bash
# Clean and rebuild
rm -rf deps _build node_modules assets/node_modules
./scripts/start-dev.sh
```

---

## CI/CD Integration

These scripts are designed to work in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run tests with coverage
  run: ./scripts/test.sh --coverage

- name: Build production
  run: ./scripts/build-prod.sh
```

---

## Environment Variables

You can customize behavior with environment variables:

- `MIX_ENV` - Set environment (dev/test/prod)
- `DATABASE_URL` - Override database connection
- `PORT` - Override web server port
- `SECRET_KEY_BASE` - Set secret key for production

Example:
```bash
PORT=5000 ./scripts/start-dev.sh
```
