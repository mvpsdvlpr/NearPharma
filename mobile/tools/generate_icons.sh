#!/usr/bin/env bash
set -euo pipefail

# Simple script to generate common icon sizes from a source icon
# Usage: ./generate_icons.sh source.png output_dir
SRC=${1:-"../assets/icons/icon_master.png"}
OUT=${2:-"../assets/icons/generated"}

mkdir -p "$OUT"
sizes=(1024 512 192 180 120 96 72 48 32)
for s in "${sizes[@]}"; do
  magick "$SRC" -resize ${s}x${s} "$OUT/icon_${s}.png"
done
echo "Generated icons in $OUT"
#!/usr/bin/env bash
set -euo pipefail

# Script to prepare icon assets for Flutter app
# - copies existing pin-pill.png to icons folder as icon_master
# - creates adaptive foreground by making background transparent (needs ImageMagick)
# - creates a solid background PNG

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONS_DIR="$ROOT_DIR/assets/icons"
IMG_DIR="$ROOT_DIR/assets/img"

mkdir -p "$ICONS_DIR"

SRC="$IMG_DIR/pin-pill.png"
if [ ! -f "$SRC" ]; then
  echo "Source image not found: $SRC"
  exit 1
fi

cp "$SRC" "$ICONS_DIR/icon_master.png"
echo "Copied $SRC -> $ICONS_DIR/icon_master.png"

# Create adaptive_foreground by removing a default neutral background (if present)
if command -v magick >/dev/null 2>&1; then
  echo "Using ImageMagick to generate adaptive_foreground.png and adaptive_background.png"
  # Attempt to remove a common neutral background color (#F6F6F6) — tweak if your background differs
  magick "$ICONS_DIR/icon_master.png" -fuzz 6% -transparent "#F6F6F6" "$ICONS_DIR/adaptive_foreground.png" || cp "$ICONS_DIR/icon_master.png" "$ICONS_DIR/adaptive_foreground.png"
  # Create a plain background using primary green
  magick -size 1024x1024 canvas:"#2ECC71" "$ICONS_DIR/adaptive_background.png"
  echo "Generated adaptive_foreground.png and adaptive_background.png in $ICONS_DIR"
else
  echo "ImageMagick (magick) not found. Please install ImageMagick or create the following files manually in $ICONS_DIR:"
  echo " - icon_master.png (copy of assets/img/pin-pill.png)"
  echo " - adaptive_foreground.png (symbol with transparent bg)"
  echo " - adaptive_background.png (plain background PNG)"
fi

echo "Done. Next steps: cd mobile && flutter pub get && flutter pub run flutter_launcher_icons:main"
