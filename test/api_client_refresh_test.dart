import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_chat/data/api_client.dart';

void main() {
  group('isConfirmedInvalidRefreshResponse', () {
    test('accepts the current server unauthorized response', () {
      final response = http.Response(jsonEncode({'error': 'unauthorized'}), 401);

      expect(isConfirmedInvalidRefreshResponse(response), isTrue);
    });

    test('accepts an explicit invalid refresh code', () {
      final response = http.Response(
        jsonEncode({'error': 'invalid refresh token', 'code': 'invalid_refresh_token'}),
        401,
      );

      expect(isConfirmedInvalidRefreshResponse(response), isTrue);
    });

    test('does not invalidate the session for reverse proxy html', () {
      final response = http.Response('<html>unauthorized</html>', 401);

      expect(isConfirmedInvalidRefreshResponse(response), isFalse);
    });

    test('does not invalidate the session for temporary server failures', () {
      for (final status in [500, 502, 503, 504]) {
        final response = http.Response(jsonEncode({'error': 'temporary failure'}), status);
        expect(
          isConfirmedInvalidRefreshResponse(response),
          isFalse,
          reason: 'status $status must preserve the stored session',
        );
      }
    });
  });
}
