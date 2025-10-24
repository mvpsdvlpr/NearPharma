import 'package:flutter/material.dart';

class AppTheme {
  // HSL to Color helper (h: 0-360, s/l: 0-100)
  static Color fromHsl(double h, double s, double l) {
    s /= 100;
    l /= 100;
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - (((h / 60) % 2) - 1).abs());
    final m = l - c / 2;
    double r = 0, g = 0, b = 0;
    if (0 <= h && h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (60 <= h && h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (120 <= h && h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (180 <= h && h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (240 <= h && h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    final R = ((r + m) * 255).round();
    final G = ((g + m) * 255).round();
    final B = ((b + m) * 255).round();
    return Color.fromARGB(255, R.clamp(0, 255), G.clamp(0, 255), B.clamp(0, 255));
  }

  // Design tokens (from provided CSS). Values are H S% L%
  static final Color background = fromHsl(0, 0, 100);
  static final Color foreground = fromHsl(0, 0, 10);
  static final Color card = fromHsl(142, 25, 96);
  static final Color cardForeground = fromHsl(0, 0, 10);
  static final Color primary = fromHsl(142, 76, 36);
  static final Color primaryForeground = fromHsl(0, 0, 100);
  static final Color muted = fromHsl(0, 0, 96);
  static final Color mutedForeground = fromHsl(0, 0, 45);
  static final Color accent = fromHsl(8, 100, 70);
  static final Color destructive = fromHsl(0, 84, 60);

  static final double radius = 12.0; // corresponds to 0.75rem

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    primaryColor: primary,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
    cardColor: card,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        elevation: 0,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: fromHsl(0, 0, 8),
    primaryColor: primary,
    colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark),
    cardColor: fromHsl(142, 15, 12),
  );
}
