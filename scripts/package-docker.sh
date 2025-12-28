#!/bin/bash
set -e

echo "======================================="
echo "Clientats Docker Production Package"
echo "======================================="
echo ""

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Configuration
VERSION=${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo "latest")}
PACKAGE_NAME="clientats-docker-${VERSION}"
BUILD_DIR="build/${PACKAGE_NAME}"
TARBALL="build/${PACKAGE_NAME}.tar.gz"

echo "📦 Building production package: ${PACKAGE_NAME}"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
mkdir -p "${BUILD_DIR}"

# Create multi-stage Dockerfile
echo ""
echo "🐳 Creating Dockerfile..."
cat > "${BUILD_DIR}/Dockerfile" << 'EOF'
# Build stage
FROM elixir:1.17-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm

# Set build ENV
ENV MIX_ENV=prod

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./

# Install mix dependencies
RUN mix deps.get --only prod && \
    mix deps.compile

# Copy application code
COPY config config
COPY lib lib
COPY priv priv
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Runtime stage
FROM alpine:3.21

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    bash

# Install Erlang and Elixir
RUN apk add --no-cache erlang elixir

# Create app user
RUN adduser -D -u 1000 app

# Set working directory
WORKDIR /app

# Copy compiled application from build stage
COPY --from=build --chown=app:app /app/_build/prod /app/_build/prod
COPY --from=build --chown=app:app /app/deps /app/deps
COPY --from=build --chown=app:app /app/config /app/config
COPY --from=build --chown=app:app /app/lib /app/lib
COPY --from=build --chown=app:app /app/priv /app/priv
COPY --from=build --chown=app:app /app/mix.exs /app/mix.lock ./

# Switch to app user
USER app

# Set environment
ENV MIX_ENV=prod \
    PORT=4000

# Expose port
EXPOSE 4000

# Start the application
CMD ["mix", "phx.server"]
EOF

# Create docker-compose.yml
echo ""
echo "🐳 Creating docker-compose.yml..."
cat > "${BUILD_DIR}/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  app:
    build: .
    container_name: clientats-prod-app
    environment:
      DATABASE_PATH: /app/data/clientats.db
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: ${PHX_HOST:-localhost}
      PHX_PORT: ${PHX_PORT:-4001}
      PORT: 4000
    ports:
      - "${PHX_PORT:-4001}:4000"
    volumes:
      - clientats_data:/app/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:4000"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  clientats_data:
EOF

# Create .env.example
echo ""
echo "📝 Creating .env.example..."
cat > "${BUILD_DIR}/.env.example" << 'EOF'
# Production Environment Variables
# Copy this file to .env and update the values

# Secret key base for Phoenix
# Generate with: mix phx.gen.secret
SECRET_KEY_BASE=CHANGE_ME_TO_A_SECURE_SECRET_KEY

# Public hostname
PHX_HOST=localhost

# Public port (must match docker-compose ports mapping)
PHX_PORT=4001
EOF

# Copy necessary files
echo ""
echo "📋 Copying project files..."
cp mix.exs mix.lock "${BUILD_DIR}/"
cp -r config "${BUILD_DIR}/"
cp -r lib "${BUILD_DIR}/"
cp -r priv "${BUILD_DIR}/"
cp -r assets "${BUILD_DIR}/"

# Create .dockerignore
cat > "${BUILD_DIR}/.dockerignore" << 'EOF'
.git
.gitignore
_build
deps
node_modules
build
*.tar.gz
.env
EOF

# Create deployment README
echo ""
echo "📝 Creating README..."
cat > "${BUILD_DIR}/README.md" << 'EOF'
# Clientats Production Deployment (Docker)

This package contains a production-ready Docker build of Clientats using SQLite.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1. **Generate a secret key:**
   ```bash
   docker run --rm elixir:1.17-alpine sh -c "mix local.hex --force && mix phx.gen.secret"
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   # Edit .env and set SECRET_KEY_BASE to the generated secret
   ```

3. **Build and start:**
   ```bash
   docker-compose up -d --build
   ```

4. **Access the application:**
   - Open http://localhost:4001 in your browser
   - Database migrations run automatically on startup

## Management Commands

