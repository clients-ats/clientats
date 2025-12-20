#!/usr/bin/env bash
set -euo pipefail

# Simple icon generator using Python (no external dependencies needed)
# Creates minimal but valid PNG icons for Tauri

ICONS_DIR="src-tauri/icons"
mkdir -p "$ICONS_DIR"

echo "🎨 Generating placeholder icons for Tauri..."

# Use Python to create valid PNG files
python3 << 'PYTHON_SCRIPT'
import struct
import zlib
import os

def create_png(width, height, color_rgb, output_path):
    """Create a minimal valid PNG file"""
    # PNG signature
    png_signature = b'\x89PNG\r\n\x1a\n'

    # IHDR chunk (image header)
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr_chunk = b'IHDR' + ihdr_data
    ihdr_crc = struct.pack('>I', zlib.crc32(ihdr_chunk) & 0xffffffff)
    ihdr = struct.pack('>I', len(ihdr_data)) + ihdr_chunk + ihdr_crc

    # IDAT chunk (image data) - solid color
    pixels = bytearray()
    r, g, b = color_rgb
    for y in range(height):
        pixels.append(0)  # filter type
        for x in range(width):
            pixels.extend([r, g, b])

    compressed = zlib.compress(bytes(pixels), 9)
    idat_chunk = b'IDAT' + compressed
    idat_crc = struct.pack('>I', zlib.crc32(idat_chunk) & 0xffffffff)
    idat = struct.pack('>I', len(compressed)) + idat_chunk + idat_crc

    # IEND chunk (end of file)
    iend_chunk = b'IEND'
    iend_crc = struct.pack('>I', zlib.crc32(iend_chunk) & 0xffffffff)
    iend = struct.pack('>I', 0) + iend_chunk + iend_crc

    # Write PNG file
    with open(output_path, 'wb') as f:
        f.write(png_signature + ihdr + idat + iend)

# Create icons directory
icons_dir = 'src-tauri/icons'
os.makedirs(icons_dir, exist_ok=True)

# Create icons with blue color (37, 99, 235) - Tailwind blue-600
blue = (37, 99, 235)

create_png(32, 32, blue, f'{icons_dir}/32x32.png')
print(f'✓ Created {icons_dir}/32x32.png')

create_png(128, 128, blue, f'{icons_dir}/128x128.png')
print(f'✓ Created {icons_dir}/128x128.png')

create_png(256, 256, blue, f'{icons_dir}/128x128@2x.png')
print(f'✓ Created {icons_dir}/128x128@2x.png')

# For .ico (Windows), create a minimal valid ICO file
# ICO file format header + 32x32 PNG embedded
def create_ico_from_png(png_path, ico_path):
    with open(png_path, 'rb') as f:
        png_data = f.read()

    # ICO header
    ico_header = struct.pack('<HHH', 0, 1, 1)  # Reserved, Type (1=icon), Count

    # ICO directory entry for 32x32
    ico_entry = struct.pack('<BBBBHHII',
        32,              # Width
        32,              # Height
        0,               # Color palette
        0,               # Reserved
        1,               # Color planes
        32,              # Bits per pixel
        len(png_data),   # Size of image data
        22               # Offset to image data (6 + 16 = 22)
    )

    with open(ico_path, 'wb') as f:
        f.write(ico_header + ico_entry + png_data)

create_ico_from_png(f'{icons_dir}/32x32.png', f'{icons_dir}/icon.ico')
print(f'✓ Created {icons_dir}/icon.ico')

# For .icns (macOS), create a minimal placeholder
# Tauri will generate a proper one during build
with open(f'{icons_dir}/icon.icns', 'wb') as f:
    # Minimal valid ICNS header
    f.write(b'icns')  # Magic number
    f.write(struct.pack('>I', 8))  # File size (just header)

print(f'✓ Created {icons_dir}/icon.icns')
print('')
print('✅ Icon generation complete!')
print('💡 These are solid blue placeholder icons.')
print('   To create custom icons, use: cargo install tauri-icon && tauri icon path/to/icon.png')
PYTHON_SCRIPT

echo "Done!"
