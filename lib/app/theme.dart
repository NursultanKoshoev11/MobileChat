import 'package:flutter/material.dart';

/// Spacing scale for the whole app.
///
/// This is the single source of truth for gaps and paddings: new UI code must
/// use these constants instead of raw numbers so the vertical rhythm stays
/// consistent across screens.
abstract final class KoomSpacing {
  /// 4 - hairline gaps inside a single control.
  static const double xs = 4;

  /// 8 - gap between tightly related elements (icon + label).
  static const double sm = 8;

  /// 12 - gap between rows inside a card.
  static const double md = 12;

  /// 16 - default padding of cards, sheets and screen gutters.
  static const double lg = 16;

  /// 24 - gap between sections.
  static const double xl = 24;

  /// 32 - gap around large blocks (empty states, page headers).
  static const double xxl = 32;
}

/// Corner radius scale for the whole app.
///
/// This is the single source of truth for rounded corners. `lib/` used to
/// contain 15 different radii; everything new must pick one of these four.
abstract final class KoomRadii {
  /// 12 - inputs, small buttons, icon buttons, skeleton blocks.
  static const double sm = 12;

  /// 16 - buttons, list tiles, tiles and inner containers.
  static const double md = 16;

  /// 24 - cards, dialogs, sheets and other large surfaces.
  static const double lg = 24;

  /// 999 - fully rounded pills (chips, badges, drag handles).
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// The two elevation levels the app uses.
///
/// This is the single source of truth for depth: `low` for resting surfaces
/// (cards, bars) and `high` for things floating above the page (dialogs,
/// sheets, menus). Pass the theme's shadow color, or use
/// [KoomColors.shadowLow] / [KoomColors.shadowHigh] which already do.
abstract final class KoomElevation {
  /// Material elevation value for resting surfaces.
  static const double low = 2;

  /// Material elevation value for floating surfaces.
  static const double high = 12;

  static List<BoxShadow> shadowLow(Color shadow) => <BoxShadow>[
        BoxShadow(
          color: shadow,
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> shadowHigh(Color shadow) => <BoxShadow>[
        BoxShadow(
          color: shadow,
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];
}

class KoomTheme {
  /// Local Inter asset bundled under `assets/fonts/` (see pubspec.yaml).
  static const String fontFamily = 'Inter';

  static const Color primary = Color(0xFF0878F9);
  static const Color primaryDark = Color(0xFF0757D9);
  static const Color primarySoft = Color(0xFFEAF3FF);
  static const Color accent = Color(0xFF14B8FF);

  static const Color lightPage = Color(0xFFF5F8FE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSoft = Color(0xFFF1F5FB);
  static const Color lightBorder = Color(0xFFDDE6F3);
  static const Color lightTextStrong = Color(0xFF0C1F46);

  /// 5.2:1 on the light page, 5.6:1 on white (WCAG AA for body text).
  static const Color lightTextMuted = Color(0xFF5A6880);

  static const Color darkPage = Color(0xFF07111F);
  static const Color darkSurface = Color(0xFF0F1C2E);
  static const Color darkSurfaceSoft = Color(0xFF16263B);
  static const Color darkBorder = Color(0xFF253A55);
  static const Color darkTextStrong = Color(0xFFF4F7FC);

  /// 7.4:1 on the dark soft surface, 7.9:1 on the dark page.
  static const Color darkTextMuted = Color(0xFF9AA9BF);

  /// The one destructive colour for the light theme (5.1:1 on the page).
  static const Color destructiveLight = Color(0xFFC62F35);

  /// The one destructive colour for the dark theme (6.8:1 on the page).
  static const Color destructiveDark = Color(0xFFFF6B70);

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
      error: destructiveLight,
      onError: Colors.white,
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
      error: destructiveDark,
      onError: darkPage,
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
    final baseTextTheme =
        ThemeData(brightness: scheme.brightness).textTheme.apply(
              fontFamily: fontFamily,
              bodyColor: textStrongColor,
              displayColor: textStrongColor,
            );
    final roundedSm = RoundedRectangleBorder(borderRadius: KoomRadii.smAll);
    final roundedMd = RoundedRectangleBorder(borderRadius: KoomRadii.mdAll);
    final roundedLg = RoundedRectangleBorder(borderRadius: KoomRadii.lgAll);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: pageColor,
      canvasColor: pageColor,
      cardColor: surfaceColor,
      dividerColor: borderColor,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      visualDensity: VisualDensity.standard,
      // Calm type scale: w700 for large headings, w600 for titles and
      // labels, w400 for body copy with comfortable line height. A small
      // negative tracking is kept only on the largest headings.
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: textStrongColor,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: textMutedColor,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: pageColor,
        foregroundColor: textStrongColor,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: KoomSpacing.lg,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
          color: textStrongColor,
          fontFamily: fontFamily,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
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
          borderRadius: KoomRadii.lgAll,
          side: BorderSide(color: borderColor),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dark ? darkTextStrong : primaryDark,
          backgroundColor: surfaceSoftColor,
          disabledForegroundColor: textMutedColor.withValues(alpha: 0.55),
          disabledBackgroundColor: surfaceSoftColor.withValues(alpha: 0.55),
          // Material minimum touch target.
          minimumSize: const Size(48, 48),
          shape: roundedSm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoftColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KoomSpacing.lg,
          vertical: KoomSpacing.lg,
        ),
        labelStyle: TextStyle(
          color: textMutedColor,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: textMutedColor.withValues(alpha: 0.82)),
        prefixIconColor: textMutedColor,
        suffixIconColor: textMutedColor,
        border: OutlineInputBorder(
          borderRadius: KoomRadii.smAll,
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KoomRadii.smAll,
          borderSide: BorderSide(color: borderColor),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: KoomRadii.smAll,
          borderSide: BorderSide(color: borderColor.withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: KoomRadii.smAll,
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: KoomRadii.smAll,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: KoomRadii.smAll,
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
          padding: const EdgeInsets.symmetric(
            horizontal: KoomSpacing.xl,
            vertical: KoomSpacing.md,
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          shape: roundedMd,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: KoomSpacing.lg,
            vertical: KoomSpacing.md,
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: borderColor),
          shape: roundedMd,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
          shape: roundedSm,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: KoomElevation.low,
        focusElevation: KoomElevation.low,
        highlightElevation: KoomElevation.low,
        shape: roundedMd,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KoomSpacing.lg,
          vertical: KoomSpacing.xs,
        ),
        iconColor: textMutedColor,
        textColor: textStrongColor,
        titleTextStyle: TextStyle(
          color: textStrongColor,
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: textMutedColor,
          fontFamily: fontFamily,
          height: 1.4,
        ),
        shape: roundedMd,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoftColor,
        selectedColor: scheme.primary.withValues(alpha: dark ? 0.26 : 0.13),
        disabledColor: surfaceSoftColor.withValues(alpha: 0.5),
        side: BorderSide(color: borderColor),
        shape: const RoundedRectangleBorder(borderRadius: KoomRadii.pillAll),
        labelStyle: TextStyle(
          color: textStrongColor,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: scheme.primary,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: KoomSpacing.sm,
          vertical: KoomSpacing.sm,
        ),
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
            TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          shape: WidgetStatePropertyAll(roundedSm),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: KoomSpacing.md,
              vertical: KoomSpacing.md,
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: KoomElevation.high,
        shadowColor: shadow,
        shape: RoundedRectangleBorder(
          borderRadius: KoomRadii.mdAll,
          side: BorderSide(color: borderColor),
        ),
        textStyle: TextStyle(
          color: textStrongColor,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: KoomElevation.high,
        shadowColor: shadow,
        shape: roundedLg,
        titleTextStyle: TextStyle(
          color: textStrongColor,
          fontFamily: fontFamily,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        contentTextStyle: TextStyle(
          color: textMutedColor,
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        modalBackgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        modalElevation: KoomElevation.high,
        elevation: KoomElevation.low,
        shadowColor: shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KoomRadii.lg),
          ),
        ),
        dragHandleColor: textMutedColor.withValues(alpha: 0.36),
        dragHandleSize: const Size(40, 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: KoomElevation.low,
        height: 72,
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.26 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textMutedColor,
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
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
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
        ),
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
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
        elevation: KoomElevation.high,
        shape: roundedSm,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: Colors.white,
        largeSize: 20,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        KoomColors(
          page: pageColor,
          surface: surfaceColor,
          surfaceSoft: surfaceSoftColor,
          border: borderColor,
          textStrong: textStrongColor,
          textMuted: textMutedColor,
          chipBackground:
              dark ? const Color(0xFF193252) : const Color(0xFFEAF3FF),
          shadow: shadow,
          danger: scheme.error,
          onDanger: scheme.onError,
        ),
      ],
    );
  }
}

class KoomColors extends ThemeExtension<KoomColors> {
  const KoomColors({
    required this.page,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.textStrong,
    required this.textMuted,
    required this.chipBackground,
    required this.shadow,
    required this.danger,
    required this.onDanger,
  });

