import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'public_request.dart';
import 'session_store.dart';

class PublicRequestsApi {
  PublicRequestsApi({required this.baseUrl, required this.sessionStore});

  final String baseUrl;
  final SessionStore sessionStore;
  static const Duration _timeout = Duration(seconds: 15);

  Future<PublicRequest> createRequest({required String groupId, required String type, required String title, required String body}) async {
    final response = await _send('POST', '/api/groups/$groupId/requests', body: {
      'request_type': type,
      'title': title,
      'body': body,
    });
    return PublicRequest.fromJson(response as Map<String, dynamic>);
  }

  Future<List<PublicRequest>> listRequests(String groupId, {bool mineOnly = false}) async {
    final query = <String, String>{'limit': '50'};
    if (mineOnly) query['mine'] = 'true';
    final response = await _send('GET', '/api/groups/$groupId/requests', query: query);
    return (response as List<dynamic>).map((item) => PublicRequest.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> support(String requestId) async {
    await _send('POST', '/api/requests/$requestId/support');
  }

  Future<void> oppose(String requestId) async {
    await _send('POST', '/api/requests/$requestId/oppose');
  }

  Future<List<PublicRequestComment>> listComments(String requestId) async {
    final response = await _send('GET', '/api/requests/$requestId/comments');
    return (response as List<dynamic>).map((item) => PublicRequestComment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<PublicRequestComment> addComment({required String requestId, required String body}) async {
    final response = await _send('POST', '/api/requests/$requestId/comments', body: {'body': body});
    return PublicRequestComment.fromJson(response as Map<String, dynamic>);
  }

  Future<void> updateStatus({required String requestId, required String status}) async {
    await _send('POST', '/api/requests/$requestId/status', body: {'status': status});
  }

  Future<dynamic> _send(String method, String path, {Map<String, String>? query, Map<String, dynamic>? body}) async {
    final session = await sessionStore.read();
    if (session == null) throw const ApiException('Session expired. Please sign in again.');

    final uri = Uri.parse(baseUrl).replace(path: path, queryParameters: query);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };

    try {
      final response = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(_timeout)
          : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('Connection timed out. Please try again.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Network error: $error');
    }
  }

  dynamic _decode(http.Response response) {
    final text = response.body.trim();
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      throw ApiException(decoded['error'] as String);
    }
    throw ApiException('Server error ${response.statusCode}');
  }
}
