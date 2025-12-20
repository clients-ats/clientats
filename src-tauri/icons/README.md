# Application Icons

This directory should contain the application icons for different platforms.

## Required Icons

- `32x32.png` - Small icon (Windows)
- `128x128.png` - Medium icon (macOS, Linux)
- `128x128@2x.png` - Retina icon (macOS)
- `icon.icns` - macOS bundle icon
- `icon.ico` - Windows executable icon

## Generating Icons

You can use tools like:
- [tauri-icon](https://github.com/tauri-apps/tauri-icon) - Official Tauri icon generator
- Online converters like [icoconvert.com](https://icoconvert.com/)

## Quick Start

If you have a source icon (preferably 1024x1024 PNG), you can generate all required icons:

```bash
# Install tauri-icon
cargo install tauri-icon

# Generate icons from source
tauri-icon path/to/your-icon.png
```

For now, the build process will use default Tauri icons if these are not present.
