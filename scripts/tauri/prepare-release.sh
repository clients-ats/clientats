#!/usr/bin/env bash
set -euo pipefail

# Script to prepare Phoenix release for Tauri bundling
# This should be run before building the Tauri app

echo "🔨 Preparing Phoenix release for Tauri..."

# Set production environment
export MIX_ENV=prod

# Install dependencies and compile
echo "📦 Installing dependencies..."
mix deps.get --only prod

# Compile the application first (generates phoenix-colocated hooks)
echo "⚙️ Compiling application..."
mix compile

# Compile assets (needs phoenix-colocated hooks to be generated first)
echo "🎨 Building assets..."
mix assets.deploy

# Create the release
echo "🚀 Creating Phoenix release..."
mix release --overwrite

# Copy the release to src-tauri directory (force overwrite on Windows)
echo "📋 Copying release to Tauri resources..."
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
  # Windows: Remove directory with PowerShell if it exists, then copy
  if [ -d "src-tauri/phoenix" ]; then
    echo "🗑️  Removing existing release (Windows)..."
    powershell.exe -Command "if (Test-Path 'src-tauri/phoenix') { Remove-Item -Path 'src-tauri/phoenix' -Recurse -Force -ErrorAction SilentlyContinue }"
  fi
  mkdir -p src-tauri/phoenix
  cp -r _build/prod/rel/clientats/* src-tauri/phoenix/
else
  # Unix/macOS: Standard rm and copy
  rm -rf src-tauri/phoenix
  mkdir -p src-tauri/phoenix
  cp -r _build/prod/rel/clientats/* src-tauri/phoenix/
fi

echo "✅ Phoenix release prepared successfully!"
echo "📍 Release location: src-tauri/phoenix"
