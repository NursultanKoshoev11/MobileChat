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

/// The server stopped returning `account_exists` from request-code (it would
/// expose which numbers are registered), so the app cannot tell a returning
/// user from a new one. Regression: returning users were blocked until they
/// typed a name the server then ignored.
class _FakeAuthApi extends ApiClient {
  _FakeAuthApi()
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  final verifiedNames = <String>[];

  @override
  Future<RequestCodeResult> requestPhoneCode(String mobile) async =>
      RequestCodeResult.fromJson({'status': 'code_sent'});

  @override
  Future<AppSession> verifyPhoneCode({
    required String mobile,
    required String code,
    required String displayName,
  }) async {
    verifiedNames.add(displayName);
    if (displayName.isEmpty && mobile.endsWith('999')) {
      throw const ApiException(
        'display_name is required for new account',
        statusCode: 400,
      );
    }
    return AppSession.fromJson({
      'access_token': 'a',
      'refresh_token': 'r',
      'user': {'id': 'U-1', 'display_name': 'Returning User'},
    });
  }
}

Widget _harness(Widget child) {
  return AppAppearanceScope(
    controller: AppAppearanceController(),
    child: AppLanguageScope(
      controller: AppLanguageController(),
      child: MaterialApp(theme: KoomTheme.light, home: child),
    ),
  );
}

Future<void> _enterCode(
  WidgetTester tester,
  _FakeAuthApi api,
  String mobile,
  List<AppSession> sessions,
) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_harness(PhoneAuthScreen(
    api: api,
    onAuthenticated: (session) async => sessions.add(session),
  )));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('auth_mobile_field')), mobile);
  await tester.tap(find.byKey(const ValueKey('terms_accept_checkbox')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('auth_code_field')), '123456');
  await tester.pump();
}

void main() {
  testWidgets('returning user can sign in without typing a name',
      (tester) async {
    final api = _FakeAuthApi();
    final sessions = <AppSession>[];
    await _enterCode(tester, api, '700123456', sessions);

    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(api.verifiedNames, ['']);
    expect(sessions, hasLength(1));
    expect(find.byKey(const ValueKey('auth_display_name_field')), findsNothing);
    expect(find.text('Для нового аккаунта нужно указать имя'), findsNothing);
  });

  testWidgets('new account without a name shows the server requirement',
      (tester) async {
    final api = _FakeAuthApi();
    final sessions = <AppSession>[];
    await _enterCode(tester, api, '700123999', sessions);

    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(sessions, isEmpty);
    expect(find.byKey(const ValueKey('auth_display_name_field')), findsOneWidget);
    expect(find.text('Для нового аккаунта нужно указать имя'), findsOneWidget);
  });

  testWidgets('a one-letter name is still rejected locally', (tester) async {
    final api = _FakeAuthApi();
    final sessions = <AppSession>[];
    await _enterCode(tester, api, '700123999', sessions);
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('auth_display_name_field')), 'A');
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pumpAndSettle();

    expect(api.verifiedNames, ['']);
    expect(find.text('Имя должно содержать от 2 до 40 символов'), findsOneWidget);
  });
}
