import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/app/theme.dart';

void main() {
  test('MobileChatTheme exposes light and dark color extensions', () {
    final light = MobileChatTheme.light;
    final dark = MobileChatTheme.dark;

    expect(light.brightness, Brightness.light);
    expect(light.scaffoldBackgroundColor, MobileChatTheme.lightPage);
    expect(light.cardColor, MobileChatTheme.lightSurface);
    expect(light.dividerColor, MobileChatTheme.lightBorder);
    expect(light.extension<MobileChatColors>()!.textStrong,
        MobileChatTheme.lightTextStrong);

    expect(dark.brightness, Brightness.dark);
    expect(dark.scaffoldBackgroundColor, MobileChatTheme.darkPage);
    expect(dark.cardColor, MobileChatTheme.darkSurface);
    expect(dark.dividerColor, MobileChatTheme.darkBorder);
    expect(dark.extension<MobileChatColors>()!.textMuted,
        MobileChatTheme.darkTextMuted);
  });

  test('MobileChatColors copyWith and lerp preserve theme values', () {
    final light = MobileChatTheme.light.extension<MobileChatColors>()!;
    final dark = MobileChatTheme.dark.extension<MobileChatColors>()!;

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
    final theme = MobileChatTheme.light;

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

  testWidgets('BuildContext extension returns MobileChatColors',
      (tester) async {
    late MobileChatColors colors;

    await tester.pumpWidget(
      MaterialApp(
        theme: MobileChatTheme.light,
        home: Builder(
          builder: (context) {
            colors = context.appColors;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(colors.page, MobileChatTheme.lightPage);
  });
}
