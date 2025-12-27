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

# Copy the release to src-tauri directory
echo "📋 Copying release to Tauri resources..."

# Remove existing directory first
if [ -d "src-tauri/phoenix" ]; then
  echo "🗑️  Removing existing release..."
  if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${WINDIR:-}" ]]; then
    # Windows: Use PowerShell for reliable removal
    powershell.exe -Command "Remove-Item -Path 'src-tauri/phoenix' -Recurse -Force -ErrorAction SilentlyContinue"
  else
    rm -rf src-tauri/phoenix
  fi
fi

mkdir -p src-tauri/phoenix

# Copy files
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "${WINDIR:-}" ]]; then
  # Windows: Use PowerShell for reliable copy
  powershell.exe -Command "Copy-Item -Path '_build/prod/rel/clientats/*' -Destination 'src-tauri/phoenix/' -Recurse -Force"
else
  cp -rf _build/prod/rel/clientats/* src-tauri/phoenix/
fi

# Fix permissions and remove macOS extended attributes
echo "🔧 Fixing file permissions and attributes..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: Remove extended attributes and fix permissions
  chmod -R u+w src-tauri/phoenix
  xattr -cr src-tauri/phoenix 2>/dev/null || true
elif [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "win32" ]] && [[ "$OSTYPE" != "cygwin" ]]; then
  # Linux/Other Unix: Just fix permissions
  chmod -R u+w src-tauri/phoenix
fi

echo "✅ Phoenix release prepared successfully!"
echo "📍 Release location: src-tauri/phoenix"
