import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/models.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/features/auth/phone_auth_screen.dart';
import 'package:koom/shared/phone_input.dart';

class _RecordingAuthApi extends ApiClient {
  _RecordingAuthApi()
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  final requested = <String>[];

  @override
  Future<RequestCodeResult> requestPhoneCode(String mobile) async {
    requested.add(mobile);
    return RequestCodeResult.fromJson({'status': 'code_sent'});
  }
}

const _inputs = <String, String>{
  '700123456': '700123456',
  '996700123456': '700123456',
  '+996700123456': '700123456',
  '+996 700 123 456': '700123456',
  '+996 (700) 12-34-56': '700123456',
  '00996700123456': '700123456',
  '0700123456': '700123456',
  '0 700 123 456': '700123456',
  '700 123 456': '700123456',
  '996123': '996123',
  '+996': '',
  '7001234567890': '700123456',
};

void main() {
  group('normalizeKgMobileInput', () {
    _inputs.forEach((input, expected) {
      test('"$input" -> "$expected"', () {
        expect(normalizeKgMobileInput(input), expected);
      });
    });

    test('never returns more than 9 digits', () {
      for (final input in _inputs.keys) {
        expect(normalizeKgMobileInput(input).length,
            lessThanOrEqualTo(kgMobileDigits));
      }
    });
  });

  group('KgMobileInputFormatter', () {
    const formatter = KgMobileInputFormatter();

    TextEditingValue apply(String oldText, String newText) =>
        formatter.formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newText.length),
          ),
        );

    test('handles a full pasted number', () {
      final result = apply('', '+996 700 123 456');
      expect(result.text, '700123456');
      expect(result.selection.baseOffset, 9);
    });

    test('typing 996700123456 digit by digit ends with the national part', () {
      var value = '';
      for (final char in '996700123456'.split('')) {
        value = apply(value, value + char).text;
      }
      expect(value, '700123456');
    });

    test('typing a leading 0 is dropped', () {
      var value = '';
      for (final char in '0700123456'.split('')) {
        value = apply(value, value + char).text;
      }
      expect(value, '700123456');
    });
  });

  group('phone field on PhoneAuthScreen', () {
    Future<(_RecordingAuthApi, String)> submit(WidgetTester tester, String input) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final api = _RecordingAuthApi();
      await tester.pumpWidget(
        AppAppearanceScope(
          controller: AppAppearanceController(),
          child: AppLanguageScope(
            controller: AppLanguageController(),
            child: MaterialApp(
              theme: KoomTheme.light,
              home: PhoneAuthScreen(
                api: api,
                onAuthenticated: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('auth_mobile_field')), input);
      await tester.pump();
      final shown = tester
          .widget<TextField>(find.byKey(const ValueKey('auth_mobile_field')))
          .controller!
          .text;
      await tester.tap(find.byKey(const ValueKey('terms_accept_checkbox')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
      await tester.pumpAndSettle();
      return (api, shown);
    }

    for (final input in [
      '700123456',
      '996700123456',
      '+996 700 123 456',
      '0700123456',
    ]) {
      testWidgets('"$input" requests a code for +996700123456',
          (tester) async {
        final (api, shown) = await submit(tester, input);
        expect(shown, '700123456');
        expect(api.requested, ['+996700123456']);
      });
    }

    testWidgets('pasting via the clipboard is normalized', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              inputFormatters: const [KgMobileInputFormatter()],
              maxLength: kgMobileDigits,
            ),
          ),
        ),
      );
      // A paste arrives as one edit replacing the whole selection.
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '+996 700 123 456',
          selection: TextSelection.collapsed(offset: 16),
        ),
      );
      await tester.pump();
      expect(controller.text, '700123456');
    });
  });
}
