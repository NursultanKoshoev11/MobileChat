import 'package:flutter/material.dart';

class MobileChatTheme {
  static const Color primary = Color(0xFF2AABEE);
  static const Color primaryDark = Color(0xFF168AC4);
  static const Color page = Color(0xFFF3F7FB);
  static const Color textStrong = Color(0xFF122033);
  static const Color textMuted = Color(0xFF64748B);
  static const Color mineBubble = Color(0xFFDDF3FF);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: primary, primary: primary);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: page,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textStrong,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
