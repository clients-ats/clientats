#!/bin/bash
set -e

echo "======================================"
echo "Starting Clientats (Development)"
echo "======================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

echo ""
echo "Step 1: Setting up database..."
mix ecto.setup

echo ""
echo "Step 2: Installing dependencies..."
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
