import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/shared/koom_ui.dart';

double _channel(int value) {
  final c = value / 255.0;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color color) {
  return 0.2126 * _channel((color.r * 255).round()) +
      0.7152 * _channel((color.g * 255).round()) +
      0.0722 * _channel((color.b * 255).round());
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('design tokens', () {
    test('spacing scale is 4/8/12/16/24/32', () {
      expect(
        [
          KoomSpacing.xs,
          KoomSpacing.sm,
          KoomSpacing.md,
          KoomSpacing.lg,
          KoomSpacing.xl,
          KoomSpacing.xxl,
        ],
        [4.0, 8.0, 12.0, 16.0, 24.0, 32.0],
      );
    });

    test('radius scale is sm 12 / md 16 / lg 24 / pill 999', () {
      expect(KoomRadii.sm, 12);
      expect(KoomRadii.md, 16);
      expect(KoomRadii.lg, 24);
      expect(KoomRadii.pill, 999);
      expect(KoomRadii.smAll.topLeft.x, KoomRadii.sm);
      expect(KoomRadii.mdAll.topLeft.x, KoomRadii.md);
      expect(KoomRadii.lgAll.topLeft.x, KoomRadii.lg);
      expect(KoomRadii.pillAll.topLeft.x, KoomRadii.pill);
    });

    test('there are exactly two elevation levels and they differ', () {
      expect(KoomElevation.low, lessThan(KoomElevation.high));
      final low = KoomElevation.shadowLow(Colors.black);
      final high = KoomElevation.shadowHigh(Colors.black);
      expect(low, hasLength(1));
      expect(high, hasLength(1));
      expect(high.first.blurRadius, greaterThan(low.first.blurRadius));
      expect(high.first.offset.dy, greaterThan(low.first.offset.dy));
    });

    test('theme component shapes come from the radius scale', () {
      for (final theme in [KoomTheme.light, KoomTheme.dark]) {
        final card = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(card.borderRadius, KoomRadii.lgAll);
        final icon = theme.iconButtonTheme.style!.shape!.resolve(
          const <WidgetState>{},
        )! as RoundedRectangleBorder;
        expect(icon.borderRadius, KoomRadii.smAll);
        final chip = theme.chipTheme.shape! as RoundedRectangleBorder;
        expect(chip.borderRadius, KoomRadii.pillAll);
      }
    });

    test('KoomColors exposes both shadow levels', () {
      final colors = KoomTheme.light.extension<KoomColors>()!;
      expect(colors.shadowLow.first.color, colors.shadow);
      expect(
        colors.shadowHigh.first.blurRadius,
        greaterThan(colors.shadowLow.first.blurRadius),
      );
    });
  });

  group('typography', () {
    test('uses the bundled Inter family', () {
      expect(KoomTheme.fontFamily, 'Inter');
      for (final theme in [KoomTheme.light, KoomTheme.dark]) {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
        expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Inter');
      }
    });

    test('headings are w700, titles w600, body w400, labels w600', () {
      final text = KoomTheme.light.textTheme;
      expect(text.headlineLarge?.fontWeight, FontWeight.w700);
      expect(text.headlineMedium?.fontWeight, FontWeight.w700);
      expect(text.headlineSmall?.fontWeight, FontWeight.w700);
      expect(text.titleLarge?.fontWeight, FontWeight.w600);
      expect(text.titleMedium?.fontWeight, FontWeight.w600);
      expect(text.titleSmall?.fontWeight, FontWeight.w600);
      expect(text.bodyLarge?.fontWeight, FontWeight.w400);
      expect(text.bodyMedium?.fontWeight, FontWeight.w400);
      expect(text.labelLarge?.fontWeight, FontWeight.w600);
      expect(text.labelMedium?.fontWeight, FontWeight.w600);
    });

    test('body copy keeps a comfortable line height', () {
      final text = KoomTheme.light.textTheme;
      expect(text.bodyLarge?.height, greaterThanOrEqualTo(1.45));
      expect(text.bodyMedium?.height, greaterThanOrEqualTo(1.4));
    });

    test('negative tracking is limited to the largest headings', () {
      final text = KoomTheme.light.textTheme;
      for (final style in [
        text.headlineLarge,
        text.headlineMedium,
        text.headlineSmall,
      ]) {
        expect(style!.letterSpacing, inInclusiveRange(-0.3, -0.2));
      }
      expect(text.titleLarge?.letterSpacing, 0);
      expect(text.titleMedium?.letterSpacing, 0);
      expect(text.bodyMedium?.letterSpacing ?? 0, greaterThanOrEqualTo(0));
    });

    test('no component theme is heavier than w700', () {
      for (final theme in [KoomTheme.light, KoomTheme.dark]) {
        final weights = <FontWeight?>[
          theme.appBarTheme.titleTextStyle?.fontWeight,
          theme.dialogTheme.titleTextStyle?.fontWeight,
          theme.dialogTheme.contentTextStyle?.fontWeight,
          theme.listTileTheme.titleTextStyle?.fontWeight,
          theme.chipTheme.labelStyle?.fontWeight,
          theme.snackBarTheme.contentTextStyle?.fontWeight,
          theme.badgeTheme.textStyle?.fontWeight,
          theme.tabBarTheme.labelStyle?.fontWeight,
          theme.navigationBarTheme.labelTextStyle
              ?.resolve(const <WidgetState>{})?.fontWeight,
          theme.filledButtonTheme.style?.textStyle
              ?.resolve(const <WidgetState>{})?.fontWeight,
        ];
        for (final weight in weights) {
          expect(weight, isNotNull);
          expect(weight!.value, lessThanOrEqualTo(FontWeight.w700.value));
        }
      }
    });
  });

  group('accessibility', () {
    test('icon buttons meet the 48x48 Material minimum', () {
      for (final theme in [KoomTheme.light, KoomTheme.dark]) {
        final size = theme.iconButtonTheme.style?.minimumSize
            ?.resolve(const <WidgetState>{});
        expect(size, const Size(48, 48));
      }
    });

    test('buttons stay at least 48 logical pixels tall', () {
      for (final theme in [KoomTheme.light, KoomTheme.dark]) {
        for (final style in [
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
        ]) {
          final size = style?.minimumSize?.resolve(const <WidgetState>{});
          expect(size!.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
        }
      }
    });

    test('body and muted text pass 4.5:1 in both themes', () {
      for (final theme in [KoomTheme.light, KoomTheme.dark]) {
        final colors = theme.extension<KoomColors>()!;
        for (final background in [
          colors.page,
          colors.surface,
          colors.surfaceSoft,
          colors.chipBackground,
        ]) {
          expect(
            contrastRatio(colors.textStrong, background),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrastRatio(colors.textMuted, background),
            greaterThanOrEqualTo(4.5),
            reason: 'muted text on ${background.toString()}',
          );
        }
      }
    });

    test('one destructive colour per theme, readable on page and surface', () {
      final light = KoomTheme.light;
      final dark = KoomTheme.dark;
      expect(light.extension<KoomColors>()!.danger, light.colorScheme.error);
      expect(dark.extension<KoomColors>()!.danger, dark.colorScheme.error);
      expect(light.colorScheme.error, KoomTheme.destructiveLight);
      expect(dark.colorScheme.error, KoomTheme.destructiveDark);
      expect(light.colorScheme.error, isNot(dark.colorScheme.error));

      for (final theme in [light, dark]) {
        final colors = theme.extension<KoomColors>()!;
        expect(
          contrastRatio(colors.danger, colors.page),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(colors.danger, colors.surface),
          greaterThanOrEqualTo(4.5),
        );
        // A filled destructive button must stay readable too.
        expect(
          contrastRatio(colors.onDanger, colors.danger),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('default text size', () {
    test('a fresh install starts at the normal 100% scale', () {
      expect(kDefaultDisplayScale, AppDisplayScale.standard);
      expect(AppDisplayScale.standard.factor, 1.0);
      expect(AppAppearanceController().displayScale, AppDisplayScale.standard);
    });

    test('restore keeps the default when nothing is stored', () async {
      final controller = AppAppearanceController();
      await controller.restore();
      expect(controller.displayScale, AppDisplayScale.standard);
    });
  });

  group('KoomSkeleton', () {
    Widget host(Widget child, {bool disableAnimations = false}) {
      return MaterialApp(
        theme: KoomTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(body: Center(child: child)),
        ),
      );
    }

    Color blockColor(WidgetTester tester) {
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(KoomSkeleton),
          matching: find.byType(Container),
        ),
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    testWidgets('renders a rounded block and animates', (tester) async {
      await tester.pumpWidget(
        host(const KoomSkeleton(width: 200, height: 20)),
      );

      final box = tester.getSize(find.byType(KoomSkeleton));
      expect(box, const Size(200, 20));

      final decoration = (tester
          .widget<Container>(
            find.descendant(
              of: find.byType(KoomSkeleton),
              matching: find.byType(Container),
            ),
          )
          .decoration! as BoxDecoration);
      expect(decoration.borderRadius, BorderRadius.circular(KoomRadii.sm));

      final first = blockColor(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(blockColor(tester), isNot(first));
      // Keep the looping animation from leaking into later frames.
      await tester.pumpWidget(host(const SizedBox()));
    });

    testWidgets('honours MediaQuery.disableAnimations', (tester) async {
      await tester.pumpWidget(
        host(
          const KoomSkeleton(width: 120, height: 16),
          disableAnimations: true,
        ),
      );

      final first = blockColor(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(blockColor(tester), first);
      // No pending animation: the tree settles.
      await tester.pumpAndSettle();
      expect(blockColor(tester), first);
    });

    testWidgets('adapts to light and dark surfaces', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KoomTheme.dark,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(400, 800),
              disableAnimations: true,
            ),
            child: Scaffold(body: KoomSkeleton(height: 18)),
          ),
        ),
      );
      expect(
        blockColor(tester),
        KoomTheme.dark.extension<KoomColors>()!.surfaceSoft,
      );
    });

    testWidgets('is hidden from screen readers', (tester) async {
      await tester.pumpWidget(
        host(
          const KoomSkeleton(height: 18),
          disableAnimations: true,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(KoomSkeleton),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('KoomSkeletonList lays out the requested rows', (tester) async {
      await tester.pumpWidget(
        host(
          const KoomSkeletonList(itemCount: 4, itemHeight: 40),
          disableAnimations: true,
        ),
      );

      expect(find.byType(KoomSkeleton), findsNWidgets(4));
      final first = tester.getRect(find.byType(KoomSkeleton).first);
      final second = tester.getRect(find.byType(KoomSkeleton).at(1));
      expect(first.height, 40);
      expect(second.top - first.bottom, KoomSpacing.md);
    });

    testWidgets('KoomSkeletonList renders nothing for an empty list',
        (tester) async {
      await tester.pumpWidget(
        host(
          const KoomSkeletonList(itemCount: 0),
          disableAnimations: true,
        ),
      );
      expect(find.byType(KoomSkeleton), findsNothing);
    });
  });
}
