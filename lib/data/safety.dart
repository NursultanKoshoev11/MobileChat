import 'api_client.dart';

/// Thrown when the server does not implement a safety endpoint yet
/// (HTTP 404/405). The UI shows a friendly "not available yet" message.
class FeatureUnavailableException implements Exception {
  const FeatureUnavailableException();

  @override
  String toString() => 'Feature is not available yet.';
}

abstract final class ReportTargetType {
  static const publicRequest = 'public_request';
  static const comment = 'comment';
  static const message = 'message';
  static const user = 'user';
}

abstract final class ReportReason {
  static const spam = 'spam';
  static const abuse = 'abuse';
  static const illegal = 'illegal';
  static const other = 'other';

  static const values = [spam, abuse, illegal, other];
}

const int maxReportDetailsLength = 1000;

class ReportReceipt {
  const ReportReceipt({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String status;
  final DateTime? createdAt;

  factory ReportReceipt.fromJson(Map<String, dynamic> json) {
    return ReportReceipt(
      id: json['id']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
  });

  final String userId;
  final String displayName;
  final DateTime? blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name'] as String? ?? '',
      blockedAt: DateTime.tryParse(json['blocked_at'] as String? ?? ''),
    );
  }
}

class ContentReport {
  const ContentReport({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.details,
    required this.reporterDisplayName,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String details;
  final String reporterDisplayName;
  final DateTime? createdAt;
  final String status;

  factory ContentReport.fromJson(Map<String, dynamic> json) {
    return ContentReport(
      id: json['id']?.toString() ?? '',
      targetType: json['target_type'] as String? ?? '',
      targetId: json['target_id']?.toString() ?? '',
      reason: json['reason'] as String? ?? '',
      details: json['details'] as String? ?? '',
      reporterDisplayName: json['reporter_display_name'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      status: json['status'] as String? ?? '',
    );
  }
}

/// Report / block / moderation endpoints, shared by [ApiClient] and
/// PublicRequestsApi. Implementers provide the authenticated transport.
mixin SafetyEndpoints {
  Future<dynamic> sendSafetyRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  });

  Future<dynamic> _safety(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    try {
      return await sendSafetyRequest(method, path, query: query, body: body);
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        throw const FeatureUnavailableException();
      }
      rethrow;
    }
  }

  Future<ReportReceipt> submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) async {
    final trimmed = details.trim();
    final payload = <String, dynamic>{
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
    };
    if (trimmed.isNotEmpty) {
      payload['details'] = trimmed.length > maxReportDetailsLength
          ? trimmed.substring(0, maxReportDetailsLength)
          : trimmed;
    }
    final response = await _safety('POST', '/api/reports', body: payload);
    return response is Map<String, dynamic>
        ? ReportReceipt.fromJson(response)
        : const ReportReceipt(id: '', status: '', createdAt: null);
  }

  Future<void> blockUser(String userId) async {
    await _safety('POST', '/api/users/${Uri.encodeComponent(userId)}/block');
  }

  Future<void> unblockUser(String userId) async {
    await _safety('DELETE', '/api/users/${Uri.encodeComponent(userId)}/block');
  }

  Future<List<BlockedUser>> fetchBlockedUsers() async {
    final response = await _safety('GET', '/api/me/blocks');
    if (response is! List) return const [];
    return response
        .whereType<Map<String, dynamic>>()
        .map(BlockedUser.fromJson)
        .where((user) => user.userId.isNotEmpty)
        .toList();
  }

  Future<List<ContentReport>> fetchGroupReports(
    String groupId, {
    String status = 'open',
  }) async {
    final response = await _safety(
      'GET',
      '/api/groups/${Uri.encodeComponent(groupId)}/reports',
      query: {'status': status},
    );
    if (response is! List) return const [];
    return response
        .whereType<Map<String, dynamic>>()
        .map(ContentReport.fromJson)
        .toList();
  }

  /// [action] is `dismissed` or `content_removed`.
  Future<void> resolveReport(String reportId, {required String action}) async {
    await _safety(
      'POST',
      '/api/reports/${Uri.encodeComponent(reportId)}/resolve',
      body: {'action': action},
    );
  }
}
