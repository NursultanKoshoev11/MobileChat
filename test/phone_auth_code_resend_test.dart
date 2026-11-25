import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/shared/koom_ui.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/models.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/features/auth/phone_auth_screen.dart';

/// Records every request-code call and can answer the Nth one with a server
/// error, so the screen's handling of the real rate-limit replies is tested
/// against the wording the server actually sends.
class _FakeCodeApi extends ApiClient {
  _FakeCodeApi({this.failures = const <String>[]})
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  /// One entry per request; an empty string means "answer normally".
  final List<String> failures;
  final requested = <String>[];

  @override
  Future<RequestCodeResult> requestPhoneCode(String mobile) async {
    requested.add(mobile);
    final index = requested.length - 1;
    if (index < failures.length && failures[index].isNotEmpty) {
      throw ApiException(failures[index], statusCode: 429);
    }
    return RequestCodeResult.fromJson({'status': 'code_sent'});
  }

  @override
  Future<AppSession> verifyPhoneCode({
    required String mobile,
    required String code,
    required String displayName,
  }) async {
    return AppSession.fromJson({
      'access_token': 'a',
      'refresh_token': 'r',
      'user': {'id': 'U-1', 'display_name': 'Test'},
    });
  }
}

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1, 12);

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

Finder get _mobileField => find.byKey(const ValueKey('auth_mobile_field'));
Finder get _codeField => find.byKey(const ValueKey('auth_code_field'));
Finder get _submit => find.byKey(const ValueKey('auth_submit_button'));
Finder get _terms => find.byKey(const ValueKey('terms_accept_checkbox'));
Finder get _resend => find.byKey(const ValueKey('auth_resend_button'));
Finder get _countdown => find.byKey(const ValueKey('auth_resend_countdown'));

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeCodeApi api,
  _Clock? clock,
  AppLanguage language = AppLanguage.ru,
  ThemeData? theme,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final languageController = AppLanguageController();
  languageController.setLanguage(language);
  addTearDown(languageController.dispose);

  await tester.pumpWidget(
    AppAppearanceScope(
      controller: AppAppearanceController(),
      child: AppLanguageScope(
        controller: languageController,
        child: MaterialApp(
          theme: theme ?? KoomTheme.light,
          home: PhoneAuthScreen(
            api: api,
            clock: (clock ?? _Clock()).call,
            onAuthenticated: (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Phone number, terms, submit: leaves the screen on the code step with the
/// countdown freshly started.
Future<void> _requestCode(WidgetTester tester) async {
  await tester.enterText(_mobileField, '700123456');
  await tester.pump();
  await tester.tap(_terms);
  await tester.pump();
  await tester.tap(_submit);
  await tester.pumpAndSettle();
}

Future<void> _runCountdownDown(WidgetTester tester) async {
  for (var tick = 0; tick < kPhoneCodeResendCountdown.inSeconds; tick++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  final ru = AppText(AppLanguage.ru);
  final ky = AppText(AppLanguage.ky);

  group('request-code rate limits mirror the server', () {
    final start = DateTime.utc(2026, 1, 1, 12);

    test('a fresh number may ask for a code', () {
      expect(phoneCodeRequestRefusal(const <DateTime>[], start), isNull);
    });

    test('a second code within 30 seconds is refused', () {
      expect(
        phoneCodeRequestRefusal(
          [start.subtract(const Duration(seconds: 29))],
          start,
        ),
        kCodeRequestTooSoonMessage,
      );
    });

    test('a second code after 30 seconds goes out', () {
      expect(
        phoneCodeRequestRefusal(
          [start.subtract(const Duration(seconds: 31))],
          start,
        ),
        isNull,
      );
    });

    test('a fourth code in ten minutes is refused', () {
      final sent = [
        start.subtract(const Duration(minutes: 9)),
        start.subtract(const Duration(minutes: 5)),
        start.subtract(const Duration(minutes: 1)),
      ];
      expect(
        phoneCodeRequestRefusal(sent, start),
        kCodeRequestQuotaMessage,
      );
      // The same three, but older than the ten-minute window.
      final old = sent
          .map((at) => at.subtract(const Duration(minutes: 20)))
          .toList();
      expect(phoneCodeRequestRefusal(old, start), isNull);
    });

    test('a ninth code in twenty-four hours is refused', () {
      final sent = List<DateTime>.generate(
        8,
        (index) => start.subtract(Duration(minutes: 20 * (index + 1))),
      ).reversed.toList();
      expect(phoneCodeRequestRefusal(sent, start), kCodeRequestQuotaMessage);
      expect(
        phoneCodeRequestRefusal(
          sent.map((at) => at.subtract(const Duration(days: 2))).toList(),
          start,
        ),
        isNull,
      );
    });
  });

  group('design system', () {
    testWidgets('brand, card title and card radius come from the theme',
        (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api);
      // The theme as the screen sees it: font sizes only exist once the
      // typography geometry is merged in, which Theme.of does.
      final theme = Theme.of(tester.element(find.text('Koom')));

      // No hardcoded 34/39 for the brand and no hardcoded 22 for the title.
      final brand = tester.widget<Text>(find.text('Koom')).style;
      expect(brand?.fontSize, theme.textTheme.headlineLarge?.fontSize);
      expect(brand?.fontWeight, FontWeight.w700);
      final title = tester.widget<Text>(find.text('Вход в Koom')).style;
      expect(title?.fontSize, theme.textTheme.titleLarge?.fontSize);
      expect(title?.fontWeight, FontWeight.w600);
      // The tagline used to be w800, which no heading in the system is.
      final tagline =
          tester.widget<Text>(find.text('Общение для сообществ')).style;
      expect(tagline?.fontWeight, FontWeight.w400);
      expect(tagline?.color, KoomTheme.lightTextMuted);
      // The system says 24 for cards, the screen used to say 28.
      expect(tester.widget<KoomCard>(find.byType(KoomCard)).radius,
          KoomRadii.lg);
    });

    testWidgets('the copy stack is brand, one line, then the card',
        (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api);

      expect(find.text('Общение для сообществ'), findsOneWidget);
      // The second tagline and the duplicated header brand are gone.
      expect(
        find.text('Объединяйтесь, общайтесь и принимайте решения вместе'),
        findsNothing,
      );
      expect(find.text('Koom'), findsOneWidget);
    });

    testWidgets('dark mode takes its colours from the theme extension',
        (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api, theme: KoomTheme.dark);

      expect(
        tester.widget<Text>(find.text('Koom')).style?.color,
        KoomTheme.darkTextStrong,
      );
      expect(
        tester.widget<Text>(find.text('Общение для сообществ')).style?.color,
        KoomTheme.darkTextMuted,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('autofill', () {
    testWidgets('both fields carry the hints the OS needs', (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api);

      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(
        tester.widget<TextField>(_mobileField).autofillHints,
        const <String>[AutofillHints.telephoneNumber],
      );

      await _requestCode(tester);

      expect(
        tester.widget<TextField>(_codeField).autofillHints,
        const <String>[AutofillHints.oneTimeCode],
      );
      // The group has to stay around the code step as well, otherwise the
      // platform drops the one-time-code suggestion.
      expect(find.byType(AutofillGroup), findsOneWidget);
    });

    testWidgets('an autofilled +996 700 123 456 still normalizes',
        (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api);

      // Autofill reaches the focused field as one editing update carrying the
      // whole number, country code included.
      await tester.showKeyboard(_mobileField);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '+996 700 123 456',
          selection: TextSelection.collapsed(offset: 16),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<TextField>(_mobileField).controller!.text,
        '700123456',
      );

      await tester.tap(_terms);
      await tester.pump();
      await tester.tap(_submit);
      await tester.pumpAndSettle();

      expect(api.requested, ['+996700123456']);
    });
  });

  group('resend countdown', () {
    testWidgets('starts at 60 seconds, survives a rebuild and stops at zero',
        (tester) async {
      final api = _FakeCodeApi();
      final clock = _Clock();
      await _pumpScreen(tester, api: api, clock: clock);
      await _requestCode(tester);

      expect(find.text(ru.resendCodeIn(60)), findsOneWidget);
      expect(_resend, findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(ru.resendCodeIn(59)), findsOneWidget);

      // Typing rebuilds the screen; the countdown must keep its place.
      await tester.enterText(_codeField, '12');
      await tester.pump();
      expect(find.text(ru.resendCodeIn(59)), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(ru.resendCodeIn(58)), findsOneWidget);

      await _runCountdownDown(tester);

      expect(_countdown, findsNothing);
      expect(_resend, findsOneWidget);
      expect(find.text(ru.resendCode), findsOneWidget);
      // The ticker is gone: another minute changes nothing and leaves no
      // pending timer behind.
      await tester.pump(const Duration(seconds: 60));
      expect(_resend, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the resend button is at least 48dp high', (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api);
      await _requestCode(tester);
      await _runCountdownDown(tester);

      expect(tester.getSize(_resend).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('auth_change_number_button')))
            .height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('resending asks for a new code and clears the old one',
        (tester) async {
      final api = _FakeCodeApi();
      final clock = _Clock();
      await _pumpScreen(tester, api: api, clock: clock);
      await _requestCode(tester);
      await tester.enterText(_codeField, '111111');
      await tester.pump();
      await _runCountdownDown(tester);

      clock.advance(const Duration(seconds: 61));
      await tester.tap(_resend);
      await tester.pumpAndSettle();

      expect(api.requested, ['+996700123456', '+996700123456']);
      expect(tester.widget<TextField>(_codeField).controller!.text, isEmpty);
      expect(find.text(ru.resendCodeIn(60)), findsOneWidget);
    });

    testWidgets('a server refusal shows the localized message',
        (tester) async {
      final api = _FakeCodeApi(
        failures: const ['', 'please wait before requesting another code'],
      );
      final clock = _Clock();
      await _pumpScreen(tester, api: api, clock: clock);
      await _requestCode(tester);
      await _runCountdownDown(tester);

      clock.advance(const Duration(seconds: 61));
      await tester.tap(_resend);
      await tester.pumpAndSettle();

      expect(api.requested, hasLength(2));
      expect(
        find.text('Подождите перед повторным запросом кода.'),
        findsOneWidget,
      );
    });

    testWidgets('the Kyrgyz quota refusal is surfaced before the request',
        (tester) async {
      final api = _FakeCodeApi();
      final clock = _Clock();
      await _pumpScreen(
        tester,
        api: api,
        clock: clock,
        language: AppLanguage.ky,
      );
      await _requestCode(tester);

      // Three codes inside ten minutes is the server's cap; the fourth never
      // leaves the app.
      for (var attempt = 0; attempt < 3; attempt++) {
        await _runCountdownDown(tester);
        clock.advance(const Duration(seconds: 61));
        await tester.tap(_resend);
        await tester.pumpAndSettle();
      }

      expect(api.requested, hasLength(3));
      expect(
        find.text('Код өтө көп жолу суралды. Бир аздан кийин аракет кылыңыз.'),
        findsOneWidget,
      );
      expect(find.text(ky.resendCode), findsOneWidget);
    });

    testWidgets('the countdown stops when the screen goes away',
        (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api);
      await _requestCode(tester);
      expect(find.text(ru.resendCodeIn(60)), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      // A pending timer firing against a disposed state would throw here.
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the number stops the countdown', (tester) async {
      final api = _FakeCodeApi();
      await _pumpScreen(tester, api: api);
      await _requestCode(tester);

      await tester.tap(find.byKey(const ValueKey('auth_change_number_button')));
      await tester.pumpAndSettle();

      expect(_countdown, findsNothing);
      expect(_resend, findsNothing);
      expect(_mobileField, findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });
  });
}
