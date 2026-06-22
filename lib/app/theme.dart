import 'package:flutter/material.dart';

class MobileChatTheme {
  static const Color primary = Color(0xFF2AABEE);
  static const Color primaryDark = Color(0xFF168AC4);

  static const Color lightPage = Color(0xFFEFF4FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSoft = Color(0xFFF8FBFF);
  static const Color lightBorder = Color(0xFFDCE7F3);
  static const Color lightTextStrong = Color(0xFF122033);
  static const Color lightTextMuted = Color(0xFF64748B);

  static const Color darkPage = Color(0xFF0E1621);
  static const Color darkSurface = Color(0xFF17212B);
  static const Color darkSurfaceSoft = Color(0xFF1F2C38);
  static const Color darkBorder = Color(0xFF2D3B48);
  static const Color darkTextStrong = Color(0xFFEAF2F8);
  static const Color darkTextMuted = Color(0xFF98A8B8);

  static const Color page = lightPage;
  static const Color textStrong = lightTextStrong;
  static const Color textMuted = lightTextMuted;
  static const Color mineBubble = Color(0xFFDDF3FF);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      brightness: Brightness.light,
      surface: lightSurface,
      onSurface: lightTextStrong,
    );
    return _buildTheme(
      scheme: scheme,
      pageColor: lightPage,
      surfaceColor: lightSurface,
      surfaceSoftColor: lightSurfaceSoft,
      borderColor: lightBorder,
      textStrongColor: lightTextStrong,
      textMutedColor: lightTextMuted,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: darkTextStrong,
    );
    return _buildTheme(
      scheme: scheme,
      pageColor: darkPage,
      surfaceColor: darkSurface,
      surfaceSoftColor: darkSurfaceSoft,
      borderColor: darkBorder,
      textStrongColor: darkTextStrong,
      textMutedColor: darkTextMuted,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required Color pageColor,
    required Color surfaceColor,
    required Color surfaceSoftColor,
    required Color borderColor,
    required Color textStrongColor,
    required Color textMutedColor,
  }) {
    final iconButtonBackground = scheme.brightness == Brightness.dark ? darkSurfaceSoft : const Color(0xFFE0F2FE);
    final iconButtonForeground = scheme.brightness == Brightness.dark ? darkTextStrong : primaryDark;
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageColor,
      canvasColor: pageColor,
      cardColor: surfaceColor,
      dividerColor: borderColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textStrongColor,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: iconButtonForeground,
          backgroundColor: iconButtonBackground,
          disabledForegroundColor: textMutedColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoftColor,
        labelStyle: TextStyle(color: textMutedColor),
        hintStyle: TextStyle(color: textMutedColor),
        prefixIconColor: textMutedColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.brightness == Brightness.dark ? darkSurfaceSoft : lightTextStrong,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: ThemeData(brightness: scheme.brightness).textTheme.apply(
            bodyColor: textStrongColor,
            displayColor: textStrongColor,
          ),
      extensions: <ThemeExtension<dynamic>>[
        MobileChatColors(
          page: pageColor,
          surface: surfaceColor,
          surfaceSoft: surfaceSoftColor,
          border: borderColor,
          textStrong: textStrongColor,
          textMuted: textMutedColor,
          chipBackground: scheme.brightness == Brightness.dark ? const Color(0xFF21374A) : const Color(0xFFEFF6FF),
          shadow: scheme.brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

class MobileChatColors extends ThemeExtension<MobileChatColors> {
  const MobileChatColors({
    required this.page,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.textStrong,
    required this.textMuted,
    required this.chipBackground,
    required this.shadow,
  });

  final Color page;
  final Color surface;
  final Color surfaceSoft;
  final Color border;
  final Color textStrong;
  final Color textMuted;
  final Color chipBackground;
  final Color shadow;

  @override
  MobileChatColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceSoft,
    Color? border,
    Color? textStrong,
    Color? textMuted,
    Color? chipBackground,
    Color? shadow,
  }) {
    return MobileChatColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      textStrong: textStrong ?? this.textStrong,
      textMuted: textMuted ?? this.textMuted,
      chipBackground: chipBackground ?? this.chipBackground,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  MobileChatColors lerp(ThemeExtension<MobileChatColors>? other, double t) {
    if (other is! MobileChatColors) return this;
    return MobileChatColors(
      page: Color.lerp(page, other.page, t) ?? page,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t) ?? surfaceSoft,
      border: Color.lerp(border, other.border, t) ?? border,
      textStrong: Color.lerp(textStrong, other.textStrong, t) ?? textStrong,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t) ?? chipBackground,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
    );
  }
}

extension MobileChatThemeContext on BuildContext {
  MobileChatColors get appColors => Theme.of(this).extension<MobileChatColors>()!;
}

