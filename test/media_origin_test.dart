import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/api_config.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/public_requests_api.dart';
import 'package:koom/features/public_requests/public_request_media_widgets.dart';

void main() {
  const base = 'https://koom.com.kg';

  group('isSameApiOrigin', () {
    test('accepts URLs on the configured API origin', () {
      expect(
        isSameApiOrigin('https://koom.com.kg/api/public-files/G1/F1',
            baseUrl: base),
        isTrue,
      );
      expect(isSameApiOrigin('https://koom.com.kg', baseUrl: base), isTrue);
    });

    test('rejects foreign hosts, schemes, ports and userinfo tricks', () {
      for (final url in [
        'https://evil.example/api/public-files/G1/F1',
        'https://koom.com.kg.evil.example/x',
        'http://koom.com.kg/api/public-files/G1/F1',
        'https://koom.com.kg:8443/api/public-files/G1/F1',
        'https://koom.com.kg@evil.example/x',
        'https://user@koom.com.kg/x',
        '/api/public-files/G1/F1',
        '//evil.example/x',
        'ftp://koom.com.kg/x',
        'javascript:alert(1)',
        '',
      ]) {
        expect(isSameApiOrigin(url, baseUrl: base), isFalse, reason: url);
      }
    });
  });

  group('mediaAuthHeaders', () {
    test('never attaches headers (or refreshes) for a foreign origin', () async {
      final headers = await mediaAuthHeaders(
        'https://evil.example/api/public-files/G1/F1',
        baseUrl: base,
      );
      expect(headers, isNull);
    });
  });

  group('normalizeUploadedFileUrl', () {
    test('resolves relative paths against the API base', () {
      expect(
        normalizeUploadedFileUrl('/api/public-files/G1/F1', baseUrl: base),
        'https://koom.com.kg/api/public-files/G1/F1',
      );
    });

    test('keeps absolute URLs on the API origin', () {
      expect(
        normalizeUploadedFileUrl('https://koom.com.kg/api/public-files/G1/F1',
            baseUrl: base),
        'https://koom.com.kg/api/public-files/G1/F1',
      );
    });

    test('rejects foreign absolute and protocol-relative URLs', () {
      for (final url in [
        'https://evil.example/api/public-files/G1/F1',
        '//evil.example/api/public-files/G1/F1',
        'http://koom.com.kg/api/public-files/G1/F1',
      ]) {
        expect(
          () => normalizeUploadedFileUrl(url, baseUrl: base),
          throwsA(isA<ApiException>()),
          reason: url,
        );
      }
    });

    test('returns empty for an empty url', () {
      expect(normalizeUploadedFileUrl('  ', baseUrl: base), '');
    });
  });

  group('API base validation', () {
    test('enforces HTTPS when required', () {
      expect(() => validateApiBaseUrl('http://koom.com.kg', enforce: true),
          throwsStateError);
      expect(() => validateApiBaseUrl('not a url', enforce: true),
          throwsStateError);
      validateApiBaseUrl('https://koom.com.kg', enforce: true);
      validateApiBaseUrl('http://10.0.2.2:8080', enforce: false);
    });

    test('builds legal URLs from the API origin', () {
      expect(privacyPolicyUri(baseUrl: 'https://koom.com.kg/api').toString(),
          'https://koom.com.kg/privacy');
      expect(termsOfUseUri(baseUrl: base).toString(),
          'https://koom.com.kg/terms');
    });
  });
}
