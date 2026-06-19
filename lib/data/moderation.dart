class ModerationPendingException implements Exception {
  const ModerationPendingException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ContentModerationItem {
  const ContentModerationItem({
    required this.id,
    required this.groupId,
    required this.contentType,
    required this.authorId,
    required this.authorName,
    required this.targetId,
    required this.title,
    required this.body,
    required this.requestType,
    required this.interactionMode,
    required this.status,
    required this.decision,
    required this.reasons,
    required this.provider,
    required this.providerModel,
    required this.publishedResourceId,
    required this.createdAt,
    required this.reviewedAt,
    required this.reviewedBy,
  });

  final String id;
  final String groupId;
  final String contentType;
  final String authorId;
  final String authorName;
  final String targetId;
  final String title;
  final String body;
  final String requestType;
  final String interactionMode;
  final String status;
  final String decision;
  final List<String> reasons;
  final String provider;
  final String providerModel;
  final String publishedResourceId;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String reviewedBy;

  String get typeLabel {
    switch (contentType) {
      case 'public_request_comment':
        return 'Комментарий';
      case 'public_request':
        return 'Публикация';
      case 'group_message':
        return 'Сообщение';
      default:
        return contentType;
    }
  }

  String get reasonLabel {
    if (reasons.isEmpty) return 'AI unsure';
    return reasons.map(_formatReason).join(', ');
  }

  static String _formatReason(String reason) {
    switch (reason) {
      case 'advertising_text':
        return 'реклама';
      case 'advertising_link':
        return 'ссылка';
      case 'advertising_contact':
        return 'контакт/номер';
      case 'too_many_links':
        return 'много ссылок';
      case 'profanity':
        return 'нецензурный текст';
      case 'abusive_language':
        return 'оскорбление';
      case 'repeated_characters':
        return 'повтор символов';
      case 'excessive_caps':
        return 'много CAPS';
      default:
        if (reason.startsWith('openai:')) return 'AI: ${reason.substring(7)}';
        if (reason.startsWith('huggingface:')) return 'AI: ${reason.substring(12)}';
        return reason;
    }
  }

  factory ContentModerationItem.fromJson(Map<String, dynamic> json) {
    final reasonsRaw = json['reasons'];
    return ContentModerationItem(
      id: json['id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'User',
      targetId: json['target_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      requestType: json['request_type'] as String? ?? '',
      interactionMode: json['interaction_mode'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      decision: json['decision'] as String? ?? '',
      reasons: reasonsRaw is List
          ? reasonsRaw.map((item) => item.toString()).toList()
          : const <String>[],
      provider: json['provider'] as String? ?? '',
      providerModel: json['provider_model'] as String? ?? '',
      publishedResourceId: json['published_resource_id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      reviewedAt: DateTime.tryParse(json['reviewed_at'] as String? ?? ''),
      reviewedBy: json['reviewed_by'] as String? ?? '',
    );
  }
}
