import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koom/app/app.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/models.dart';
import 'package:koom/data/safety.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/features/profile/profile_screen.dart';
import 'package:koom/shared/ui_helpers.dart';

const _session = {
  'access_token': 'access',
  'refresh_token': 'refresh',
  'user': {'id': 'U-1', 'display_name': 'Tester'},
};

Future<ApiClient> _signedInClient() async {
  FlutterSecureStorage.setMockInitialValues({});
  const store = SessionStore();
  await store.save(AppSession.fromJson(_session));
  return ApiClient(baseUrl: 'https://koom.example', sessionStore: store);
}

void main() {
  group('logout', () {
    test('clears the local session and does not throw when offline', () async {
      final api = await _signedInClient();
      final requests = <String>[];
      await http.runWithClient(
        () => api.logout(),
        () => MockClient((request) async {
          requests.add(request.url.path);
          throw const SocketException('offline');
        }),
      );
      expect(requests, ['/api/auth/logout']);
      expect(await api.sessionStore.read(), isNull);
    });

    test('clears the local session when the server answers 500', () async {
      final api = await _signedInClient();
      await http.runWithClient(
        () => api.logout(),
        () => MockClient((_) async => http.Response('oops', 500)),
      );
      expect(await api.sessionStore.read(), isNull);
    });

    test('runLogoutSteps keeps going after a failing or hanging step',
        () async {
      final ran = <int>[];
      await runLogoutSteps(
        [
          () async => throw Exception('no network'),
          () async => ran.add(2),
          () => Future<void>.delayed(const Duration(seconds: 5)),
          () async => ran.add(4),
        ],
        timeout: const Duration(milliseconds: 50),
      );
      expect(ran, [2, 4]);
    });
  });

  group('logout on all devices', () {
    test('calls POST /api/auth/logout-all then clears the session', () async {
      final api = await _signedInClient();
      final requests = <String>[];
      await http.runWithClient(
        () => api.logoutAllDevices(),
        () => MockClient((request) async {
          requests.add('${request.method} ${request.url.path} '
              '${request.headers['Authorization']}');
          return http.Response('', 204);
        }),
      );
      expect(requests, ['POST /api/auth/logout-all Bearer access']);
      expect(await api.sessionStore.read(), isNull);
    });

    test('older servers (404 without JSON) report the feature as unavailable '
        'and keep the user signed in', () async {
      final api = await _signedInClient();
      await expectLater(
        http.runWithClient(
          () => api.logoutAllDevices(),
          () => MockClient((_) async => http.Response('404 page not found', 404)),
        ),
        throwsA(isA<FeatureUnavailableException>()),
      );
      expect(await api.sessionStore.read(), isNotNull);
    });

    test('a JSON 404 from a handler is not treated as a missing route', () {
      expect(
        isMissingRouteError(
          const ApiException('group not found', statusCode: 404),
        ),
        isFalse,
      );
      expect(
        isMissingRouteError(
          const ApiException('Server error 405', statusCode: 405),
        ),
        isTrue,
      );
    });

    testWidgets('profile action confirms, then signs out everywhere',
        (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      var calls = 0;
      await tester.pumpWidget(
        AppAppearanceScope(
          controller: AppAppearanceController(),
          child: AppLanguageScope(
            controller: AppLanguageController(),
            child: MaterialApp(
              theme: KoomTheme.light,
              home: ProfileScreen(
                api: ApiClient(
                  baseUrl: 'https://koom.example',
                  sessionStore: const SessionStore(),
                ),
                user: UserProfile.fromJson(
                  (_session['user'] as Map).cast<String, dynamic>(),
                ),
                onAccountDeleted: () async {},
                onLogoutAllDevices: () async => calls++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('profile_logout_all_devices'));
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Выйти на всех устройствах'), findsWidgets);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Выйти на всех устройствах?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(calls, 0);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm_logout_all_devices')));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });
  });

  testWidgets('feature-unavailable errors are localized', (tester) async {
    late String ru;
    await tester.pumpWidget(
      AppLanguageScope(
        controller: AppLanguageController(),
        child: MaterialApp(
          home: Builder(builder: (context) {
            ru = localizedMessage(
              context,
              const FeatureUnavailableException().toString(),
            );
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(ru, contains('пока недоступна'));
    expect(jsonEncode(ru), isNot(contains('Feature')));
  });
}
