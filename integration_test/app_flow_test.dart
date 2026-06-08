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

  testWidgets('Firebase Test Lab login and smoke navigation flow', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _tapByTextIfExists(tester, 'RU');
    await _tapByTextIfExists(tester, 'EN');

    await _enterFirstEditableText(tester, testPhone);
    await _tapFirstButton(tester);
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _enterEmptyEditableText(tester, testCode);

    final editableCount = find.byType(EditableText).evaluate().length;
    if (editableCount >= 3) {
      await _enterEditableTextAt(tester, 2, testDisplayName);
    }

    await _tapFirstButton(tester);
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.byType(Scaffold), findsWidgets);

    await _tapAnyIcon(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await _tapAnyButton(tester);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapByTextIfExists(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isNotEmpty) {
    await tester.tap(finder.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}

Future<void> _enterFirstEditableText(WidgetTester tester, String value) async {
  await _enterEditableTextAt(tester, 0, value);
}

Future<void> _enterEmptyEditableText(WidgetTester tester, String value) async {
  final fields = find.byType(EditableText);
  for (var i = 0; i < fields.evaluate().length; i++) {
    final widget = tester.widget<EditableText>(fields.at(i));
    if (widget.controller.text.trim().isEmpty) {
      await _enterEditableTextAt(tester, i, value);
      return;
    }
  }
  await _enterEditableTextAt(tester, 1, value);
}

Future<void> _enterEditableTextAt(WidgetTester tester, int index, String value) async {
  final finder = find.byType(EditableText).at(index);
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
  await tester.enterText(finder, value);
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

Future<void> _tapFirstButton(WidgetTester tester) async {
  final filledButton = find.byType(FilledButton);
  if (filledButton.evaluate().isNotEmpty) {
    await tester.tap(filledButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return;
  }

  final elevatedButton = find.byType(ElevatedButton);
  if (elevatedButton.evaluate().isNotEmpty) {
    await tester.tap(elevatedButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return;
  }

  final textButton = find.byType(TextButton);
  if (textButton.evaluate().isNotEmpty) {
    await tester.tap(textButton.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}

Future<void> _tapAnyButton(WidgetTester tester) async {
  final buttons = [
    find.byType(FilledButton),
    find.byType(ElevatedButton),
    find.byType(OutlinedButton),
    find.byType(TextButton),
    find.byType(IconButton),
  ];

  for (final finder in buttons) {
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      return;
    }
  }
}

Future<void> _tapAnyIcon(WidgetTester tester) async {
  final icons = find.byType(IconButton);
  if (icons.evaluate().isNotEmpty) {
    await tester.tap(icons.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}
