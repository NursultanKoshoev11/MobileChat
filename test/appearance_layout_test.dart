import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/app/appearance.dart';
import 'package:mobile_chat/app/localization.dart';
import 'package:mobile_chat/app/theme.dart';

void main() {
  testWidgets('settings selection keeps option text geometry stable',
      (tester) async {
    final appearance = AppAppearanceController();
    final language = AppLanguageController();

    await tester.pumpWidget(
      AppAppearanceScope(
        controller: appearance,
        child: AppLanguageScope(
          controller: language,
          child: MaterialApp(
            theme: MobileChatTheme.light,
            home: const Scaffold(body: AppSettingsSheet()),
          ),
        ),
      ),
    );

    final lightOption = find.text(language.text.lightMode);
    final darkOption = find.text(language.text.darkMode);
    expect(lightOption, findsOneWidget);
    expect(darkOption, findsOneWidget);

    final lightBefore = tester.getRect(lightOption);
    final darkBefore = tester.getRect(darkOption);

    await tester.tap(darkOption);
    await tester.pumpAndSettle();

    expect(tester.getRect(lightOption), lightBefore);
    expect(tester.getRect(darkOption), darkBefore);
  });
}