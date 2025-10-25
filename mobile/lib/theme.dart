import 'package:flutter/material.dart';

// Design tokens translated from the provided CSS values.
class AppRadius {
  static const double lg = 12.0; // --radius: 0.75rem
  static const double md = 10.0; // calc(var(--radius) - 2px)
  static const double sm = 8.0;  // calc(var(--radius) - 4px)
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppShadows {
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardShadowDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
}

class AppColors {
  // Light theme colors (hex provided)
  static const Color background = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFF0F7F4);
  static const Color primary = Color(0xFF1D9B57);
  static const Color primaryLight = Color(0xFFE5F4EC);
  static const Color accent = Color(0xFFE5F4EC);
  static const Color destructive = Color(0xFFE63946);
  static const Color foreground = Color(0xFF1A1A1A);
  static const Color muted = Color(0xFFF5F5F5);
  static const Color mutedForeground = Color(0xFF737373);
  static const Color border = Color(0xFFE5E5E5);
  static const Color cardForeground = Color(0xFF1A1A1A);

  // Dark theme colors
  static const Color backgroundDark = Color(0xFF141414);
  static const Color cardDark = Color(0xFF1C2621);
  static const Color primaryLightDark = Color(0xFF263931);
  static const Color destructiveDark = Color(0xFF7A1F1F);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.card,
      primaryColor: AppColors.primary,
      primaryColorLight: AppColors.primaryLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        error: AppColors.destructive,
        surface: AppColors.background,
        background: AppColors.background,
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: AppColors.foreground,
        onSurface: AppColors.foreground,
        onBackground: AppColors.foreground,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF737373)),
        titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
        bodySmall: TextStyle(fontSize: 12.0, color: Color(0xFF737373)),
      ),
      dividerColor: AppColors.border,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      cardColor: AppColors.cardDark,
      primaryColor: AppColors.primary,
      primaryColorLight: AppColors.primaryLightDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLightDark,
        error: AppColors.destructiveDark,
        surface: AppColors.backgroundDark,
        background: AppColors.backgroundDark,
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFFF2F2F2),
        onSurface: Color(0xFFF2F2F2),
        onBackground: Color(0xFFF2F2F2),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFF2F2F2)),
        bodyMedium: TextStyle(color: Color(0xFF999999)),
        titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700, color: Color(0xFFF2F2F2)),
        bodySmall: TextStyle(fontSize: 12.0, color: Color(0xFF999999)),
      ),
      dividerColor: const Color(0xFF333333),
    );
  }
}

// Fade In Animation helper
class FadeInAnimation extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeInAnimation({super.key, required this.child, this.duration = const Duration(milliseconds: 300)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
