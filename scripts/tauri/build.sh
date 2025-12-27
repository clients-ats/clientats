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

# Disable stripping for AppImage to avoid incompatibility with modern Fedora libraries
export NO_STRIP=1

cargo tauri build

cd ..

echo ""
echo "✅ Build complete!"
echo ""

# Collect artifacts into bin/tauri/
echo "📦 Collecting build artifacts..."
BIN_DIR="bin/tauri"
rm -rf "$BIN_DIR"
mkdir -p "$BIN_DIR"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Copy DMG files
    if ls src-tauri/target/release/bundle/dmg/*.dmg 1> /dev/null 2>&1; then
        cp src-tauri/target/release/bundle/dmg/*.dmg "$BIN_DIR/"
        echo "   ✓ Copied DMG installer"
    fi
    # Copy .app bundle (as zip for distribution)
    if ls src-tauri/target/release/bundle/macos/*.app 1> /dev/null 2>&1; then
        for app in src-tauri/target/release/bundle/macos/*.app; do
            app_name=$(basename "$app" .app)
            # Use absolute path to avoid relative path issues
            abs_bin_dir="$(pwd)/$BIN_DIR"
            (cd src-tauri/target/release/bundle/macos && zip -r -q "$abs_bin_dir/${app_name}.app.zip" "$(basename "$app")")
            echo "   ✓ Copied ${app_name}.app.zip"
        done
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Copy AppImage
    if ls src-tauri/target/release/bundle/appimage/*.AppImage 1> /dev/null 2>&1; then
        cp src-tauri/target/release/bundle/appimage/*.AppImage "$BIN_DIR/"
        echo "   ✓ Copied AppImage"
    fi
    # Copy DEB
    if ls src-tauri/target/release/bundle/deb/*.deb 1> /dev/null 2>&1; then
        cp src-tauri/target/release/bundle/deb/*.deb "$BIN_DIR/"
        echo "   ✓ Copied DEB package"
    fi
    # Copy RPM
    if ls src-tauri/target/release/bundle/rpm/*.rpm 1> /dev/null 2>&1; then
        cp src-tauri/target/release/bundle/rpm/*.rpm "$BIN_DIR/"
        echo "   ✓ Copied RPM package"
    fi
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Copy MSI
    if ls src-tauri/target/release/bundle/msi/*.msi 1> /dev/null 2>&1; then
        cp src-tauri/target/release/bundle/msi/*.msi "$BIN_DIR/"
        echo "   ✓ Copied MSI installer"
    fi
    # Copy NSIS
    if ls src-tauri/target/release/bundle/nsis/*.exe 1> /dev/null 2>&1; then
        cp src-tauri/target/release/bundle/nsis/*.exe "$BIN_DIR/"
        echo "   ✓ Copied NSIS installer"
    fi
fi

echo ""
echo "📂 Build artifacts collected in: $BIN_DIR/"
ls -la "$BIN_DIR/"
