import 'dart:convert';

class PublicRequest {
  const PublicRequest({
    required this.id,
    required this.groupId,
    required this.authorId,
    required this.authorName,
    required this.requestType,
    required this.interactionMode,
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
  final String interactionMode;
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
  PublicRequestContent get content => PublicRequestContent.tryParse(body);
  String get displayBody => content.text.isNotEmpty || content.photos.isNotEmpty ? content.text : body;

  factory PublicRequest.fromJson(Map<String, dynamic> json) {
    return PublicRequest(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'User',
      requestType: json['request_type'] as String? ?? 'idea',
      interactionMode: json['interaction_mode'] as String? ?? 'discussion',
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

class PublicRequestContent {
  const PublicRequestContent({required this.text, required this.photos});

  final String text;
  final List<PublicRequestPhoto> photos;

  static const empty = PublicRequestContent(text: '', photos: []);

  String toPayload() {
    if (photos.isEmpty) return text.trim();
    return jsonEncode({
      'version': 1,
      'text': text.trim(),
      'photos': photos.map((photo) => photo.toJson()).toList(),
    });
  }

  static PublicRequestContent tryParse(String value) {
    final raw = value.trim();
    if (raw.isEmpty || !raw.startsWith('{')) return PublicRequestContent(text: value, photos: const []);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return PublicRequestContent(text: value, photos: const []);
      final photosRaw = decoded['photos'];
      return PublicRequestContent(
        text: decoded['text'] as String? ?? '',
        photos: photosRaw is List ? photosRaw.whereType<Map<String, dynamic>>().map(PublicRequestPhoto.fromJson).toList() : const [],
      );
    } catch (_) {
      return PublicRequestContent(text: value, photos: const []);
    }
  }
}

class PublicRequestPhoto {
  const PublicRequestPhoto({required this.name, required this.sizeBytes, required this.base64Data});

  final String name;
  final int sizeBytes;
  final String base64Data;

  Map<String, dynamic> toJson() => {
        'name': name,
        'size_bytes': sizeBytes,
        'base64': base64Data,
      };

  factory PublicRequestPhoto.fromJson(Map<String, dynamic> json) {
    return PublicRequestPhoto(
      name: json['name'] as String? ?? 'photo.jpg',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      base64Data: json['base64'] as String? ?? '',
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
