# Tauri Desktop Application

ClientATS is available as a standalone desktop application for macOS, Windows, and Linux using Tauri.

## Architecture

The desktop app uses a **hybrid architecture**:
- **Phoenix LiveView** server running embedded within the app
- **Tauri WebView** displaying the UI and connecting to the local server
- **SQLite database** stored in the user's application data directory
- **Fully self-contained** - no external dependencies required

This is NOT a static web app - Phoenix runs as a complete server inside the desktop application.

## Downloading Pre-built Applications

### From GitHub Actions (Development Builds)

For every push to `main`, `develop`, or any pull request, GitHub Actions automatically builds the application for all platforms.

**To download artifacts:**

1. Go to the [GitHub Actions tab](../../actions)
2. Click on the latest "Tauri Build" workflow run
3. Scroll down to the "Artifacts" section
4. Download the artifact for your platform:
   - **macOS**: `clientats-macos` (contains `.dmg` file)
   - **Windows**: `clientats-windows` (contains `.msi` installer)
   - **Linux**: `clientats-linux` (contains `.AppImage` and `.deb` files)

**Note**: Artifacts are kept for 30 days and are available for all pull requests and commits.

### From GitHub Releases (Stable Releases)

For tagged releases, pre-built binaries are automatically published to GitHub Releases:

1. Go to the [Releases page](../../releases)
2. Download the appropriate file for your platform:
   - **macOS**: `.dmg` file
   - **Windows**: `.msi` installer
   - **Linux**: `.AppImage` or `.deb` package

## Installation

### macOS
1. Download the `.dmg` file
2. Open it and drag ClientATS to your Applications folder
3. On first launch, you may need to right-click and select "Open" to bypass Gatekeeper

### Windows
1. Download the `.msi` installer
2. Double-click to run the installer
3. Follow the installation wizard

### Linux

**AppImage** (Universal):
```bash
chmod +x clientats_*.AppImage
./clientats_*.AppImage
```

**Debian/Ubuntu** (.deb):
```bash
sudo dpkg -i clientats_*.deb
```

## Building Locally

### Prerequisites

- **Elixir** 1.15+ and **Erlang/OTP** 26+
- **Rust** (latest stable)
- **Node.js** 20+
- Platform-specific dependencies:
  - **macOS**: Xcode Command Line Tools
  - **Linux**: `libwebkit2gtk-4.1-dev`, `libappindicator3-dev`, `librsvg2-dev`, `patchelf`
  - **Windows**: Windows 10 SDK

### Build Steps

1. **Prepare the Phoenix release**:
   ```bash
   bash scripts/tauri/prepare-release.sh
   ```

2. **Build the Tauri application**:
   ```bash
   cd src-tauri
   cargo tauri build
   ```

3. **Find your build**:
   - **macOS**: `src-tauri/target/release/bundle/dmg/`
   - **Windows**: `src-tauri/target/release/bundle/msi/`
   - **Linux**: `src-tauri/target/release/bundle/appimage/` or `deb/`

### Development Mode

To run the app in development mode with hot-reload:

```bash
bash scripts/tauri/dev.sh
```

Or manually:
```bash
# Terminal 1: Start Phoenix
mix phx.server

# Terminal 2: Start Tauri dev mode
cd src-tauri
cargo tauri dev
```

## Data Storage

The desktop app stores all data locally:

- **Database**: Stored in the user's application data directory
  - **macOS**: `~/Library/Application Support/com.clientats.app/clientats.db`
  - **Windows**: `%APPDATA%/com.clientats.app/clientats.db`
  - **Linux**: `~/.local/share/com.clientats.app/clientats.db`

- **Configuration**: Environment variables are auto-generated for desktop use
  - `SECRET_KEY_BASE`: Generated per machine
  - `LLM_ENCRYPTION_KEY`: Generated per machine
  - LLM API keys: Configure through the app's settings UI

## Configuration

### LLM Providers

Configure your LLM providers through the app's settings UI or via environment variables:

```bash
# Optional: Set via environment before launching
export GEMINI_API_KEY="your-key"
export OPENAI_API_KEY="your-key"
export OLLAMA_BASE_URL="http://localhost:11434"
```

### Custom Port

By default, the app runs on port 4000. To use a different port:

```bash
PORT=5000 ./clientats.app
```

## Troubleshooting

### App won't start

**Check the logs**:
- **macOS**: `~/Library/Logs/com.clientats.app/`
- **Windows**: Check Event Viewer
- **Linux**: Run from terminal to see output

**Common issues**:
- Port 4000 already in use: Close other apps using that port or set `PORT` environment variable
- Database locked: Close any other instances of the app
- Permissions: Ensure the app has permission to write to the data directory

### Database migrations failed

The app automatically runs migrations on startup. If this fails:

1. Locate your database file (see Data Storage section)
2. Backup and delete it
3. Restart the app (it will create a fresh database)

### "Malicious software" warning (macOS)

The app isn't code-signed. To open:
1. Right-click the app
2. Select "Open"
3. Click "Open" in the dialog

## Development Tips

### Clean Build

To completely clean the build:

```bash
# Clean Phoenix build
rm -rf _build/prod
rm -rf src-tauri/phoenix

# Clean Tauri build
cd src-tauri
cargo clean
```

### Building Universal Binary (macOS)

The GitHub Actions workflow automatically builds universal binaries (Intel + Apple Silicon).

For local universal builds:
```bash
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cd src-tauri
cargo tauri build --target universal-apple-darwin
```

### Updating Tauri Version

```bash
cd src-tauri
cargo update tauri
cargo update tauri-build
```

## Architecture Details

### Startup Sequence

1. Tauri app launches
2. Database directory created in app data folder
3. **Migrations run** (synchronously - blocks until complete)
4. **Phoenix server starts** (as a child process)
5. **Port checking** waits for server to be ready (max 30 seconds)
6. **WebView window opens** and loads the Phoenix UI

### Why Not Static Files?

Phoenix LiveView requires a running server for:
- Real-time WebSocket connections
- Server-side rendering
- Database queries
- Background jobs (Oban)

A static file approach wouldn't support these features.

## Contributing

When adding new features that affect the desktop app:

1. Test in development mode: `bash scripts/tauri/dev.sh`
2. Test a production build locally
3. Ensure GitHub Actions builds pass
4. Update this documentation if needed

## References

- [Tauri Documentation](https://tauri.app/)
- [Phoenix Releases](https://hexdocs.pm/phoenix/releases.html)
- [Lessons Learned](https://github.com/jsight/taurihelloworld/blob/main/todo_app/TAURI_BUILDING_TIPS.md)
