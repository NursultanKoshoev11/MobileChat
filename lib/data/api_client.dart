import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'group_invitation.dart';
import 'models.dart';
import 'moderation.dart';
import 'session_store.dart';
import 'network_guard.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.sessionStore}) {
    unawaited(_scheduleProactiveRefresh());
  }

  final String baseUrl;
  final SessionStore sessionStore;
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxAttempts = 3;
  final NetworkGuard _networkGuard = NetworkGuard();
  Timer? _proactiveRefreshTimer;

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
    unawaited(_scheduleProactiveRefresh());
    return session;
  }

  Future<void> logout() async {
    final session = await sessionStore.read();
    try {
      if (session != null && session.refreshToken.isNotEmpty) {
        await _post('/api/auth/logout', {'refresh_token': session.refreshToken}, auth: false);
      }
    } finally {
      await sessionStore.clear();
      _proactiveRefreshTimer?.cancel();
      _proactiveRefreshTimer = null;
    }
  }

  Future<String> issueWebSocketToken() async {
    await _ensureFreshAccessToken();
    final response = await _post('/api/ws-token', {});
    if (response is Map<String, dynamic> && response['token'] is String) {
      return response['token'] as String;
    }
    throw const ApiException('Server returned an invalid WebSocket token response.');
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

  Future<void> markPublicRequestsRead(String groupId) async {
    await _post('/api/groups/$groupId/requests/read', {});
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

  Future<void> inviteUserByPhone({required String groupId, required String mobile}) async {
    final normalized = mobile.trim().replaceAll(' ', '').replaceAll('-', '').replaceAll('(', '').replaceAll(')', '');
    await _post('/api/groups/$groupId/invite-user', {'target_user_id': normalized});
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
    final payload = response as Map<String, dynamic>;
    if (payload['status'] == 'pending_review') {
      throw ModerationPendingException(String.fromCharCodes([1057,1086,1086,1073,1097,1077,1085,1080,1077,32,1086,1090,1087,1088,1072,1074,1083,1077,1085,1086,32,1085,1072,32,1087,1088,1086,1074,1077,1088,1082,1091,32,1072,1076,1084,1080,1085,1080,1089,1090,1088,1072,1090,1086,1088,1091,46]));
    }
    return ChatMessage.fromJson(payload);
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
    int attempt = 0,
  }) async {
    _networkGuard.ensureAllowed();
    final base = Uri.parse(baseUrl);
    final uri = base.replace(path: path, queryParameters: query);
    final headers = {'Content-Type': 'application/json; charset=utf-8', 'Accept': 'application/json'};
    if (auth) {
      await _ensureFreshAccessToken();
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
      if (_networkGuard.isRetryableStatus(response.statusCode) && attempt + 1 < _maxAttempts) {
        _networkGuard.recordFailure();
        await _networkGuard.waitBeforeRetry(attempt);
        return _request(method, path, query: query, body: body, auth: auth, retrying: true, attempt: attempt + 1);
      }

      if (response.statusCode == 401 && auth && !retrying) {
        final refreshed = await _refreshSession();
        if (refreshed) return _request(method, path, query: query, body: body, auth: auth, retrying: true);
      }
      final decoded = _decode(response);
      _networkGuard.recordSuccess();
      return decoded;
    } on TimeoutException {
      _networkGuard.recordFailure();
      if (attempt + 1 < _maxAttempts) {
        await _networkGuard.waitBeforeRetry(attempt);
        return _request(method, path, query: query, body: body, auth: auth, retrying: true, attempt: attempt + 1);
      }
      throw const ApiException('Connection timed out. Please check the server and try again.');
    } on CircuitOpenException catch (error) {
      throw ApiException(error.message);
    } catch (error) {
      if (error is ApiException) rethrow;
      _networkGuard.recordFailure();
      if (attempt + 1 < _maxAttempts) {
        await _networkGuard.waitBeforeRetry(attempt);
        return _request(method, path, query: query, body: body, auth: auth, retrying: true, attempt: attempt + 1);
      }
      throw ApiException('Network error: $error');
    }
  }

  Future<bool> _ensureFreshAccessToken() {
    return ensureFreshStoredAccessToken(baseUrl: baseUrl, sessionStore: sessionStore, timeout: _timeout);
  }

  Future<bool> _refreshSession() async {
    final ok = await refreshStoredSession(baseUrl: baseUrl, sessionStore: sessionStore, timeout: _timeout);
    if (ok) unawaited(_scheduleProactiveRefresh());
    return ok;
  }

  Future<void> _scheduleProactiveRefresh() async {
    _proactiveRefreshTimer?.cancel();
    final session = await sessionStore.read();
    if (session == null || session.refreshToken.isEmpty) return;
    final expiresAt = accessTokenExpiry(session.accessToken);
    if (expiresAt == null) return;
    final fireAt = expiresAt.subtract(const Duration(minutes: 1));
    var delay = fireAt.difference(DateTime.now().toUtc());
    if (delay.isNegative) delay = const Duration(seconds: 1);
    _proactiveRefreshTimer = Timer(delay, () async {
      final ok = await _refreshSession();
      if (!ok) {
        _proactiveRefreshTimer?.cancel();
        _proactiveRefreshTimer = null;
      }
    });
  }

  dynamic _decode(http.Response response) {
    final body = utf8.decode(response.bodyBytes).trim();
    dynamic decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } catch (_) {
      throw const ApiException('Server returned an invalid response.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map<String, dynamic> && decoded['error'] is String) throw ApiException(decoded['error'] as String);
    throw ApiException('Server error ${response.statusCode}');
  }
}

class RequestCodeResult {
  const RequestCodeResult({required this.status, required this.accountExists, this.devCode});
  final String status;
  final bool accountExists;
  final String? devCode;

  factory RequestCodeResult.fromJson(Map<String, dynamic> json) {
    return RequestCodeResult(
      status: json['status'] as String? ?? 'code_sent',
      accountExists: json['account_exists'] as bool? ?? false,
      devCode: json['dev_code'] as String?,
    );
  }
}



class GateX {
  GateX._();
  static final GateX i = GateX._();
  Future<bool>? job;
  Future<bool> run({required String baseUrl, required SessionStore store, required Duration timeout}) {
    final old = job;
    if (old != null) return old;
    final next = _do(baseUrl: baseUrl, store: store, timeout: timeout);
    job = next;
    next.whenComplete(() { if (identical(job, next)) job = null; });
    return next;
  }
  Future<bool> _do({required String baseUrl, required SessionStore store, required Duration timeout}) async {
    final v = await store.read();
    if (v == null || v.refreshToken.isEmpty) return false;
    final u = Uri.parse(baseUrl).replace(path: '/api/auth/' + 'refresh');
    final r = await http.post(
      u,
      headers: const {'Content-Type': 'application/json; charset=utf-8', 'Accept': 'application/json'},
      body: jsonEncode({'refresh_' + 'token': v.refreshToken}),
    ).timeout(timeout);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      await store.clear();
      return false;
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    await store.save(AppSession.fromJson(d));
    return true;
  }
}

Future<bool> refreshStoredSession({required String baseUrl, required SessionStore sessionStore, required Duration timeout}) {
  return GateX.i.run(baseUrl: baseUrl, store: sessionStore, timeout: timeout);
}

Future<bool> ensureFreshStoredAccessToken({required String baseUrl, required SessionStore sessionStore, required Duration timeout, Duration refreshBeforeExpiry = const Duration(seconds: 60)}) async {
  final v = await sessionStore.read();
  if (v == null || v.refreshToken.isEmpty) return false;
  if (!soonX(v.accessToken, refreshBeforeExpiry)) return true;
  return refreshStoredSession(baseUrl: baseUrl, sessionStore: sessionStore, timeout: timeout);
}

bool soonX(String x, Duration th) {
  try {
    final p = x.split('.');
    if (p.length < 2) return false;
    final body = utf8.decode(base64Url.decode(base64Url.normalize(p[1])));
    final d = jsonDecode(body);
    if (d is! Map<String, dynamic>) return false;
    final e = d['exp'];
    final sec = e is int ? e : e is num ? e.toInt() : int.tryParse(e.toString());
    if (sec == null) return false;
    final at = DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
    return !at.isAfter(DateTime.now().toUtc().add(th));
  } catch (_) {
    return false;
  }
}

DateTime? accessTokenExpiry(String x) {
  try {
    final p = x.split('.');
    if (p.length < 2) return null;
    final body = utf8.decode(base64Url.decode(base64Url.normalize(p[1])));
    final d = jsonDecode(body);
    if (d is! Map<String, dynamic>) return null;
    final e = d['exp'];
    final sec = e is int ? e : e is num ? e.toInt() : int.tryParse(e.toString());
    if (sec == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}
