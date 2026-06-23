import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'group_statistics.dart';
import 'models.dart';
import 'public_request.dart';
import 'session_store.dart';
import 'network_guard.dart';
import 'offline_outbox.dart';
import 'moderation.dart';

export 'moderation.dart';

class PublicRequestsApi {
  PublicRequestsApi({required this.baseUrl, required this.sessionStore});

  final String baseUrl;
  final SessionStore sessionStore;
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxAttempts = 3;
  final NetworkGuard _networkGuard = NetworkGuard();

  Future<PublicRequest> createRequest({
    required String groupId,
    required String type,
    required String interactionMode,
    required String title,
    required String body,
  }) async {
    final response = await _send(
      'POST',
      '/api/groups/$groupId/requests',
      body: {
        'request_type': type,
        'interaction_mode': interactionMode,
        'title': title,
        'body': body,
      },
    );
    final payload = response as Map<String, dynamic>;
    if (payload['status'] == 'pending_review') {
      throw const ModerationPendingException('\u041f\u0443\u0431\u043b\u0438\u043a\u0430\u0446\u0438\u044f \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0430 \u043d\u0430 \u043f\u0440\u043e\u0432\u0435\u0440\u043a\u0443 \u0430\u0434\u043c\u0438\u043d\u0443.');
    }
    return PublicRequest.fromJson(payload);
  }

