import 'package:flutter/material.dart';

class JagtTheme {
  static const _forest = Color(0xFF1B3A1B);
  static const _forestLight = Color(0xFF2E5A2E);
  static const _bark = Color(0xFF2C2416);
  static const _sand = Color(0xFFF5F0E8);
  static const _sandDark = Color(0xFFE8E0D0);
  static const _gold = Color(0xFFB8860B);
  static const _goldLight = Color(0xFFD4A843);
  static const _cream = Color(0xFFFAF8F4);

  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: _forest,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCCE5CC),
      onPrimaryContainer: _forest,
      secondary: _gold,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFF3D6),
      onSecondaryContainer: _bark,
      surface: _cream,
      onSurface: _bark,
      onSurfaceVariant: Color(0xFF5C5345),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: _cream,
      surfaceContainer: Color(0xFFF0EBE0),
      surfaceContainerHigh: Color(0xFFEAE2D4),
      surfaceContainerHighest: _sand,
      error: Color(0xFFB3261E),
      outline: Color(0xFF8A8070),
    ),
    scaffoldBackgroundColor: _cream,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: _forest,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _forest,
      indicatorColor: _forestLight,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _goldLight, size: 24);
        }
        return IconThemeData(color: Colors.white.withValues(alpha: 0.6), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: _goldLight,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          );
        }
        return TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
        );
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _sandDark.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _sandDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _sandDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _forest, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _forest,
        side: const BorderSide(color: _forest),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _forest),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _sand,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: _sandDark.withValues(alpha: 0.5)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _gold,
      foregroundColor: Colors.white,
      elevation: 3,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: _forest,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _forest,
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF8ABF8A),
      onPrimary: _forest,
      primaryContainer: Color(0xFF243824),
      onPrimaryContainer: Color(0xFFCCE5CC),
      secondary: _goldLight,
      onSecondary: _bark,
      secondaryContainer: Color(0xFF4A3A10),
      onSecondaryContainer: _goldLight,
      surface: Color(0xFF141412),
      onSurface: Color(0xFFF0EAE0),
      onSurfaceVariant: Color(0xFFB0A896),
      surfaceContainerLowest: Color(0xFF101010),
      surfaceContainerLow: Color(0xFF1A1A16),
      surfaceContainer: Color(0xFF222220),
      surfaceContainerHigh: Color(0xFF2E2E28),
      surfaceContainerHighest: Color(0xFF3A3A32),
      error: Color(0xFFFF8A80),
      outline: Color(0xFF8A7E6E),
    ),
    scaffoldBackgroundColor: const Color(0xFF141412),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Color(0xFF141412),
      foregroundColor: Color(0xFFF0EAE0),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1A16),
      surfaceTintColor: Colors.transparent,
      indicatorColor: _forest,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _goldLight, size: 24);
        }
        return IconThemeData(color: Colors.white.withValues(alpha: 0.5), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: _goldLight, fontSize: 11, fontWeight: FontWeight.w600);
        }
        return TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11);
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF1E1E1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8ABF8A), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFF1E1E1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF8ABF8A),
        foregroundColor: _forest,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8ABF8A),
        side: const BorderSide(color: Color(0xFF8ABF8A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF8ABF8A)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF2A2A24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.1)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _goldLight,
      foregroundColor: Color(0xFF141412),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF8ABF8A),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFF1E1E1A),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Color(0xFF8ABF8A),
    ),
  );
}
