#!/bin/bash
set -e

echo "======================================"
echo "Starting Clientats (Development)"
echo "======================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Check if database container is running
echo ""
echo "Step 1: Checking database..."
if podman ps --filter "name=clientats-db" --format "{{.Names}}" | grep -q "clientats-db"; then
    echo "✅ Database container is running"
else
    echo "⚠️  Database container not running. Starting it now..."

    # Check if container exists but is stopped
    if podman ps -a --filter "name=clientats-db" --format "{{.Names}}" | grep -q "clientats-db"; then
        echo "Starting existing database container..."
        podman start clientats-db
    else
        echo "Creating new database container..."
        podman run -d --name clientats-db \
          -e POSTGRES_PASSWORD=postgres \
          -e POSTGRES_USER=postgres \
          -e POSTGRES_DB=clientats_dev \
          -p 5432:5432 \
          postgres:16-alpine
    fi

    echo "Waiting for database to be ready..."
    sleep 3
fi

echo ""
echo "Step 2: Setting up database..."
mix ecto.create 2>/dev/null || echo "Database already exists"
mix ecto.migrate

echo ""
echo "Step 3: Installing dependencies..."
mix deps.get

echo ""
echo "Step 4: Setting up assets..."
mix assets.setup 2>/dev/null || true

echo ""
echo "======================================"
echo "🚀 Starting Phoenix development server"
echo "======================================"
echo ""
echo "Server will be available at: http://localhost:4000"
echo "Press Ctrl+C twice to stop"
echo ""

# Start the Phoenix server
mix phx.server
