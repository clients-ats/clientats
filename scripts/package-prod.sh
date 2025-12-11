#!/bin/bash
set -e

echo "======================================="
echo "Clientats Production Package Builder"
echo "======================================="
echo ""

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Configuration
VERSION=${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || echo "latest")}
PACKAGE_NAME="clientats-prod-${VERSION}"
BUILD_DIR="build/${PACKAGE_NAME}"
TARBALL="build/${PACKAGE_NAME}.tar.gz"

echo "📦 Building production package: ${PACKAGE_NAME}"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
mkdir -p "${BUILD_DIR}"

# Copy source files for Docker build
echo ""
echo "📋 Copying project files..."
cp mix.exs mix.lock "${BUILD_DIR}/"
cp -r config "${BUILD_DIR}/"
cp -r lib "${BUILD_DIR}/"
cp -r priv "${BUILD_DIR}/"
cp -r assets "${BUILD_DIR}/"

# Create .dockerignore
cat > "${BUILD_DIR}/.dockerignore" << 'EOF'
Dockerfile
docker-compose.yml
.env
.env.example
README.md
start.sh
migrate.sh
*.tar.gz
_build
deps
node_modules
.git
EOF

# Create Dockerfile
echo ""
echo "🐳 Creating Dockerfile..."
cat > "${BUILD_DIR}/Dockerfile" << 'EOF'
# Build stage
FROM elixir:1.17-alpine AS build

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Set build ENV
ENV MIX_ENV=prod

# Prepare build dir
WORKDIR /app

# Install hex + rebar (skip rebar if download fails - will install from deps if needed)
RUN mix local.hex --force && \
    (mix local.rebar --force || echo "Rebar will be installed from dependencies if needed")

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

# Compile the application first (generates phoenix-colocated hooks)
RUN mix compile

# Compile assets (needs phoenix-colocated hooks to be generated first)
RUN mix assets.deploy

# Runtime stage
FROM elixir:1.17-alpine

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    bash \
    wget \
    git

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

# Install hex for app user (needed for mix commands)
RUN mix local.hex --force

# Set environment
ENV MIX_ENV=prod \
    PORT=4000

# Expose port
EXPOSE 4000

# Start the application
CMD ["mix", "phx.server"]
EOF

# Create docker-compose.yml (works with podman-compose)
echo ""
echo "🐳 Creating docker-compose.yml..."
cat > "${BUILD_DIR}/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    container_name: clientats-prod-db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: clientats_prod
    volumes:
      - clientats_prod_data:/var/lib/postgresql/data
    ports:
      - "6433:5432"
    networks:
      - clientats-prod
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build: .
    container_name: clientats-prod-app
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: ecto://postgres:postgres@db:5432/clientats_prod
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      PHX_HOST: ${PHX_HOST:-localhost}
      PHX_PORT: ${PHX_PORT:-4001}
      PORT: 4000
    ports:
      - "${PHX_PORT:-4001}:4000"
    networks:
      - clientats-prod
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:4000"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  clientats_prod_data:

networks:
  clientats-prod:
    driver: bridge
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

# Public port (must match podman-compose ports mapping)
PHX_PORT=4001
EOF

# Create deployment README
echo ""
echo "📝 Creating README..."
cat > "${BUILD_DIR}/README.md" << 'EOF'
# Clientats Production Deployment

This package contains a production-ready build of Clientats.

## Prerequisites

- Podman (or Docker)
- podman-compose (or docker-compose)

## Quick Start

1. **Generate a secret key:**
   ```bash
   podman run --rm elixir:1.17-alpine sh -c "mix local.hex --force && mix phx.gen.secret"
   ```

2. **Create environment file:**
   ```bash
   cp .env.example .env
   # Edit .env and set SECRET_KEY_BASE to the generated secret
   ```

3. **Build and start:**
   ```bash
   podman-compose up -d --build
   ```

4. **Run migrations:**
   ```bash
   podman-compose exec app mix ecto.migrate
   ```

5. **Access the application:**
   - Open http://localhost:4001 in your browser

## Management Commands

### View logs
```bash
podman-compose logs -f
```

### Stop the application
```bash
podman-compose down
```

### Stop and remove all data
```bash
podman-compose down -v
```

### Restart the application
```bash
podman-compose restart
```

### Update to a new version
```bash
podman-compose down
# Replace files with new version
podman-compose up -d --build
podman-compose exec app mix ecto.migrate
```

## Configuration

### Ports
The application runs on port 4001 by default (to avoid conflicts with dev).
Change `PHX_PORT` in `.env` to use a different port.

### Database
PostgreSQL runs on port 6433 (to avoid conflicts with dev).
Data is persisted in a Docker volume named `clientats_prod_data`.

### Backup Database
```bash
podman-compose exec db pg_dump -U postgres clientats_prod > backup.sql
```

### Restore Database
```bash
cat backup.sql | podman-compose exec -T db psql -U postgres clientats_prod
```

## Architecture

- **app**: Clientats application (Phoenix/Elixir)
- **db**: PostgreSQL 16 database
- **Network**: Isolated `clientats-prod` network
- **Volumes**: `clientats_prod_data` for database persistence

## Troubleshooting

### Application won't start
```bash
podman-compose logs app
```

### Database connection issues
```bash
podman-compose exec db psql -U postgres -c "SELECT 1"
```

### Reset everything
```bash
podman-compose down -v
rm -rf clientats_prod_data
podman-compose up -d --build
```
EOF

# Create migration helper script
echo ""
echo "📝 Creating migration helper..."
cat > "${BUILD_DIR}/migrate.sh" << 'EOF'
#!/bin/bash
# Run database migrations
podman-compose exec app mix ecto.migrate
EOF
chmod +x "${BUILD_DIR}/migrate.sh"

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
    echo "  podman run --rm elixir:1.17-alpine sh -c \"mix local.hex --force && mix phx.gen.secret\""
    echo ""
    exit 1
fi

# Check if SECRET_KEY_BASE is set
if grep -q "CHANGE_ME" .env 2>/dev/null; then
    echo "⚠️  Warning: SECRET_KEY_BASE not configured in .env"
    echo ""
    echo "Generate a secret key:"
    echo "  podman run --rm elixir:1.17-alpine sh -c \"mix local.hex --force && mix phx.gen.secret\""
    echo ""
    read -p "Continue anyway? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        exit 1
    fi
fi

echo "🐳 Building and starting containers..."
podman-compose up -d --build

echo ""
echo "⏳ Waiting for database to be ready..."
sleep 5

echo ""
echo "🔄 Running migrations..."
./migrate.sh

echo ""
echo "✅ Clientats is running!"
echo ""
echo "Access the application at: http://localhost:${PHX_PORT:-4001}"
echo ""
echo "Useful commands:"
echo "  podman-compose logs -f      # View logs"
echo "  podman-compose down         # Stop application"
echo "  podman-compose restart      # Restart application"
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
echo "  4. Follow instructions in README.md"
echo ""
echo "Quick start:"
echo "  cd build/${PACKAGE_NAME}"
echo "  ./start.sh"
echo ""
