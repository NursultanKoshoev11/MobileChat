import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_chat/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testPhone = String.fromEnvironment(
    'TEST_AUTH_PHONE',
    defaultValue: '+996700000001',
  );
  const testCode = String.fromEnvironment(
    'TEST_AUTH_CODE',
    defaultValue: '111111',
  );
  const testDisplayName = String.fromEnvironment(
    'TEST_AUTH_DISPLAY_NAME',
    defaultValue: 'Firebase Test User',
  );

  testWidgets('Firebase Test Lab login and safe UI crawl', (tester) async {
    app.main();
    await _settle(tester, seconds: 5);

    await _loginIfNeeded(tester);

    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);

    await _openMenuAndVisit(tester, const ['Профиль']);
    await _openMenuAndVisit(tester, const ['Приглашения', 'Чакыруулар']);
    await _openMenuAndVisit(tester, const ['Мои заявки', 'Менин өтүнүчтөрүм']);
    await _openMenuAndVisit(tester, const ['Заявки админу', 'Админ өтүнүчтөрү']);
    await _openMenuAndVisit(tester, const ['Войти по коду', 'Код менен кирүү']);

    await _tapSafeTextIfVisible(tester, const [
      'Заявка на группу',
      'Топ ачууга өтүнүч',
      'Новая группа',
      'Жаңы топ',
    ]);

    await _tapSafeVisibleControls(tester, maxTaps: 8);

    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  Future<void> _loginIfNeeded(WidgetTester tester) async {
    if (find.byType(EditableText).evaluate().isEmpty) return;

    await _enterEditableTextAt(tester, 0, testPhone);
    await _tapPrimaryButton(tester);
    await _settle(tester, seconds: 5);

    if (find.byType(EditableText).evaluate().isEmpty) return;

    await _enterFirstEmptyEditableText(tester, testCode);

    final editableCount = find.byType(EditableText).evaluate().length;
    if (editableCount >= 3) {
      await _enterEditableTextAt(tester, 2, testDisplayName);
    }

    await _tapPrimaryButton(tester);
    await _settle(tester, seconds: 8);
  }
}

Future<void> _settle(WidgetTester tester, {int seconds = 2}) async {
  await tester.pump(Duration(seconds: seconds));
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
  } catch (_) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _enterFirstEmptyEditableText(WidgetTester tester, String value) async {
  final fields = find.byType(EditableText);
  final count = fields.evaluate().length;
  for (var i = 0; i < count; i++) {
    final widget = tester.widget<EditableText>(fields.at(i));
    if (widget.controller.text.trim().isEmpty) {
      await _enterEditableTextAt(tester, i, value);
      return;
    }
  }
  if (count > 1) await _enterEditableTextAt(tester, 1, value);
}

Future<void> _enterEditableTextAt(WidgetTester tester, int index, String value) async {
  final fields = find.byType(EditableText);
  if (fields.evaluate().length <= index) return;
  final finder = fields.at(index);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(finder, value);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapPrimaryButton(WidgetTester tester) async {
  final candidates = <Finder>[
    find.byType(FilledButton),
    find.byType(ElevatedButton),
    find.byType(OutlinedButton),
    find.byType(TextButton),
  ];

  for (final finder in candidates) {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first, warnIfMissed: false);
      await _settle(tester, seconds: 2);
      return;
    }
  }
}

Future<void> _openMenuAndVisit(WidgetTester tester, List<String> labels) async {
  await _openMainMenu(tester);
  final tapped = await _tapSafeTextIfVisible(tester, labels, goBackAfterTap: true);
  if (!tapped) await _safeBack(tester);
  await _settle(tester, seconds: 2);
}

Future<void> _openMainMenu(WidgetTester tester) async {
  final icons = find.byType(IconButton);
  if (icons.evaluate().isEmpty) return;
  await tester.tap(icons.last, warnIfMissed: false);
  await _settle(tester, seconds: 2);
}

Future<bool> _tapSafeTextIfVisible(
  WidgetTester tester,
  List<String> labels, {
  bool goBackAfterTap = true,
}) async {
  for (final label in labels) {
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) continue;
    if (_isUnsafeLabel(label)) continue;
    await tester.tap(finder.first, warnIfMissed: false);
    await _settle(tester, seconds: 3);
    if (goBackAfterTap) await _safeBack(tester);
    return true;
  }
  return false;
}

Future<void> _tapSafeVisibleControls(WidgetTester tester, {int maxTaps = 8}) async {
  var taps = 0;
  final candidates = <Finder Function()>[
    () => find.byType(FloatingActionButton),
    () => find.byType(FilledButton),
    () => find.byType(ElevatedButton),
    () => find.byType(OutlinedButton),
    () => find.byType(TextButton),
    () => find.byType(IconButton),
  ];

  for (final buildFinder in candidates) {
    final count = buildFinder().evaluate().length;
    for (var i = 0; i < count && taps < maxTaps; i++) {
      final current = buildFinder();
      if (current.evaluate().length <= i) break;
      final target = current.at(i);
      final label = _textInside(tester, target);
      if (_isUnsafeLabel(label)) continue;
      try {
        await tester.ensureVisible(target);
      } catch (_) {
        // Some controls are already visible or not scrollable.
      }
      await tester.tap(target, warnIfMissed: false);
      taps++;
      await _settle(tester, seconds: 2);
      await _closeTransientSurfaceIfOpen(tester);
    }
  }
}

String _textInside(WidgetTester tester, Finder finder) {
  final elements = finder.evaluate().toList();
  if (elements.isEmpty) return '';
  final buffer = StringBuffer();

  void collect(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      final value = widget.data ?? widget.textSpan?.toPlainText();
      if (value != null) buffer.write(' $value');
    }
    if (widget is Tooltip) {
      buffer.write(' ${widget.message}');
    }
    element.visitChildren(collect);
  }

  collect(elements.first);
  return buffer.toString();
}

bool _isUnsafeLabel(String value) {
  final lower = value.toLowerCase();
  const unsafeTokens = [
    'logout',
    'log out',
    'delete',
    'remove',
    'leave',
    'reject',
    'approve',
    'save',
    'submit',
    'send',
    'create',
    'join',
    'invite',
    'выйти',
    'удал',
    'отклон',
    'одобр',
    'сохран',
    'созда',
    'отправ',
    'войти по коду',
    'приглас',
    'чыгуу',
    'өчүр',
    'жөнөт',
    'сактоо',
    'кошулуу',
    'код менен кирүү',
  ];
  return unsafeTokens.any(lower.contains);
}

Future<void> _closeTransientSurfaceIfOpen(WidgetTester tester) async {
  final hasDialog = find.byType(AlertDialog).evaluate().isNotEmpty;
  final hasBottomSheet = find.byType(BottomSheet).evaluate().isNotEmpty;
  if (hasDialog || hasBottomSheet) await _safeBack(tester);
}

Future<void> _safeBack(WidgetTester tester) async {
  try {
    await tester.pageBack();
    await _settle(tester, seconds: 2);
  } catch (_) {
    await tester.pump(const Duration(seconds: 1));
  }
}
