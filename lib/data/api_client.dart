import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'group_invitation.dart';
import 'models.dart';
import 'session_store.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.sessionStore});

  final String baseUrl;
  final SessionStore sessionStore;
  static const Duration _timeout = Duration(seconds: 15);

  Future<RequestCodeResult> requestPhoneCode(String mobile) async {
    final response = await _post('/api/auth/request-code', {'mobile': mobile}, auth: false);
    return RequestCodeResult.fromJson(response as Map<String, dynamic>);
  }

  Future<AppSession> verifyPhoneCode({
    required String mobile,
    required String code,
    required String displayName,
  }) async {
    final response = await _post('/api/auth/verify-code', {
      'mobile': mobile,
      'code': code,
      'display_name': displayName,
    }, auth: false);
    final session = AppSession.fromJson(response as Map<String, dynamic>);
    await sessionStore.save(session);
    return session;
  }

  Future<void> registerPushToken({required String token, required String platform}) async {
    await _post('/api/push/register', {'token': token, 'platform': platform});
  }

  Future<void> deletePushToken({required String token, required String platform}) async {
    await _request('DELETE', '/api/push/token', body: {'token': token, 'platform': platform});
  }

  Future<List<ChatGroup>> fetchGroups() async {
    final response = await _get('/api/groups');
    return (response as List<dynamic>).map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<ChatGroup>> searchPublicGroups(String query) async {
    final response = await _get('/api/groups/search', query: {'q': query});
    return (response as List<dynamic>).map((item) => ChatGroup.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatGroup> createGroup({required String title, required String description, required String visibility}) async {
    final response = await _post('/api/groups', {
      'title': title,
      'description': description,
      'visibility': visibility,
    });
    return ChatGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<void> joinPublicGroup(String groupId) async {
    await _post('/api/groups/$groupId/join', {});
  }

  Future<ChatGroup> joinByInviteCode(String inviteCode) async {
    final response = await _post('/api/groups/join-by-code', {'invite_code': inviteCode});
    return ChatGroup.fromJson(response as Map<String, dynamic>);
  }

  Future<void> inviteUserById({required String groupId, required String targetUserId}) async {
    await _post('/api/groups/$groupId/invite-user', {'target_user_id': targetUserId});
  }

  Future<List<GroupInvitation>> fetchInvitations() async {
    final response = await _get('/api/invites');
    return (response as List<dynamic>).map((item) => GroupInvitation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> acceptInvitation(String inviteId) async {
    await _post('/api/invites/$inviteId/accept', {});
  }

  Future<void> declineInvitation(String inviteId) async {
    await _post('/api/invites/$inviteId/decline', {});
  }

  Future<List<ChatMessage>> fetchMessages(String groupId, {int limit = 50, DateTime? before}) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null) query['before'] = before.toUtc().toIso8601String();
    final response = await _get('/api/groups/$groupId/messages', query: query);
    return (response as List<dynamic>).map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> sendMessage({required String groupId, required String text}) async {
    final response = await _post('/api/groups/$groupId/messages', {'text': text});
    return ChatMessage.fromJson(response as Map<String, dynamic>);
  }

  Future<GroupCreationRequest> createGroupCreationRequest({
    required String applicantName,
    required String position,
    required String organizationName,
    required String organizationType,
    required String region,
    required String officialPhone,
    required String officialEmail,
    required String website,
    required String groupTitle,
    required String groupDescription,
    required String reason,
    required String documents,
  }) async {
    final response = await _post('/api/group-creation-requests', {
      'applicant_name': applicantName,
      'position': position,
      'organization_name': organizationName,
      'organization_type': organizationType,
      'region': region,
      'official_phone': officialPhone,
      'official_email': officialEmail,
      'website': website,
      'group_title': groupTitle,
      'group_description': groupDescription,
      'reason': reason,
      'documents': documents,
    });
    return GroupCreationRequest.fromJson(response as Map<String, dynamic>);
  }

  Future<List<GroupCreationRequest>> fetchMyGroupCreationRequests() async {
    final response = await _get('/api/group-creation-requests');
    return (response as List<dynamic>).map((item) => GroupCreationRequest.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<GroupCreationRequest>> fetchAdminGroupCreationRequests({String status = '', int limit = 100}) async {
    final query = <String, String>{'limit': '$limit'};
    if (status.trim().isNotEmpty) query['status'] = status.trim();
    final response = await _get('/api/admin/group-creation-requests', query: query);
    return (response as List<dynamic>).map((item) => GroupCreationRequest.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<GroupCreationRequest> approveGroupCreationRequest(String requestId, {String adminComment = ''}) async {
    final response = await _post('/api/admin/group-creation-requests/$requestId/approve', {'admin_comment': adminComment});
    return GroupCreationRequest.fromJson(response as Map<String, dynamic>);
  }

  Future<GroupCreationRequest> rejectGroupCreationRequest(String requestId, {String adminComment = ''}) async {
    final response = await _post('/api/admin/group-creation-requests/$requestId/reject', {'admin_comment': adminComment});
    return GroupCreationRequest.fromJson(response as Map<String, dynamic>);
  }

  Future<GroupCreationRequest> needMoreInfoForGroupCreationRequest(String requestId, {String adminComment = ''}) async {
    final response = await _post('/api/admin/group-creation-requests/$requestId/need-more-info', {'admin_comment': adminComment});
    return GroupCreationRequest.fromJson(response as Map<String, dynamic>);
  }

  Future<dynamic> _get(String path, {Map<String, String>? query, bool auth = true}) {
    return _request('GET', path, query: query, auth: auth);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body, {bool auth = true}) {
    return _request('POST', path, body: body, auth: auth);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
    bool retrying = false,
  }) async {
    final base = Uri.parse(baseUrl);
    final uri = base.replace(path: path, queryParameters: query);
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final session = await sessionStore.read();
      if (session == null) throw const ApiException('Session expired. Please sign in again.');
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    try {
      late final http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(_timeout);
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
      } else {
        response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
      }

      if (response.statusCode == 401 && auth && !retrying) {
        final refreshed = await _refreshSession();
        if (refreshed) {
          return _request(method, path, query: query, body: body, auth: auth, retrying: true);
        }
      }
      return _decode(response);
    } on TimeoutException {
      throw const ApiException('Connection timed out. Please check the server and try again.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Network error: $error');
    }
  }

  Future<bool> _refreshSession() async {
    final session = await sessionStore.read();
    if (session == null || session.refreshToken.isEmpty) return false;

    final base = Uri.parse(baseUrl);
    final uri = base.replace(path: '/api/auth/refresh');
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
    final body = response.body.trim();
    final decoded = body.isEmpty ? null : jsonDecode(body);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map<String, dynamic> && decoded['error'] is String) {
      throw ApiException(decoded['error'] as String);
    }
    throw ApiException('Server error ${response.statusCode}');
  }
}

class RequestCodeResult {
  const RequestCodeResult({required this.status, this.devCode});

  final String status;
  final String? devCode;

  factory RequestCodeResult.fromJson(Map<String, dynamic> json) {
    return RequestCodeResult(
      status: json['status'] as String? ?? 'code_sent',
      devCode: json['dev_code'] as String?,
    );
  }
}
