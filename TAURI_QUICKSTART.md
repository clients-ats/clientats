# Tauri Desktop App - Quick Start

## For Users: Download & Install

### Option 1: Download from GitHub Actions (Latest Builds)

Every commit and PR automatically builds desktop apps for all platforms!

1. Go to: https://github.com/clients-ats/clientats/actions
2. Click the latest **"Tauri Build"** workflow
3. Scroll to **Artifacts** section
4. Download your platform:
   - `clientats-macos` → macOS
   - `clientats-windows` → Windows
   - `clientats-linux` → Linux

**Artifacts expire after 30 days**

### Option 2: Download from Releases (Stable)

For tagged releases only:

1. Go to: https://github.com/clients-ats/clientats/releases
2. Download the latest release for your platform

## For Developers

### Quick Build (Local)

```bash
# One-command build
bash scripts/tauri/build.sh
```

### Development Mode

```bash
# Run with hot-reload
bash scripts/tauri/dev.sh
```

### Manual Steps

```bash
# 1. Build Phoenix release
bash scripts/tauri/prepare-release.sh

# 2. Build Tauri app
cd src-tauri
cargo tauri build
```

## Project Structure

```
clientats/
├── src-tauri/              # Tauri application
│   ├── src/
│   │   └── main.rs        # Rust app entry point
│   ├── Cargo.toml         # Rust dependencies
│   ├── tauri.conf.json    # Tauri configuration
│   ├── icons/             # App icons (platform-specific)
│   └── phoenix/           # Phoenix release (generated)
├── scripts/tauri/
│   ├── prepare-release.sh # Build Phoenix release
│   ├── build.sh           # Complete build script
│   └── dev.sh             # Development mode
└── docs/TAURI.md          # Full documentation
```

## Key Commands

| Command | Description |
|---------|-------------|
| `scripts/tauri/dev.sh` | Run in development mode |
| `scripts/tauri/build.sh` | Build production app |
| `scripts/tauri/prepare-release.sh` | Build Phoenix only |
| `cargo tauri build` | Build Tauri (requires Phoenix) |
| `cargo tauri dev` | Tauri dev mode (requires Phoenix running) |

## Architecture Overview

```
┌─────────────────────────────────────┐
│     Tauri Desktop Application       │
│  ┌───────────────────────────────┐  │
│  │   WebView (UI Layer)          │  │
│  │   - Phoenix LiveView          │  │
│  │   - WebSocket connection      │  │
│  └───────────────────────────────┘  │
│              ↕                       │
│  ┌───────────────────────────────┐  │
│  │   Phoenix Server              │  │
│  │   - Embedded in app           │  │
│  │   - Runs on localhost:4000    │  │
│  │   - Auto-starts with app      │  │
│  └───────────────────────────────┘  │
│              ↕                       │
│  ┌───────────────────────────────┐  │
│  │   SQLite Database             │  │
│  │   - User's app data folder    │  │
│  │   - Auto-migrations           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Startup Process

1. **Tauri launches** (Rust app starts)
2. **Database prepared** (in user's home directory)
3. **Migrations run** (synchronously)
4. **Phoenix starts** (embedded server on port 4000)
5. **Port check waits** (up to 30 seconds)
6. **Window opens** (WebView loads Phoenix UI)

## Data Location

Your data is stored locally:

- **macOS**: `~/Library/Application Support/com.clientats.app/`
- **Windows**: `%APPDATA%/com.clientats.app/`
- **Linux**: `~/.local/share/com.clientats.app/`

## GitHub Actions

The workflow (`.github/workflows/tauri-build.yml`) automatically:

- ✅ Builds for **macOS** (universal binary: Intel + M1/M2/M3)
- ✅ Builds for **Windows** (MSI + NSIS installers)
- ✅ Builds for **Linux** (AppImage + DEB packages)
- ✅ Runs on every **push** and **pull request**
- ✅ Creates **GitHub Releases** for tags
- ✅ Uploads **downloadable artifacts** (30-day retention)

## Common Issues

**App won't start?**
- Check port 4000 isn't in use: `lsof -i :4000`
- Check logs (see docs/TAURI.md for log locations)

**Build fails?**
- Clean: `rm -rf _build/prod src-tauri/target src-tauri/phoenix`
- Try again: `bash scripts/tauri/build.sh`

**"Asset not found" error?**
- Don't use `frontendDist` in tauri.conf.json
- Use `devUrl: "http://localhost:4000"` instead

## Next Steps

📖 **Full Documentation**: [docs/TAURI.md](docs/TAURI.md)

🔧 **Tauri Best Practices**: See the [lessons learned](https://github.com/jsight/taurihelloworld/blob/main/todo_app/TAURI_BUILDING_TIPS.md) from previous Tauri projects

🚀 **Phoenix Releases**: https://hexdocs.pm/phoenix/releases.html