  final Color page;
  final Color surface;
  final Color surfaceSoft;
  final Color border;
  final Color textStrong;
  final Color textMuted;
  final Color chipBackground;
  final Color shadow;

  /// The single destructive colour of the theme. Use this instead of
  /// `Colors.red.*` for delete/block/report affordances.
  final Color danger;

  /// Readable foreground on top of [danger].
  final Color onDanger;

  /// Shadow for resting surfaces (cards, bars). See [KoomElevation].
  List<BoxShadow> get shadowLow => KoomElevation.shadowLow(shadow);

  /// Shadow for floating surfaces (dialogs, sheets). See [KoomElevation].
  List<BoxShadow> get shadowHigh => KoomElevation.shadowHigh(shadow);

  @override
  KoomColors copyWith({
    Color? page,
    Color? surface,
    Color? surfaceSoft,
    Color? border,
    Color? textStrong,
    Color? textMuted,
    Color? chipBackground,
    Color? shadow,
    Color? danger,
    Color? onDanger,
  }) {
    return KoomColors(
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      textStrong: textStrong ?? this.textStrong,
      textMuted: textMuted ?? this.textMuted,
      chipBackground: chipBackground ?? this.chipBackground,
      shadow: shadow ?? this.shadow,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
    );
  }

  @override
  KoomColors lerp(ThemeExtension<KoomColors>? other, double t) {
    if (other is! KoomColors) return this;
    return KoomColors(
      page: Color.lerp(page, other.page, t) ?? page,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t) ?? surfaceSoft,
      border: Color.lerp(border, other.border, t) ?? border,
      textStrong: Color.lerp(textStrong, other.textStrong, t) ?? textStrong,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      chipBackground:
          Color.lerp(chipBackground, other.chipBackground, t) ?? chipBackground,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      onDanger: Color.lerp(onDanger, other.onDanger, t) ?? onDanger,
    );
  }
}

extension KoomThemeContext on BuildContext {
  KoomColors get appColors => Theme.of(this).extension<KoomColors>()!;
}
