import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'group_statistics.dart';
import 'models.dart';
import 'public_request.dart';
import 'session_store.dart';

class PublicRequestsApi {
  PublicRequestsApi({required this.baseUrl, required this.sessionStore});

  final String baseUrl;
  final SessionStore sessionStore;
  static const Duration _timeout = Duration(seconds: 15);

  Future<PublicRequest> createRequest({required String groupId, required String type, required String interactionMode, required String title, required String body}) async {
    final response = await _send('POST', '/api/groups/$groupId/requests', body: {
      'request_type': type,
      'interaction_mode': interactionMode,
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

  Future<GroupStatistics> fetchStatistics(String groupId, {String period = 'month', String granularity = 'day', DateTime? from, DateTime? to}) async {
    final query = <String, String>{
      'period': period,
      'granularity': granularity,
    };
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();
    final response = await _send('GET', '/api/groups/$groupId/statistics', query: query);
    return GroupStatistics.fromJson(response as Map<String, dynamic>);
  }

  Future<void> support(String requestId) async {
    await _send('POST', '/api/requests/$requestId/support');
  }

  Future<void> oppose(String requestId) async {
    await _send('POST', '/api/requests/$requestId/oppose');
  }

  Future<void> clearVote(String requestId) async {
    await _send('DELETE', '/api/requests/$requestId/vote');
  }

  Future<List<PublicRequestComment>> listComments(String requestId) async {
    final response = await _send('GET', '/api/requests/$requestId/comments');
    return (response as List<dynamic>).map((item) => PublicRequestComment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<PublicRequestComment> addComment({required String requestId, required String body}) async {
    final response = await _send('POST', '/api/requests/$requestId/comments', body: {'body': body});
    return PublicRequestComment.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteComment(String commentId) async {
    await _send('DELETE', '/api/requests/comments/$commentId');
  }

  Future<void> hideRequest(String requestId) async {
    await _send('POST', '/api/requests/$requestId/hide');
  }

  Future<void> updateStatus({required String requestId, required String status}) async {
    await _send('POST', '/api/requests/$requestId/status', body: {'status': status});
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool retrying = false,
  }) async {
    final session = await sessionStore.read();
    if (session == null) throw const ApiException('Session expired. Please sign in again.');

    final uri = Uri.parse(baseUrl).replace(path: path, queryParameters: query);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };

    try {
      late final http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(_timeout);
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers).timeout(_timeout);
      } else {
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
      }

      if (response.statusCode == 401 && !retrying) {
        final refreshed = await _refreshSession();
        if (refreshed) {
          return _send(method, path, query: query, body: body, retrying: true);
        }
      }
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('Connection timed out. Please try again.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Network error: $error');
    }
  }

  Future<bool> _refreshSession() async {
    final session = await sessionStore.read();
    if (session == null || session.refreshToken.isEmpty) return false;

    final uri = Uri.parse(baseUrl).replace(path: '/api/auth/refresh');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': session.refreshToken}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await sessionStore.clear();
      return false;
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    await sessionStore.save(AppSession.fromJson(decoded));
    return true;
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
