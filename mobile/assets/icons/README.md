This folder contains the app icon source files and generated assets.ICON ASSETS
```markdown
# App launcher icon sources

This folder holds the master icon files used to generate platform launcher icons for the mobile app.

Expected files (examples):

- `icon_master.png` — full icon (high-resolution PNG) used as fallback/static icon.
- `adaptive_foreground.png` — symbol only (transparent background) used as Android adaptive icon foreground.
- `adaptive_background.png` — plain background or subtle texture used as Android adaptive icon background.

## Reproducible steps (recommended)

1. Install ImageMagick (the generator script uses the `magick` CLI):

   sudo apt-get install -y imagemagick

2. From the repository root run the Makefile target in `mobile/` (this runs the generator and then `flutter_launcher_icons`):

   cd mobile
   make icons

What `make icons` does:

- Calls `tools/generate_icons.sh` which attempts to create `adaptive_foreground.png` and `adaptive_background.png` from `icon_master.png`.
- Runs `flutter pub run flutter_launcher_icons:main` to generate iOS/Android icons and populate the respective asset catalogs.

## Manual alternative

If you prefer manual steps, run:

1) From repository root:

   mobile/tools/generate_icons.sh ../assets/icons/icon_master.png mobile/assets/icons

2) Then from `mobile/`:

   flutter pub get
   flutter pub run flutter_launcher_icons:main

## Notes

- If ImageMagick isn't available the script falls back to copying the master PNG. That may produce non-ideal foreground/background layers; prefer to run ImageMagick or provide `adaptive_foreground.png` and `adaptive_background.png` manually.
- Keep `icon_master.png` at high resolution (2048×2048 recommended) so generated icons look crisp on high-DPI devices.
- Decide whether to commit generated platform assets or generate them during CI. Both approaches are valid — committing improves reproducibility for local builds; generating in CI keeps repo smaller.

``` 
