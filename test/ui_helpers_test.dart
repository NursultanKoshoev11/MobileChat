import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/app/localization.dart';
import 'package:mobile_chat/app/theme.dart';
import 'package:mobile_chat/shared/ui_helpers.dart';

void main() {
  Future<String> localized(
    WidgetTester tester,
    AppLanguage language,
    String message,
  ) async {
    var result = '';
    final controller = AppLanguageController()..setLanguage(language);

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(
          theme: MobileChatTheme.light,
          home: Builder(
            builder: (context) {
              result = localizedMessage(context, message);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    return result;
  }

  test('avatarText and compactTime handle simple formatting', () {
    expect(avatarText(' mobile'), 'M');
    expect(avatarText(''), '?');
    expect(compactTime(DateTime(2026, 7, 1, 4, 9)), '04:09');
  });

  testWidgets('localizedMessage maps backend messages', (tester) async {
    final messages = [
      'comments are blocked until 2026-07-01T12:34:00Z',
      'comments are blocked until 2026-07-01T12:34bad',
      'comments are blocked until someday',
      'comments are blocked',
      'content is temporarily limited',
      'content is not allowed',
      'status updated',
      'comment deleted',
      'comment added',
      'request updated',
      'request sent',
      'post published',
      'invitation sent',
      'invitation accepted',
      'invitation declined',
      'session expired',
      'connection timed out',
      'network error',
      'server error',
      'mobile must be in international format',
      'code is required',
      'display_name is required',
      'display_name must be between 2 and 40',
      'invalid email or password',
      'invalid credentials',
      'unauthorized',
      'forbidden',
      'title must be between 3 and 80',
      'description must be at most 500',
      'text is required',
      'body is required',
      'body text must be between 5 and 5000 characters',
      'reason must be between 5 and 2000 characters',
      'comment must be between 1 and 1000 characters',
      'file is too large',
      'code must contain 6 digits',
      'too many code requests; try again later',
      'not found',
      'already done',
    ];

    for (final language in AppLanguage.values) {
      for (final message in messages) {
        final result = await localized(tester, language, message);
        expect(result, isNotEmpty, reason: message);
        expect(result, isNot(equals(message)), reason: message);
      }
    }
  });

  testWidgets('localizedMessage returns unknown messages unchanged',
      (tester) async {
    final result =
        await localized(tester, AppLanguage.ru, 'custom backend text');

    expect(result, 'custom backend text');
  });


  testWidgets('localizedMessage hides unknown English error details',
      (tester) async {
    final result = await localized(
      tester,
      AppLanguage.ru,
      'unexpected transport failure',
    );

    expect(result, 'Не удалось выполнить действие. Попробуйте ещё раз.');
  });

  testWidgets('showAppSnack displays a localized notice at the top',
      (tester) async {
    final controller = AppLanguageController();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(
          theme: MobileChatTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppSnack(context, 'request sent'),
                child: const Text('show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('show'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('request sent'), findsNothing);
    expect(find.text('Заявка отправлена.'), findsOneWidget);
    final noticeIcon = find.byIcon(Icons.notifications_active_rounded);
    expect(noticeIcon, findsOneWidget);
    expect(tester.getTopLeft(noticeIcon).dy, lessThan(120));

    await tester.pump(const Duration(seconds: 3));
    expect(noticeIcon, findsNothing);
  });

  testWidgets('ErrorBanner and InfoBanner render themed messages',
      (tester) async {
    final controller = AppLanguageController();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(
          theme: MobileChatTheme.light,
          darkTheme: MobileChatTheme.dark,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: Column(
              children: [
                ErrorBanner(message: 'server error'),
                InfoBanner(message: 'plain info'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.text('server error'), findsNothing);
    expect(find.text('plain info'), findsOneWidget);
    expect(ErrorBanner(message: 'raw').message, 'raw');
    expect(InfoBanner(message: 'raw').message, 'raw');
  });
}
