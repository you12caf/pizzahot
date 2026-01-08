import 'package:flutter/material.dart';

/// Universal Premium Theme
///
/// - Primary: 0xFFFC6011 (Professional Orange)
/// - Scaffold: Colors.grey[50] (Clean Off-White)
/// - Cards: White, elevation 2, radius 16
/// - AppBar: White background, black text/icons
/// - Buttons: Orange background, white text
///
/// This provider exposes a single, static [ThemeData].
/// All dynamic / Firestore-driven theming has been removed
/// to guarantee a consistent visual identity.
class ThemeProvider with ChangeNotifier {
  static const Color _primaryOrange = Color(0xFFFC6011);
  static final Color _scaffoldBg = Colors.grey[50]!;

  final ThemeData _themeData = ThemeData(
    useMaterial3: false,

    // Core colors
    primaryColor: _primaryOrange,
    scaffoldBackgroundColor: _scaffoldBg,
    colorScheme: ColorScheme.light(
      primary: _primaryOrange,
      secondary: _primaryOrange,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
    ),

    // AppBar: white with black content
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Cards: white, elevation 2, radius 16
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),

    // Buttons: orange background, white text
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryOrange,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    // FABs follow primary orange
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primaryOrange,
      foregroundColor: Colors.white,
    ),

    // Text: high-contrast, premium feel
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      titleLarge: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Inputs: clean, white, softly rounded
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryOrange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  ThemeData get themeData => _themeData;

  // Theme is fixed; external mutation is intentionally disabled to
  // prevent accidental regressions to old color schemes.
}
