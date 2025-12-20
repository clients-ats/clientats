#!/usr/bin/env bash
set -euo pipefail

# Script to prepare Phoenix release for Tauri bundling
# This should be run before building the Tauri app

echo "🔨 Preparing Phoenix release for Tauri..."

# Clean any existing release
rm -rf src-tauri/phoenix

# Set production environment
export MIX_ENV=prod

# Install dependencies and compile
echo "📦 Installing dependencies..."
mix deps.get --only prod

# Compile assets
echo "🎨 Building assets..."
mix assets.deploy

# Create the release
echo "🚀 Creating Phoenix release..."
mix release --overwrite

# Copy the release to src-tauri directory
echo "📋 Copying release to Tauri resources..."
mkdir -p src-tauri/phoenix
cp -r _build/prod/rel/clientats/* src-tauri/phoenix/

echo "✅ Phoenix release prepared successfully!"
echo "📍 Release location: src-tauri/phoenix"
