import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'session_store.dart';

class SessionRefresher {
  SessionRefresher._();

  static final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

  static Future<bool> refresh({
    required String baseUrl,
    required SessionStore sessionStore,
    required Duration timeout,
  }) {
    final key = Uri.parse(baseUrl).origin;
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _refreshOnce(
      baseUrl: baseUrl,
      sessionStore: sessionStore,
      timeout: timeout,
    );
    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });
  }

  static Future<bool> _refreshOnce({
    required String baseUrl,
    required SessionStore sessionStore,
    required Duration timeout,
  }) async {
    final session = await sessionStore.read();
    if (session == null || session.refreshToken.isEmpty) return false;
    final tokenUsed = session.refreshToken;

    try {
      final uri = Uri.parse(baseUrl).replace(path: '/api/auth/refresh');
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': tokenUsed}),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final latest = await sessionStore.read();
        if (latest != null && latest.refreshToken != tokenUsed) {
          return true;
        }
        return false;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      await sessionStore.save(AppSession.fromJson(decoded));
      return true;
    } on TimeoutException {
      return false;
    } on http.ClientException {
      return false;
    } on FormatException {
      return false;
    }
  }
}
