#!/usr/bin/env python3
"""Generate app icon for Polymnesis: brain/psychology icon on indigo background."""

import cairosvg
from PIL import Image
import io
import os

# Material Design "psychology" icon SVG path (from Google Material Icons, Apache 2.0)
# This is the head-with-gear icon
PSYCHOLOGY_SVG = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="1024" height="1024">
  <path fill="white" d="M13 8.57c-.79 0-1.43.64-1.43 1.43s.64 1.43 1.43 1.43 1.43-.64 1.43-1.43-.64-1.43-1.43-1.43z"/>
  <path fill="white" d="M13 3C9.25 3 6.2 5.94 6.02 9.64L4.1 12.2c-.25.33-.01.8.4.8H6v3c0 1.1.9 2 2 2h1v3h7v-4.68c2.36-1.12 4-3.53 4-6.32 0-3.87-3.13-7-7-7zm3 7l-.74.74-.64-.51c-.29-.23-.66-.08-.66.28v.5l.63.53c.15.12.15.37 0 .49l-.63.53V13c0 .36.37.51.66.28l.64-.51.74.74.74-.74-.64-.51c-.29-.23-.29-.63 0-.86l.64-.51L16 10.15l-.74.74-.64-.51c-.29-.23-.66-.08-.66.28v.08z"/>
</svg>
'''

# Actually, let me use a cleaner, more recognizable brain/psychology SVG
# The official Material Symbols psychology icon path
PSYCHOLOGY_SVG_CLEAN = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="600" height="600">
  <path fill="white" d="M13,8.57C12.21,8.57,11.57,9.21,11.57,10c0,0.79,0.64,1.43,1.43,1.43 s1.43-0.64,1.43-1.43C14.43,9.21,13.79,8.57,13,8.57z"/>
  <path fill="white" d="M13,3C9.25,3,6.2,5.94,6.02,9.64L4.1,12.2c-0.25,0.33-0.01,0.8,0.4,0.8H6v3 c0,1.1,0.9,2,2,2h1v3h7v-4.68c2.36-1.12,4-3.53,4-6.32C20,6.13,16.87,3,13,3z M15.13,14.12L14.5,13.49 c-0.2,0.13-0.42,0.23-0.66,0.28V14.5h-0.9v-0.72c-0.64-0.14-1.17-0.56-1.43-1.14l0.78-0.33c0.18,0.42,0.6,0.72,1.07,0.72 c0.65,0,1.18-0.53,1.18-1.18c0-0.49-0.29-0.9-0.71-1.08V10.5h0.9v0.72c0.24,0.05,0.46,0.15,0.66,0.28l0.63-0.63l0.64,0.64 l-0.63,0.63c0.13,0.2,0.23,0.42,0.28,0.66H17v0.9h-0.72c-0.05,0.24-0.15,0.46-0.28,0.66l0.63,0.63L15.13,14.12z"/>
</svg>
'''

# Let me use a simpler, bolder approach - a brain silhouette that's clearly visible as an icon
BRAIN_SVG = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="600" height="600">
  <!-- Brain left hemisphere -->
  <path fill="white" d="
    M 48 20
    C 38 20, 28 26, 26 36
    C 24 42, 26 48, 22 52
    C 18 56, 18 62, 22 66
    C 24 68, 26 72, 28 76
    C 30 80, 36 82, 42 80
    C 46 78, 48 74, 48 70
    Z
  " opacity="0.95"/>
  <!-- Brain right hemisphere -->
  <path fill="white" d="
    M 52 20
    C 62 20, 72 26, 74 36
    C 76 42, 74 48, 78 52
    C 82 56, 82 62, 78 66
    C 76 68, 74 72, 72 76
    C 70 80, 64 82, 58 80
    C 54 78, 52 74, 52 70
    Z
  " opacity="0.95"/>
  <!-- Brain folds - left -->
  <path fill="none" stroke="#4F46E5" stroke-width="2" stroke-linecap="round" d="
    M 32 36 Q 40 40 36 48
    M 28 50 Q 36 52 34 60
    M 30 62 Q 38 64 36 72
  "/>
  <!-- Brain folds - right -->
  <path fill="none" stroke="#4F46E5" stroke-width="2" stroke-linecap="round" d="
    M 68 36 Q 60 40 64 48
    M 72 50 Q 64 52 66 60
    M 70 62 Q 62 64 64 72
  "/>
  <!-- Center line -->
  <line x1="50" y1="22" x2="50" y2="70" stroke="#4F46E5" stroke-width="2"/>
  <!-- Gear in middle of brain -->
  <circle cx="50" cy="46" r="8" fill="#4F46E5" opacity="0.9"/>
  <circle cx="50" cy="46" r="5" fill="white"/>
  <circle cx="50" cy="46" r="2.5" fill="#4F46E5"/>
  <!-- Gear teeth -->
  <rect x="48" y="36" width="4" height="4" rx="1" fill="#4F46E5"/>
  <rect x="48" y="52" width="4" height="4" rx="1" fill="#4F46E5"/>
  <rect x="40" y="44" width="4" height="4" rx="1" fill="#4F46E5"/>
  <rect x="56" y="44" width="4" height="4" rx="1" fill="#4F46E5"/>
  <!-- Diagonal gear teeth -->
  <rect x="42.5" y="38.5" width="3.5" height="3.5" rx="1" fill="#4F46E5" transform="rotate(45 44.25 40.25)"/>
  <rect x="54" y="38.5" width="3.5" height="3.5" rx="1" fill="#4F46E5" transform="rotate(45 55.75 40.25)"/>
  <rect x="42.5" y="50" width="3.5" height="3.5" rx="1" fill="#4F46E5" transform="rotate(45 44.25 51.75)"/>
  <rect x="54" y="50" width="3.5" height="3.5" rx="1" fill="#4F46E5" transform="rotate(45 55.75 51.75)"/>
  <!-- Brain stem -->
  <path fill="white" d="
    M 46 70 Q 46 85 44 90 L 56 90 Q 54 85 54 70 Z
  "/>
</svg>
'''

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.join(SCRIPT_DIR, "assets", "images")

def generate_foreground():
    """Generate adaptive icon foreground: white icon on transparent background, 1024x1024."""
    png_data = cairosvg.svg2png(bytestring=BRAIN_SVG.encode(), output_width=600, output_height=600)
    icon = Image.open(io.BytesIO(png_data)).convert("RGBA")

    # Create 1024x1024 canvas with transparent background
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    # Center the 600px icon in 1024px canvas (offset = 212)
    offset = (1024 - 600) // 2
    canvas.paste(icon, (offset, offset), icon)

    fg_path = os.path.join(ASSETS_DIR, "app_icon_foreground.png")
    canvas.save(fg_path, "PNG")
    print(f"Saved foreground: {fg_path}")
    return canvas

def generate_full_icon(foreground):
    """Generate full app icon: indigo background + white icon, 1024x1024."""
    bg = Image.new("RGBA", (1024, 1024), (79, 70, 229, 255))  # #4F46E5
    bg.paste(foreground, (0, 0), foreground)

    icon_path = os.path.join(ASSETS_DIR, "app_icon.png")
    bg.save(icon_path, "PNG")
    print(f"Saved full icon: {icon_path}")

if __name__ == "__main__":
    fg = generate_foreground()
    generate_full_icon(fg)
    print("Done! Now run: flutter pub run flutter_launcher_icons")
