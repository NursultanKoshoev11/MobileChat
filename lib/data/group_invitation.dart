class GroupInvitation {
  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupTitle,
    required this.senderId,
    required this.senderName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupTitle;
  final String senderId;
  final String senderName;
  final String status;
  final DateTime createdAt;

  factory GroupInvitation.fromJson(Map<String, dynamic> json) {
    return GroupInvitation(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      groupTitle: json['group_title'] as String? ?? 'Group',
      senderId: json['inviter_id'] as String? ?? '',
      senderName: json['inviter_name'] as String? ?? 'User',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