### View logs
```bash
docker-compose logs -f app
```

### Access console
```bash
docker-compose exec app iex -S mix
```

### Stop the application
```bash
docker-compose down
```

### Stop and remove all data
```bash
docker-compose down -v
```

### Restart the application
```bash
docker-compose restart
```

### Update to a new version
```bash
docker-compose down
# Replace files with new version
docker-compose up -d --build
```

## Configuration

### Ports
The application runs on port 4001 by default (to avoid conflicts with dev).
Change `PHX_PORT` in `.env` to use a different port.

### Database
SQLite database is stored in a Docker volume for persistence.
Data is persisted in a Docker volume named `clientats_data`.

### Backup Database
```bash
# Copy database file from container
docker cp clientats-prod-app:/app/data/clientats.db ./backup_$(date +%Y%m%d_%H%M%S).db
```

### Restore Database
```bash
# Stop the application first
docker-compose down

# Copy backup into volume (start container briefly)
docker-compose up -d
docker cp ./backup.db clientats-prod-app:/app/data/clientats.db
docker-compose restart
```

## Architecture

- **app**: Clientats application (Phoenix/Elixir with embedded SQLite)
- **Volumes**: `clientats_data` for SQLite database persistence

## Troubleshooting

### Application won't start
```bash
docker-compose logs app
```

### Database issues
```bash
# Check database file exists
docker-compose exec app ls -la /app/data/

# Check database integrity
docker-compose exec app sqlite3 /app/data/clientats.db "PRAGMA integrity_check;"
```

### Reset everything
```bash
docker-compose down -v
docker-compose up -d --build
```

### Rebuild without cache
```bash
docker-compose build --no-cache
docker-compose up -d
```
EOF

# Create start script
echo ""
echo "📝 Creating start script..."
cat > "${BUILD_DIR}/start.sh" << 'EOF'
#!/bin/bash
set -e

echo "======================================="
echo "Starting Clientats Production"
echo "======================================="
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo ""
    echo "Please create .env file:"
    echo "  cp .env.example .env"
    echo ""
    echo "Then generate a secret key and add it to .env:"
    echo "  docker run --rm elixir:1.17-alpine sh -c \"mix local.hex --force && mix phx.gen.secret\""
    echo ""
    exit 1
fi

# Check if SECRET_KEY_BASE is set
if grep -q "CHANGE_ME" .env 2>/dev/null; then
    echo "⚠️  Warning: SECRET_KEY_BASE not configured in .env"
    echo ""
    echo "Generate a secret key:"
    echo "  docker run --rm elixir:1.17-alpine sh -c \"mix local.hex --force && mix phx.gen.secret\""
    echo ""
    read -p "Continue anyway? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        exit 1
    fi
fi

echo "🐳 Building and starting containers..."
docker-compose up -d --build

echo ""
echo "⏳ Waiting for application to start..."
sleep 5

echo ""
echo "✅ Clientats is running!"
echo ""
echo "Access the application at: http://localhost:${PHX_PORT:-4001}"
echo ""
echo "Useful commands:"
echo "  docker-compose logs -f app  # View logs"
echo "  docker-compose down          # Stop application"
echo "  docker-compose restart       # Restart application"
echo ""
EOF
chmod +x "${BUILD_DIR}/start.sh"

# Create tarball
echo ""
echo "📦 Creating tarball..."
cd build
tar -czf "${PACKAGE_NAME}.tar.gz" "${PACKAGE_NAME}"
cd ..

# Calculate size
SIZE=$(du -h "${TARBALL}" | cut -f1)

echo ""
echo "======================================="
echo "✅ Production package created!"
echo "======================================="
echo ""
echo "Package: ${TARBALL}"
echo "Size: ${SIZE}"
echo ""
echo "To deploy:"
echo "  1. Copy ${TARBALL} to your server"
echo "  2. Extract: tar -xzf ${PACKAGE_NAME}.tar.gz"
echo "  3. cd ${PACKAGE_NAME}"
echo "  4. ./start.sh"
echo ""
echo "Quick test locally:"
echo "  cd build/${PACKAGE_NAME}"
echo "  ./start.sh"
echo ""
