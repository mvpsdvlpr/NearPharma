This folder contains the app icon source files and generated assets.ICON ASSETS



Files expected:This folder contains the master icon files used to generate platform launcher icons for the mobile app.

- icon_master.png             (full icon used as fallback/static)

- adaptive_foreground.png     (symbol only, transparent background)Files expected:

- adaptive_background.png     (plain background or subtle texture)- icon_master.png         # full icon (used as fallback/static icon)

- adaptive_foreground.png # symbol only (transparent background) for Android adaptive icons (foreground layer)

Use the script in ../tools/generate_icons.sh to generate common sizes:- adaptive_background.png # simple background (solid color or subtle gradient) for Android adaptive icons (background layer)



  cd mobile/toolsHow to regenerate

  ./generate_icons.sh ../assets/icons/icon_master.png ../assets/icons/generated1. Ensure you have ImageMagick installed (magick CLI).

2. Run from repo root:

After generating, update pubspec.yaml and run flutter_launcher_icons to produce platform icons.   cd mobile

   ../tools/generate_icons.sh
3. Install dev dependency and run the launcher icon generator:
   flutter pub get
   flutter pub run flutter_launcher_icons:main

If ImageMagick isn't available, create the three files manually and place them in this folder.
