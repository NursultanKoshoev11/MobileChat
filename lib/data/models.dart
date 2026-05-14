class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    this.mobile,
  });

  final String id;
  final String displayName;
  final DateTime? createdAt;
  final String? mobile;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      mobile: json['mobile'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'mobile': mobile,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class AppSession {
  const AppSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile user;

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user': user.toJson(),
    };
  }
}

class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.visibility,
    required this.ownerId,
    required this.memberCount,
    required this.inviteCode,
    required this.myRole,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String visibility;
  final String ownerId;
  final int memberCount;
  final String? inviteCode;
  final String? myRole;
  final DateTime? createdAt;

  bool get isPublic => visibility == 'public';
  bool get canInvite => myRole == 'owner' || myRole == 'admin';

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      visibility: json['visibility'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      memberCount: json['member_count'] as int? ?? 0,
      inviteCode: json['invite_code'] as String?,
      myRole: json['my_role'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
