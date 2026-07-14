import 'package:flutter/material.dart';

class MobileChatTheme {
  static const Color primary = Color(0xFF0878F9);
  static const Color primaryDark = Color(0xFF0757D9);
  static const Color primarySoft = Color(0xFFEAF3FF);
  static const Color accent = Color(0xFF14B8FF);

  static const Color lightPage = Color(0xFFF5F8FE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSoft = Color(0xFFF1F5FB);
  static const Color lightBorder = Color(0xFFDDE6F3);
  static const Color lightTextStrong = Color(0xFF0C1F46);
  static const Color lightTextMuted = Color(0xFF6C7A96);

  static const Color darkPage = Color(0xFF07111F);
  static const Color darkSurface = Color(0xFF0F1C2E);
  static const Color darkSurfaceSoft = Color(0xFF16263B);
  static const Color darkBorder = Color(0xFF253A55);
  static const Color darkTextStrong = Color(0xFFF4F7FC);
  static const Color darkTextMuted = Color(0xFF9AA9BF);

  static const Color page = lightPage;
  static const Color textStrong = lightTextStrong;
  static const Color textMuted = lightTextMuted;
  static const Color mineBubble = Color(0xFFDCEEFF);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0A83FF), Color(0xFF0662EA)],
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      brightness: Brightness.light,
      surface: lightSurface,
      onSurface: lightTextStrong,
      error: const Color(0xFFE5484D),
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
      primary: const Color(0xFF4DA3FF),
      secondary: const Color(0xFF3CC5FF),
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: darkTextStrong,
      error: const Color(0xFFFF6B70),
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
    final dark = scheme.brightness == Brightness.dark;
    final shadow = dark
        ? Colors.black.withValues(alpha: 0.34)
        : const Color(0xFF174C8F).withValues(alpha: 0.10);
    final baseTextTheme = ThemeData(brightness: scheme.brightness).textTheme;
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final rounded18 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageColor,
      canvasColor: pageColor,
      cardColor: surfaceColor,
      dividerColor: borderColor,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      visualDensity: VisualDensity.standard,
      textTheme: baseTextTheme
          .apply(bodyColor: textStrongColor, displayColor: textStrongColor)
          .copyWith(
            headlineLarge: baseTextTheme.headlineLarge?.copyWith(
              color: textStrongColor,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
            headlineMedium: baseTextTheme.headlineMedium?.copyWith(
              color: textStrongColor,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            headlineSmall: baseTextTheme.headlineSmall?.copyWith(
              color: textStrongColor,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
            titleLarge: baseTextTheme.titleLarge?.copyWith(
              color: textStrongColor,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
            titleMedium: baseTextTheme.titleMedium?.copyWith(
              color: textStrongColor,
              fontWeight: FontWeight.w800,
            ),
            bodyLarge: baseTextTheme.bodyLarge?.copyWith(
              color: textStrongColor,
              height: 1.42,
            ),
            bodyMedium: baseTextTheme.bodyMedium?.copyWith(
              color: textStrongColor,
              height: 1.38,
            ),
            labelLarge: baseTextTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: pageColor,
        foregroundColor: textStrongColor,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
          color: textStrongColor,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.35,
        ),
        iconTheme: IconThemeData(color: textStrongColor),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dark ? darkTextStrong : primaryDark,
          backgroundColor: surfaceSoftColor,
          disabledForegroundColor: textMutedColor.withValues(alpha: 0.55),
          disabledBackgroundColor: surfaceSoftColor.withValues(alpha: 0.55),
          minimumSize: const Size(42, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoftColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle:
            TextStyle(color: textMutedColor, fontWeight: FontWeight.w700),
        floatingLabelStyle:
            TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
        hintStyle: TextStyle(color: textMutedColor.withValues(alpha: 0.82)),
        prefixIconColor: textMutedColor,
        suffixIconColor: textMutedColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: scheme.error, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.32),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          elevation: 0,
          shape: rounded16,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          side: BorderSide(color: borderColor),
          shape: rounded16,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 6,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        iconColor: textMutedColor,
        textColor: textStrongColor,
        titleTextStyle: TextStyle(
          color: textStrongColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
        subtitleTextStyle: TextStyle(color: textMutedColor, height: 1.3),
        shape: rounded18,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoftColor,
        selectedColor: scheme.primary.withValues(alpha: dark ? 0.26 : 0.13),
        disabledColor: surfaceSoftColor.withValues(alpha: 0.5),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle:
            TextStyle(color: textStrongColor, fontWeight: FontWeight.w800),
        secondaryLabelStyle:
            TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) return scheme.primary;
            return surfaceSoftColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return textMutedColor;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        textStyle:
            TextStyle(color: textStrongColor, fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: TextStyle(
          color: textStrongColor,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle:
            TextStyle(color: textMutedColor, fontSize: 15, height: 1.4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        modalBackgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        modalElevation: 18,
        elevation: 8,
        shadowColor: shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        dragHandleColor: textMutedColor.withValues(alpha: 0.36),
        dragHandleSize: const Size(42, 5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        height: 72,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.26 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textMutedColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textMutedColor,
            size: 23,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: borderColor,
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: textMutedColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaceSoftColor,
        circularTrackColor: surfaceSoftColor,
      ),
      dividerTheme:
          DividerThemeData(color: borderColor, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1A2B43) : lightTextStrong,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: Colors.white,
        largeSize: 20,
        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      ),
      extensions: <ThemeExtension<dynamic>>[
        MobileChatColors(
          page: pageColor,
          surface: surfaceColor,
          surfaceSoft: surfaceSoftColor,
          border: borderColor,
          textStrong: textStrongColor,
          textMuted: textMutedColor,
          chipBackground:
              dark ? const Color(0xFF193252) : const Color(0xFFEAF3FF),
          shadow: shadow,
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
      chipBackground:
          Color.lerp(chipBackground, other.chipBackground, t) ?? chipBackground,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
    );
  }
}

extension MobileChatThemeContext on BuildContext {
  MobileChatColors get appColors =>
      Theme.of(this).extension<MobileChatColors>()!;
}
