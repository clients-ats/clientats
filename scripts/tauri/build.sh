#!/usr/bin/env bash
set -euo pipefail

# Production build script for Tauri desktop app
# Builds a release version for the current platform

echo "🏗️  Building ClientATS Desktop Application"
echo ""

# Check prerequisites
command -v mix >/dev/null 2>&1 || { echo "❌ Elixir/Mix is required but not installed."; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "❌ Rust/Cargo is required but not installed."; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js is required but not installed."; exit 1; }

echo "✅ Prerequisites check passed"
echo ""

# Step 1: Prepare Phoenix release
echo "📦 Step 1/2: Building Phoenix release..."
bash scripts/tauri/prepare-release.sh

# Step 2: Build Tauri app
echo ""
echo "🔨 Step 2/2: Building Tauri application..."
cd src-tauri

if ! command -v cargo-tauri &> /dev/null; then
    echo "📥 Installing Tauri CLI..."
    cargo install tauri-cli --version "^2.0.0" --locked
fi

cargo tauri build

echo ""
echo "✅ Build complete!"
echo ""
echo "📂 Build artifacts:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   • DMG: src-tauri/target/release/bundle/dmg/"
    echo "   • App: src-tauri/target/release/bundle/macos/"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "   • AppImage: src-tauri/target/release/bundle/appimage/"
    echo "   • DEB: src-tauri/target/release/bundle/deb/"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    echo "   • MSI: src-tauri/target/release/bundle/msi/"
    echo "   • NSIS: src-tauri/target/release/bundle/nsis/"
else
    echo "   • Check: src-tauri/target/release/bundle/"
fi