  Future<Map<String, dynamic>> uploadPublicRequestFile({
    required String groupId,
    required String kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final session = await sessionStore.read();
    if (session == null) {
      throw const ApiException('Session expired. Please sign in again.');
    }
    final uri = Uri.parse(baseUrl).replace(path: '/api/groups/$groupId/files');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..fields['kind'] = kind
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Upload failed: ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final url = decoded['url'] as String? ?? '';
    if (url.startsWith('/')) {
      decoded['url'] = Uri.parse(baseUrl).replace(path: url).toString();
    }
    return decoded;
  }

  Future<List<PublicRequest>> listRequests(
    String groupId, {
    bool mineOnly = false,
  }) async {
    final query = <String, String>{'limit': '50'};
    if (mineOnly) query['mine'] = 'true';
    final response = await _send(
      'GET',
      '/api/groups/$groupId/requests',
      query: query,
    );
    return (response as List<dynamic>)
        .map((item) => PublicRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ContentModerationItem>> listModerationItems(
    String groupId, {
    String status = 'pending',
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (status.trim().isNotEmpty) query['status'] = status.trim();
    final response = await _send(
      'GET',
      '/api/groups/$groupId/moderation/items',
      query: query,
    );
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ContentModerationItem.fromJson)
        .toList();
  }

  Future<int> countModerationItems(
    String groupId, {
    String status = 'pending',
  }) async {
    final query = <String, String>{};
    if (status.trim().isNotEmpty) query['status'] = status.trim();
    final response = await _send(
      'GET',
      '/api/groups/$groupId/moderation/items/count',
      query: query,
    );
    if (response is Map<String, dynamic>) {
      return response['count'] as int? ?? 0;
    }
    return 0;
  }

  Future<void> approveModerationItem(String itemId) async {
    await _send('POST', '/api/moderation/items/$itemId/approve');
  }

  Future<void> rejectModerationItem(String itemId) async {
    await _send('POST', '/api/moderation/items/$itemId/reject');
  }

  Future<void> leaveGroup(String groupId) async {
    await _send('DELETE', '/api/groups/$groupId/leave');
  }

  Future<ChatGroup> ensureGroupInviteCode(String groupId) async {
    final response = await _send('POST', '/api/groups/$groupId/invite-code');
    return ChatGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<List<GroupMember>> listGroupMembers(String groupId) async {
    final response = await _send('GET', '/api/groups/$groupId/members');
    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map(GroupMember.fromJson)
        .toList();
  }

  Future<GroupMember> updateGroupMemberRole({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    final response = await _send(
      'POST',
      '/api/groups/$groupId/members/$userId/role',
      body: {'role': role},
    );
    return GroupMember.fromJson(response as Map<String, dynamic>);
  }

  Future<GroupMember> updateGroupMemberRoleByPhone({
    required String groupId,
    required String phone,
    required String role,
  }) async {
    final response = await _send(
      'POST',
      '/api/groups/$groupId/members/role-by-phone',
      body: {'phone': phone, 'role': role},
    );
    return GroupMember.fromJson(response as Map<String, dynamic>);
  }

  Future<void> setCommentMute({
    required String groupId,
    required String userId,
    required int durationMinutes,
    String reason = '',
  }) async {
    await _send(
      'POST',
      '/api/groups/$groupId/comment-mutes/$userId',
      body: {'duration_minutes': durationMinutes, 'reason': reason},
    );
  }

  Future<void> clearCommentMute({
    required String groupId,
    required String userId,
  }) async {
    await _send('POST', '/api/groups/$groupId/comment-mutes/$userId/clear');
  }

  Future<void> setCommentMuteByPhone({
    required String groupId,
    required String phone,
    required int durationMinutes,
    String reason = '',
  }) async {
    await _send(
      'POST',
      '/api/groups/$groupId/comment-mutes/by-phone',
      body: {
        'phone': phone,
        'duration_minutes': durationMinutes,
        'reason': reason
      },
    );
  }

  Future<void> clearCommentMuteByPhone({
    required String groupId,
    required String phone,
  }) async {
    await _send(
      'POST',
      '/api/groups/$groupId/comment-mutes/unmute-by-phone',
      body: {'phone': phone},
    );
  }

  Future<GroupStatistics> fetchStatistics(
    String groupId, {
    String period = 'month',
    String granularity = 'day',
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{
      'period': period,
      'granularity': granularity,
    };
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();
    final response = await _send(
      'GET',
      '/api/groups/$groupId/statistics',
      query: query,
    );
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
    return (response as List<dynamic>)
        .map(
          (item) => PublicRequestComment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<PublicRequestComment> addComment({
    required String requestId,
    required String body,
  }) async {
    final response = await _send(
      'POST',
      '/api/requests/$requestId/comments',
      body: {'body': body},
    );
    final payload = response as Map<String, dynamic>;
    if (payload['status'] == 'pending_review') {
      throw const ModerationPendingException('Комментарий отправлен на проверку администратору.');
    }
    return PublicRequestComment.fromJson(payload);
  }

  Future<void> deleteComment(String commentId) async {
    await _send('DELETE', '/api/requests/comments/$commentId');
  }

  Future<void> hideRequest(String requestId) async {
    await _send('POST', '/api/requests/$requestId/hide');
  }

  Future<void> updateStatus({
    required String requestId,
    required String status,
  }) async {
    await _send(
      'POST',
      '/api/requests/$requestId/status',
      body: {'status': status},
    );
  }

  Future<void> flushOfflinePublicRequests() async {
    await OfflineOutbox.instance.flushPublicRequests((draft) async {
      await createRequest(
        groupId: draft.groupId,
        type: draft.requestType,
        interactionMode: draft.interactionMode,
        title: draft.title,
        body: draft.body,
      );
    });
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool retrying = false,
    int attempt = 0,
  }) async {
    _networkGuard.ensureAllowed();
    final session = await sessionStore.read();
    if (session == null)
      throw const ApiException('Session expired. Please sign in again.');

    final uri = Uri.parse(baseUrl).replace(path: path, queryParameters: query);
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };

    try {
      late final http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(_timeout);
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers).timeout(_timeout);
      } else {
        response = await http
            .post(uri, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(_timeout);
      }

      if (_networkGuard.isRetryableStatus(response.statusCode) && attempt + 1 < _maxAttempts) {
        _networkGuard.recordFailure();
        await _networkGuard.waitBeforeRetry(attempt);
        return _send(method, path, query: query, body: body, retrying: true, attempt: attempt + 1);
      }

      if (response.statusCode == 401 && !retrying) {
        final refreshed = await _refreshSession();
        if (refreshed) {
          return _send(method, path, query: query, body: body, retrying: true, attempt: attempt + 1);
        }
      }
      final decoded = _decode(response);
      _networkGuard.recordSuccess();
      return decoded;
    } on TimeoutException {
      _networkGuard.recordFailure();
      if (attempt + 1 < _maxAttempts) {
        await _networkGuard.waitBeforeRetry(attempt);
        return _send(method, path, query: query, body: body, retrying: true, attempt: attempt + 1);
      }
      throw const ApiException('Connection timed out. Please try again.');
    } on CircuitOpenException catch (error) {
      throw ApiException(error.message);
    } catch (error) {
      if (error is ApiException) rethrow;
      _networkGuard.recordFailure();
      if (attempt + 1 < _maxAttempts) {
        await _networkGuard.waitBeforeRetry(attempt);
        return _send(method, path, query: query, body: body, retrying: true, attempt: attempt + 1);
      }
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
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode({'refresh_token': session.refreshToken}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await sessionStore.clear();
      return false;
    }
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    await sessionStore.save(AppSession.fromJson(decoded));
    return true;
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes).trim();
    final decoded = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      throw ApiException(decoded['error'] as String);
    }
    throw ApiException('Server error ${response.statusCode}');
  }
}
