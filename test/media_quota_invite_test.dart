import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:koom/app/localization.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/public_requests_api.dart';
import 'package:koom/features/groups/group_qr_scan_screen.dart';
import 'package:koom/features/public_requests/public_request_media_widgets.dart';
import 'package:koom/shared/ui_helpers.dart';

Widget _app(Widget child, {AppLanguage language = AppLanguage.ru}) {
  final controller = AppLanguageController()..setLanguage(language);
  return AppLanguageScope(
    controller: controller,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('upload quota (429)', () {
    final response = http.Response(
      '{"error":"daily upload quota exceeded","code":"upload_quota_exceeded",'
      '"limit_bytes":104857600}',
      429,
    );

    test('upload errors keep the server code', () {
      final error = uploadErrorFromResponse(response);
      expect(error.statusCode, 429);
      expect(error.message, 'upload_quota_exceeded');
      expect(isUploadQuotaError(error), isTrue);
      expect(
        isUploadQuotaError(const ApiException('Upload failed: 500', statusCode: 500)),
        isFalse,
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('is shown localized (${language.name})', (tester) async {
        late String byCode;
        late String byText;
        await tester.pumpWidget(_app(
          Builder(builder: (context) {
            byCode = localizedMessage(context, 'upload_quota_exceeded');
            byText = localizedMessage(context, 'daily upload quota exceeded');
            return const SizedBox();
          }),
          language: language,
        ));
        final expected = AppText(language).uploadQuotaExceeded;
        expect(byCode, expected);
        expect(byText, expected);
      });
    }
  });

  testWidgets('missing media shows a neutral placeholder', (tester) async {
    await tester.pumpWidget(_app(const MediaUnavailablePlaceholder(
      width: 92,
      height: 92,
      showLabel: true,
    )));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('Медиа недоступно'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('access sheet code/QR value of a new code survives the scanner', () {
    // groupAccessQrValue falls back to the formatted code when the group has
    // no qr_pass (the group list never returns one).
    const formatted = 'K7M2P-QX9ZT';
    expect(formatGroupInviteCode('k7m2pqx9zt'), formatted);
    expect(extractInviteCode(formatted, baseUrl: 'https://api.koom.test'),
        'K7M2PQX9ZT');
    expect(formatGroupInviteCode(extractInviteCode(formatted,
        baseUrl: 'https://api.koom.test')!), formatted);
    expect(formatGroupInviteCode('ABC234'), 'ABC-234');
  });
}
