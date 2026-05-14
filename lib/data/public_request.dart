class PublicRequest {
  const PublicRequest({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    required this.requestType,
    required this.title,
    required this.body,
    required this.status,
    required this.supportCount,
    required this.opposeCount,
    required this.commentCount,
    required this.myVote,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String groupId;
  final String authorId;
  final String authorName;
  final String requestType;
  final String title;
  final String body;
  final String status;
  final int supportCount;
  final int opposeCount;
  final int commentCount;
  final String? myVote;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get supportedByMe => myVote == 'support';
  bool get opposedByMe => myVote == 'oppose';

  factory PublicRequest.fromJson(Map<String, dynamic> json) {
    return PublicRequest(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'User',
      requestType: json['request_type'] as String? ?? 'idea',
      title: json['title'] as String,
      body: json['body'] as String,
      status: json['status'] as String? ?? 'new',
      supportCount: json['support_count'] as int? ?? 0,
      opposeCount: json['oppose_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      myVote: json['my_vote'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class PublicRequestComment {
  const PublicRequestComment({
    required this.id,
    required this.requestId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory PublicRequestComment.fromJson(Map<String, dynamic> json) {
    return PublicRequestComment(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'User',
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
