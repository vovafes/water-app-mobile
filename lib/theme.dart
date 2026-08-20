import 'package:flutter/material.dart';

/// Brand colours, mirrored from the web app's Tailwind palette.
///
/// Web (resources/views/layouts/{app,guest}.blade.php) uses
/// `from-sky-400 to-cyan-500` for the logo gradient and `sky` as the
/// accent throughout. We keep those colour names below so it's easy to
/// trace a value back to its Tailwind reference.
class BrandColors {
  // Sky scale
  static const sky50 = Color(0xFFF0F9FF);
  static const sky100 = Color(0xFFE0F2FE);
  static const sky300 = Color(0xFF7DD3FC);
  static const sky400 = Color(0xFF38BDF8);
  static const sky500 = Color(0xFF0EA5E9);
  static const sky600 = Color(0xFF0284C7);
  static const sky700 = Color(0xFF0369A1);
  static const sky900 = Color(0xFF0C4A6E);
  static const sky950 = Color(0xFF082F49);

  // Cyan scale (gradient companion)
  static const cyan500 = Color(0xFF06B6D4);
  static const cyan600 = Color(0xFF0891B2);

  // Slate scale
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  // Status
  static const amber500 = Color(0xFFF59E0B);
  static const rose500 = Color(0xFFF43F5E);
  static const emerald500 = Color(0xFF10B981);

  // Gradient endpoints used by the web hero card
  static const gradientStart = sky400;
  static const gradientEnd = cyan500;
  static const gradientStartStrong = sky500;
  static const gradientEndStrong = cyan600;
}

ThemeData buildLightTheme() {
  final colorScheme = const ColorScheme.light(
    primary: BrandColors.sky500,
    onPrimary: Colors.white,
    primaryContainer: BrandColors.sky100,
    onPrimaryContainer: BrandColors.sky900,
    secondary: BrandColors.cyan500,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCFFAFE),
    onSecondaryContainer: Color(0xFF155E75),
    tertiary: BrandColors.amber500,
    onTertiary: Colors.white,
    error: BrandColors.rose500,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: BrandColors.slate900,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: BrandColors.slate50,
    surfaceContainer: BrandColors.slate100,
    surfaceContainerHigh: BrandColors.slate200,
    surfaceContainerHighest: BrandColors.slate200,
    outline: BrandColors.slate300,
    outlineVariant: BrandColors.slate200,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BrandColors.slate50,
    textTheme: _baseTextTheme(BrandColors.slate900),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: BrandColors.slate900,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: BrandColors.slate900,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BrandColors.slate200),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.sky500,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.slate300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.slate300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.sky500, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: BrandColors.sky100,
      // 12sp wraps "Achievements"/"Досягнення" onto a second line in a
      // five-tab bar; 11sp keeps every locale on one line.
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: BrandColors.slate200,
      thickness: 1,
      space: 1,
    ),
  );
}

ThemeData buildDarkTheme() {
  final colorScheme = const ColorScheme.dark(
    primary: BrandColors.sky400,
    onPrimary: BrandColors.slate950,
    primaryContainer: Color(0xFF075985), // sky-800
    onPrimaryContainer: BrandColors.sky100,
    secondary: BrandColors.cyan500,
    onSecondary: BrandColors.slate950,
    secondaryContainer: Color(0xFF155E75),
    onSecondaryContainer: Color(0xFFCFFAFE),
    tertiary: BrandColors.amber500,
    onTertiary: BrandColors.slate950,
    error: BrandColors.rose500,
    onError: BrandColors.slate950,
    surface: BrandColors.slate900,
    onSurface: BrandColors.slate100,
    surfaceContainerLowest: BrandColors.slate950,
    surfaceContainerLow: BrandColors.slate900,
    surfaceContainer: BrandColors.slate800,
    surfaceContainerHigh: BrandColors.slate700,
    surfaceContainerHighest: BrandColors.slate700,
    outline: BrandColors.slate700,
    outlineVariant: BrandColors.slate800,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BrandColors.slate950,
    textTheme: _baseTextTheme(BrandColors.slate100),
    appBarTheme: AppBarTheme(
      backgroundColor: BrandColors.slate900,
      surfaceTintColor: Colors.transparent,
      foregroundColor: BrandColors.slate100,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: BrandColors.slate100,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
    cardTheme: CardThemeData(
      color: BrandColors.slate900,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BrandColors.slate800),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.sky500,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrandColors.slate900,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.slate700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.slate700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BrandColors.sky400, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: BrandColors.slate900,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Color(0xFF075985),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: BrandColors.slate800,
      thickness: 1,
      space: 1,
    ),
  );
}

TextTheme _baseTextTheme(Color base) => TextTheme(
  displayLarge: TextStyle(color: base),
  displayMedium: TextStyle(color: base),
  displaySmall: TextStyle(color: base),
  headlineLarge: TextStyle(color: base, fontWeight: FontWeight.w700),
  headlineMedium: TextStyle(color: base, fontWeight: FontWeight.w700),
  headlineSmall: TextStyle(color: base, fontWeight: FontWeight.w700),
  titleLarge: TextStyle(color: base, fontWeight: FontWeight.w600),
  titleMedium: TextStyle(color: base, fontWeight: FontWeight.w600),
  titleSmall: TextStyle(color: base, fontWeight: FontWeight.w600),
  bodyLarge: TextStyle(color: base),
  bodyMedium: TextStyle(color: base),
  bodySmall: TextStyle(color: base),
  labelLarge: TextStyle(color: base),
  labelMedium: TextStyle(color: base),
  labelSmall: TextStyle(color: base),
);
