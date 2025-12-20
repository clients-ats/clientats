#!/usr/bin/env bash
set -euo pipefail

# Development script for running Tauri in dev mode
# This starts the Phoenix server separately and then runs Tauri

echo "🚀 Starting ClientATS in development mode..."

# Ensure dependencies are installed (fast if already present)
echo "📦 Ensuring Elixir dependencies are up to date..."
mix deps.get

if [ ! -d "node_modules" ]; then
    echo "📦 Installing Node dependencies..."
    npm install
fi

# Ensure database exists
if [ ! -f "dev.db" ]; then
    echo "🗄️  Creating database..."
    mix ecto.create
    mix ecto.migrate
fi

# Check if Phoenix server is already running
if lsof -Pi :4000 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Phoenix server is already running on port 4000"
    echo "📱 Starting Tauri in dev mode..."
else
    echo "🔧 Starting Phoenix server..."
    # Start Phoenix in the background
    MIX_ENV=dev mix phx.server &
    PHOENIX_PID=$!
    echo "📝 Phoenix PID: $PHOENIX_PID"

    # Wait for Phoenix to be ready
    echo "⏳ Waiting for Phoenix server to start..."
    timeout 30 bash -c 'until nc -z localhost 4000; do sleep 1; done' || {
        echo "❌ Phoenix server failed to start"
        kill $PHOENIX_PID 2>/dev/null || true
        exit 1
    }
    echo "✅ Phoenix server is ready!"
fi

# Start Tauri in dev mode
echo "📱 Starting Tauri dev mode..."
cd src-tauri && cargo tauri dev

# Cleanup Phoenix if we started it
if [ -n "${PHOENIX_PID:-}" ]; then
    echo "🛑 Stopping Phoenix server..."
    kill $PHOENIX_PID 2>/dev/null || true
fi
