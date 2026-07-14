import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/app/appearance.dart';
import 'package:mobile_chat/app/localization.dart';
import 'package:mobile_chat/app/theme.dart';
import 'package:mobile_chat/shared/koom_ui.dart';

Future<void> pumpAtSize(
  WidgetTester tester,
  Size size,
  Widget child, {
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: MobileChatTheme.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('responsive action buttons stack on narrow screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(320, 568),
      Padding(
        padding: const EdgeInsets.all(16),
        child: KoomResponsiveActions(
          children: [
            OutlinedButton(
              key: const ValueKey('first_action'),
              onPressed: () {},
              child: const Text('First action'),
            ),
            FilledButton(
              key: const ValueKey('second_action'),
              onPressed: () {},
              child: const Text('Second action'),
            ),
          ],
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('first_action')));
    final second = tester.getRect(find.byKey(const ValueKey('second_action')));
    expect(second.top, greaterThan(first.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsive action buttons stay in one row on wide screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(700, 900),
      Padding(
        padding: const EdgeInsets.all(16),
        child: KoomResponsiveActions(
          children: [
            OutlinedButton(
              key: const ValueKey('first_action'),
              onPressed: () {},
              child: const Text('First action'),
            ),
            FilledButton(
              key: const ValueKey('second_action'),
              onPressed: () {},
              child: const Text('Second action'),
            ),
          ],
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('first_action')));
    final second = tester.getRect(find.byKey(const ValueKey('second_action')));
    expect(second.left, greaterThan(first.right));
    expect((second.center.dy - first.center.dy).abs(), lessThan(0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive tile grid wraps without overlap on narrow screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(320, 568),
      Padding(
        padding: const EdgeInsets.all(12),
        child: KoomAdaptiveTileGrid(
          children: List.generate(
            4,
            (index) => SizedBox(
              key: ValueKey('tile_$index'),
              height: 64,
              child: Text('Tile $index'),
            ),
          ),
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('tile_0')));
    final second = tester.getRect(find.byKey(const ValueKey('tile_1')));
    final third = tester.getRect(find.byKey(const ValueKey('tile_2')));
    expect(second.left, greaterThan(first.left));
    expect(third.top, greaterThan(first.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive tile grid uses one row when width allows it',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(700, 900),
      Padding(
        padding: const EdgeInsets.all(12),
        child: KoomAdaptiveTileGrid(
          children: List.generate(
            4,
            (index) => SizedBox(
              key: ValueKey('tile_$index'),
              height: 64,
              child: Text('Tile $index'),
            ),
          ),
        ),
      ),
    );

    final first = tester.getRect(find.byKey(const ValueKey('tile_0')));
    final fourth = tester.getRect(find.byKey(const ValueKey('tile_3')));
    expect(fourth.top, first.top);
    expect(fourth.left, greaterThan(first.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive FAB hides its label on compact screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(320, 568),
      KoomAdaptiveFab(
        onPressed: () {},
        icon: Icons.add_rounded,
        label: 'Create a new community',
      ),
    );

    expect(find.text('Create a new community'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive FAB shows its label on wide screens',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(700, 900),
      KoomAdaptiveFab(
        onPressed: () {},
        icon: Icons.add_rounded,
        label: 'Create a new community',
      ),
    );

    expect(find.text('Create a new community'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings sheet has no overflow on a small phone',
      (tester) async {
    final appearance = AppAppearanceController();
    final language = AppLanguageController();
    await tester.binding.setSurfaceSize(const Size(280, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AppAppearanceScope(
        controller: appearance,
        child: AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: MobileChatTheme.light,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(280, 520),
                textScaler: TextScaler.linear(1.35),
              ),
              child: const Scaffold(body: AppSettingsSheet()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSettingsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long status labels stay inside a narrow viewport',
      (tester) async {
    await pumpAtSize(
      tester,
      const Size(280, 520),
      const Center(
        child: KoomStatusPill(
          icon: Icons.verified_user_outlined,
          label:
              'A very long status label that must never overflow the screen',
        ),
      ),
    );

    final rect = tester.getRect(find.byType(KoomStatusPill));
    expect(rect.width, lessThanOrEqualTo(280));
    expect(tester.takeException(), isNull);
  });
}