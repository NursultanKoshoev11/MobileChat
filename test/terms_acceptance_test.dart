import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/features/auth/phone_auth_screen.dart';
import 'package:koom/shared/legal_links.dart';

Widget _harness(Widget child) {
  return AppAppearanceScope(
    controller: AppAppearanceController(),
    child: AppLanguageScope(
      controller: AppLanguageController(),
      child: MaterialApp(theme: KoomTheme.light, home: child),
    ),
  );
}

ButtonStyleButton _submitButton(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('auth_submit_button')));

void main() {
  testWidgets('code cannot be requested until terms are accepted',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(PhoneAuthScreen(
      api: ApiClient(
          baseUrl: 'https://koom.com.kg', sessionStore: const SessionStore()),
      onAuthenticated: (_) async {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('auth_mobile_field')), '700123456');
    await tester.pump();

    final checkbox = find.byKey(const ValueKey('terms_accept_checkbox'));
    expect(checkbox, findsOneWidget);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(_submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('previous acceptance is restored from local storage',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues(
        {'koom_terms_accepted_v1': '2026-01-01T00:00:00.000Z'});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(PhoneAuthScreen(
      api: ApiClient(
          baseUrl: 'https://koom.com.kg', sessionStore: const SessionStore()),
      onAuthenticated: (_) async {},
    )));
    await tester.pumpAndSettle();

    final checkbox = find.byKey(const ValueKey('terms_accept_checkbox'));
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  });

  testWidgets('terms checkbox links both legal documents', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_harness(Scaffold(
      body: TermsAcceptanceCheckbox(
        value: false,
        onChanged: (_) {},
        onOpenLink: opened.add,
      ),
    )));
    expect(find.textContaining('Условия использования', findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('Политика конфиденциальности',
            findRichText: true),
        findsOneWidget);
    final richText = tester.widget<RichText>(find.descendant(
        of: find.byType(TermsAcceptanceCheckbox),
        matching: find.byType(RichText)));
    final links = <String>[];
    richText.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer != null) {
        links.add(span.text ?? '');
        (span.recognizer! as TapGestureRecognizer).onTap!();
      }
      return true;
    });
    expect(links, ['Условия использования', 'Политика конфиденциальности']);
    expect(opened.map((uri) => uri.path), ['/terms', '/privacy']);
  });
}
