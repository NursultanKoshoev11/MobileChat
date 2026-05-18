import 'public_request.dart';

class StatisticsBreakdownItem {
  const StatisticsBreakdownItem({required this.key, required this.label, required this.count, required this.percent});

  final String key;
  final String label;
  final int count;
  final double percent;

  factory StatisticsBreakdownItem.fromJson(Map<String, dynamic> json) {
    return StatisticsBreakdownItem(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? json['key'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class StatisticsTimelineItem {
  const StatisticsTimelineItem({
    required this.bucket,
    required this.total,
    required this.closed,
    required this.open,
    required this.resolved,
    required this.complaints,
  });

  final String bucket;
  final int total;
  final int closed;
  final int open;
  final int resolved;
  final int complaints;

  factory StatisticsTimelineItem.fromJson(Map<String, dynamic> json) {
    return StatisticsTimelineItem(
      bucket: json['bucket'] as String? ?? '',
      total: json['total'] as int? ?? 0,
      closed: json['closed'] as int? ?? 0,
      open: json['open'] as int? ?? 0,
      resolved: json['resolved'] as int? ?? 0,
      complaints: json['complaints'] as int? ?? 0,
    );
  }
}

class GroupStatistics {
  const GroupStatistics({
    required this.groupId,
    required this.period,
    required this.granularity,
    required this.from,
    required this.to,
    required this.totalRequests,
    required this.totalComplaints,
    required this.totalComments,
    required this.supportVotes,
    required this.opposeVotes,
    required this.closedRequests,
    required this.openRequests,
    required this.resolvedRequests,
    required this.rejectedRequests,
    required this.closeRate,
    required this.resolveRate,
    required this.byType,
    required this.byStatus,
    required this.byInteractionMode,
    required this.timeline,
    required this.recentOpenRequests,
  });

  final String groupId;
  final String period;
  final String granularity;
  final DateTime? from;
  final DateTime? to;
  final int totalRequests;
  final int totalComplaints;
  final int totalComments;
  final int supportVotes;
  final int opposeVotes;
  final int closedRequests;
  final int openRequests;
  final int resolvedRequests;
  final int rejectedRequests;
  final double closeRate;
  final double resolveRate;
  final List<StatisticsBreakdownItem> byType;
  final List<StatisticsBreakdownItem> byStatus;
  final List<StatisticsBreakdownItem> byInteractionMode;
  final List<StatisticsTimelineItem> timeline;
  final List<PublicRequest> recentOpenRequests;

  factory GroupStatistics.fromJson(Map<String, dynamic> json) {
    return GroupStatistics(
      groupId: json['group_id'] as String? ?? '',
      period: json['period'] as String? ?? 'month',
      granularity: json['granularity'] as String? ?? 'day',
      from: DateTime.tryParse(json['from'] as String? ?? ''),
      to: DateTime.tryParse(json['to'] as String? ?? ''),
      totalRequests: json['total_requests'] as int? ?? 0,
      totalComplaints: json['total_complaints'] as int? ?? 0,
      totalComments: json['total_comments'] as int? ?? 0,
      supportVotes: json['support_votes'] as int? ?? 0,
      opposeVotes: json['oppose_votes'] as int? ?? 0,
      closedRequests: json['closed_requests'] as int? ?? 0,
      openRequests: json['open_requests'] as int? ?? 0,
      resolvedRequests: json['resolved_requests'] as int? ?? 0,
      rejectedRequests: json['rejected_requests'] as int? ?? 0,
      closeRate: (json['close_rate'] as num?)?.toDouble() ?? 0,
      resolveRate: (json['resolve_rate'] as num?)?.toDouble() ?? 0,
      byType: (json['by_type'] as List<dynamic>? ?? const []).map((item) => StatisticsBreakdownItem.fromJson(item as Map<String, dynamic>)).toList(),
      byStatus: (json['by_status'] as List<dynamic>? ?? const []).map((item) => StatisticsBreakdownItem.fromJson(item as Map<String, dynamic>)).toList(),
      byInteractionMode: (json['by_interaction_mode'] as List<dynamic>? ?? const []).map((item) => StatisticsBreakdownItem.fromJson(item as Map<String, dynamic>)).toList(),
      timeline: (json['timeline'] as List<dynamic>? ?? const []).map((item) => StatisticsTimelineItem.fromJson(item as Map<String, dynamic>)).toList(),
      recentOpenRequests: (json['recent_open_requests'] as List<dynamic>? ?? const []).map((item) => PublicRequest.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}
