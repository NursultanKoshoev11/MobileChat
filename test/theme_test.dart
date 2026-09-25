import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/theme.dart';

void main() {
  test('KoomTheme exposes light and dark color extensions', () {
    final light = KoomTheme.light;
    final dark = KoomTheme.dark;

    expect(light.brightness, Brightness.light);
    expect(light.scaffoldBackgroundColor, KoomTheme.lightPage);
    expect(light.cardColor, KoomTheme.lightSurface);
    expect(light.dividerColor, KoomTheme.lightBorder);
    expect(light.extension<KoomColors>()!.textStrong,
        KoomTheme.lightTextStrong);

    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, KoomTheme.darkPage);
    expect(dark.cardColor, KoomTheme.darkSurface);
    expect(dark.dividerColor, KoomTheme.darkBorder);
    expect(dark.extension<KoomColors>()!.textMuted,
        KoomTheme.darkTextMuted);
  });

  test('KoomColors copyWith and lerp preserve theme values', () {
    final light = KoomTheme.light.extension<KoomColors>()!;
    final dark = KoomTheme.dark.extension<KoomColors>()!;

    final copied = light.copyWith(
      page: Colors.red,
      surface: Colors.green,
      surfaceSoft: Colors.blue,
      border: Colors.yellow,
      textStrong: Colors.black,
      textMuted: Colors.grey,
      chipBackground: Colors.purple,
      shadow: Colors.orange,
    );
    expect(copied.page, Colors.red);
    expect(copied.surface, Colors.green);
    expect(copied.surfaceSoft, Colors.blue);
    expect(copied.border, Colors.yellow);
    expect(copied.textStrong, Colors.black);
    expect(copied.textMuted, Colors.grey);
    expect(copied.chipBackground, Colors.purple);
    expect(copied.shadow, Colors.orange);

    final unchanged = light.copyWith();
    expect(unchanged.page, light.page);
    expect(unchanged.surface, light.surface);
    expect(unchanged.surfaceSoft, light.surfaceSoft);
    expect(unchanged.border, light.border);
    expect(unchanged.textStrong, light.textStrong);
    expect(unchanged.textMuted, light.textMuted);
    expect(unchanged.chipBackground, light.chipBackground);
    expect(unchanged.shadow, light.shadow);

    final midpoint = light.lerp(dark, 0.5);
    expect(midpoint.page, Color.lerp(light.page, dark.page, 0.5));
    expect(midpoint.shadow, Color.lerp(light.shadow, dark.shadow, 0.5));
    expect(light.lerp(null, 0.5), same(light));
  });

  test('selection typography keeps identical metrics', () {
    final theme = KoomTheme.light;

    final chipTheme = theme.chipTheme;
    expect(chipTheme.labelStyle?.fontWeight,
        chipTheme.secondaryLabelStyle?.fontWeight);
    expect(chipTheme.showCheckmark, isFalse);

    final navigationTheme = theme.navigationBarTheme;
    final selectedNavigationStyle = navigationTheme.labelTextStyle?.resolve(
      const <WidgetState>{WidgetState.selected},
    );
    final unselectedNavigationStyle = navigationTheme.labelTextStyle?.resolve(
      const <WidgetState>{},
    );
    expect(
      selectedNavigationStyle?.fontWeight,
      unselectedNavigationStyle?.fontWeight,
    );
    expect(
      selectedNavigationStyle?.fontSize,
      unselectedNavigationStyle?.fontSize,
    );
    expect(
      navigationTheme.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );

    final tabTheme = theme.tabBarTheme;
    expect(tabTheme.labelStyle?.fontWeight,
        tabTheme.unselectedLabelStyle?.fontWeight);
  });

  testWidgets('BuildContext extension returns KoomColors',
      (tester) async {
    late KoomColors colors;

    await tester.pumpWidget(
      MaterialApp(
        theme: KoomTheme.light,
        home: Builder(
          builder: (context) {
            colors = context.appColors;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(colors.page, KoomTheme.lightPage);
  });
}
