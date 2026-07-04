import 'package:flutter/material.dart';

/// Application Theme Configuration
/// Supports instant system-tied Light/Dark mode switching
class AppTheme {
  // Light Theme Colors
  static const Color _lightPrimary = Color(0xFF6750A4);
  static const Color _lightOnPrimary = Color(0xFFFFFFFF);
  static const Color _lightPrimaryContainer = Color(0xFFEADDFF);
  static const Color _lightOnPrimaryContainer = Color(0xFF21005D);
  static const Color _lightSecondary = Color(0xFF625B71);
  static const Color _lightOnSecondary = Color(0xFFFFFFFF);
  static const Color _lightSecondaryContainer = Color(0xFFE8DEF8);
  static const Color _lightOnSecondaryContainer = Color(0xFF1D192B);
  static const Color _lightTertiary = Color(0xFF7D5260);
  static const Color _lightOnTertiary = Color(0xFFFFFFFF);
  static const Color _lightTertiaryContainer = Color(0xFFFFD8E4);
  static const Color _lightOnTertiaryContainer = Color(0xFF31111D);
  static const Color _lightError = Color(0xFFB3261E);
  static const Color _lightOnError = Color(0xFFFFFFFF);
  static const Color _lightErrorContainer = Color(0xFFF9DEDC);
  static const Color _lightOnErrorContainer = Color(0xFF410E0B);
  static const Color _lightBackground = Color(0xFFFFFBFE);
  static const Color _lightOnBackground = Color(0xFF1C1B1F);
  static const Color _lightSurface = Color(0xFFFFFBFE);
  static const Color _lightOnSurface = Color(0xFF1C1B1F);
  static const Color _lightOutline = Color(0xFF79747E);

  // Dark Theme Colors
  static const Color _darkPrimary = Color(0xFFD0BCFF);
  static const Color _darkOnPrimary = Color(0xFF381E72);
  static const Color _darkPrimaryContainer = Color(0xFF4F378B);
  static const Color _darkOnPrimaryContainer = Color(0xFFEADDFF);
  static const Color _darkSecondary = Color(0xFFCCC2DC);
  static const Color _darkOnSecondary = Color(0xFF332D41);
  static const Color _darkSecondaryContainer = Color(0xFF4A4458);
  static const Color _darkOnSecondaryContainer = Color(0xFFE8DEF8);
  static const Color _darkTertiary = Color(0xFFEFB8C8);
  static const Color _darkOnTertiary = Color(0xFF492532);
  static const Color _darkTertiaryContainer = Color(0xFF633B48);
  static const Color _darkOnTertiaryContainer = Color(0xFFFFD8E4);
  static const Color _darkError = Color(0xFFF2B8B5);
  static const Color _darkOnError = Color(0xFF601410);
  static const Color _darkErrorContainer = Color(0xFF8C1D18);
  static const Color _darkOnErrorContainer = Color(0xFFF9DEDC);
  static const Color _darkBackground = Color(0xFF1C1B1F);
  static const Color _darkOnBackground = Color(0xFFE6E1E5);
  static const Color _darkSurface = Color(0xFF1C1B1F);
  static const Color _darkOnSurface = Color(0xFFE6E1E5);
  static const Color _darkOutline = Color(0xFF938F99);

  /// Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: _lightPrimary,
        onPrimary: _lightOnPrimary,
        primaryContainer: _lightPrimaryContainer,
        onPrimaryContainer: _lightOnPrimaryContainer,
        secondary: _lightSecondary,
        onSecondary: _lightOnSecondary,
        secondaryContainer: _lightSecondaryContainer,
        onSecondaryContainer: _lightOnSecondaryContainer,
        tertiary: _lightTertiary,
        onTertiary: _lightOnTertiary,
        tertiaryContainer: _lightTertiaryContainer,
        onTertiaryContainer: _lightOnTertiaryContainer,
        error: _lightError,
        onError: _lightOnError,
        errorContainer: _lightErrorContainer,
        onErrorContainer: _lightOnErrorContainer,
        outline: _lightOutline,
        surface: _lightSurface,
        onSurface: _lightOnSurface,
        background: _lightBackground,
        onBackground: _lightOnBackground,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: _lightSurface,
        foregroundColor: _lightOnSurface,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _lightOutline.withOpacity(0.2)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightOutline.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightError),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        indicatorColor: _lightPrimaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(fontSize: 12);
        }),
      ),
    );
  }

  /// Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: _darkPrimary,
        onPrimary: _darkOnPrimary,
        primaryContainer: _darkPrimaryContainer,
        onPrimaryContainer: _darkOnPrimaryContainer,
        secondary: _darkSecondary,
        onSecondary: _darkOnSecondary,
        secondaryContainer: _darkSecondaryContainer,
        onSecondaryContainer: _darkOnSecondaryContainer,
        tertiary: _darkTertiary,
        onTertiary: _darkOnTertiary,
        tertiaryContainer: _darkTertiaryContainer,
        onTertiaryContainer: _darkOnTertiaryContainer,
        error: _darkError,
        onError: _darkOnError,
        errorContainer: _darkErrorContainer,
        onErrorContainer: _darkOnErrorContainer,
        outline: _darkOutline,
        surface: _darkSurface,
        onSurface: _darkOnSurface,
        background: _darkBackground,
        onBackground: _darkOnBackground,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: _darkSurface,
        foregroundColor: _darkOnSurface,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _darkOutline.withOpacity(0.2)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkOutline.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkError),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        indicatorColor: _darkPrimaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(fontSize: 12);
        }),
      ),
    );
  }
}
