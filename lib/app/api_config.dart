import 'package:flutter/foundation.dart';

/// API base URL configured at build time via `--dart-define=API_BASE_URL=...`.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://koom.com.kg',
);

/// Whether the current build must talk to the API over HTTPS only.
/// Release and profile builds are distributed/benchmarked on real devices, so
/// both must refuse plain-text API endpoints.
bool get requiresHttpsApi => kReleaseMode || kProfileMode;

/// Throws when [baseUrl] is not a valid HTTPS URL and [enforce] is true.
void validateApiBaseUrl(String baseUrl, {bool? enforce}) {
  if (!(enforce ?? requiresHttpsApi)) return;
  final uri = Uri.tryParse(baseUrl);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw StateError(
      'Release and profile builds require a valid HTTPS API_BASE_URL.',
    );
  }
}

/// Origin (scheme://host[:port]) of [baseUrl], or null when it cannot be parsed.
String? apiOriginOf(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return uri.origin;
}

/// True when [url] is an absolute http(s) URL with exactly the same origin as
/// [baseUrl]. Only such URLs may receive the user's bearer token.
bool isSameApiOrigin(String url, {String baseUrl = kApiBaseUrl}) {
  final expected = apiOriginOf(baseUrl);
  if (expected == null) return false;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  if (uri.userInfo.isNotEmpty) return false;
  return uri.origin == expected;
}

/// Public legal pages, built from the configured API origin.
Uri privacyPolicyUri({String baseUrl = kApiBaseUrl}) =>
    _legalUri('/privacy', baseUrl);

Uri termsOfUseUri({String baseUrl = kApiBaseUrl}) =>
    _legalUri('/terms', baseUrl);

Uri _legalUri(String path, String baseUrl) {
  final origin = apiOriginOf(baseUrl) ?? 'https://koom.com.kg';
  return Uri.parse(origin).replace(path: path);
}
