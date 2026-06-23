class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    required this.role,
    this.mobile,
  });

  final String id;
  final String displayName;
  final DateTime? createdAt;
  final String? mobile;
  final String role;

  bool get isPlatformAdmin => role == 'platform_admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      mobile: json['mobile'] as String? ?? json['phone'] as String?,
      role: json['role'] as String? ?? 'user',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'mobile': mobile,
      'role': role,
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
    required this.unreadPublicRequestCount,
    required this.inviteCode,
    required this.qrPass,
    required this.myRole,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String visibility;
  final String ownerId;
  final int memberCount;
  final int unreadPublicRequestCount;
  final String? inviteCode;
  final String? qrPass;
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
      unreadPublicRequestCount: json['unread_public_request_count'] as int? ?? 0,
      inviteCode: json['invite_code'] as String?,
      qrPass: json['qr_pass'] as String?,
      myRole: json['my_role'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  ChatGroup copyWith({
    String? id,
    String? title,
    String? description,
    String? visibility,
    String? ownerId,
    int? memberCount,
    int? unreadPublicRequestCount,
    String? inviteCode,
    String? qrPass,
    String? myRole,
    DateTime? createdAt,
  }) {
    return ChatGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      visibility: visibility ?? this.visibility,
      ownerId: ownerId ?? this.ownerId,
      memberCount: memberCount ?? this.memberCount,
      unreadPublicRequestCount: unreadPublicRequestCount ?? this.unreadPublicRequestCount,
      inviteCode: inviteCode ?? this.inviteCode,
      qrPass: qrPass ?? this.qrPass,
      myRole: myRole ?? this.myRole,
      createdAt: createdAt ?? this.createdAt,
    );
  }

}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
    this.phone,
  });

  final String userId;
  final String displayName;
  final String role;
  final String? phone;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'User',
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'member',
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

class GroupCreationRequest {
  const GroupCreationRequest({
    required this.id,
    required this.requesterId,
    required this.applicantName,
    required this.position,
    required this.organizationName,
    required this.organizationType,
    required this.region,
    required this.officialPhone,
    required this.officialEmail,
    required this.website,
    required this.groupTitle,
    required this.groupDescription,
    required this.reason,
    required this.documents,
    required this.status,
    required this.adminComment,
    required this.createdGroupId,
    required this.createdAt,
    required this.updatedAt,
    required this.reviewedAt,
  });

  final String id;
  final String requesterId;
  final String applicantName;
  final String position;
  final String organizationName;
  final String organizationType;
  final String region;
  final String officialPhone;
  final String officialEmail;
  final String website;
  final String groupTitle;
  final String groupDescription;
  final String reason;
  final String documents;
  final String status;
  final String adminComment;
  final String createdGroupId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  factory GroupCreationRequest.fromJson(Map<String, dynamic> json) {
    return GroupCreationRequest(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String? ?? '',
      applicantName: json['applicant_name'] as String? ?? '',
      position: json['position'] as String? ?? '',
      organizationName: json['organization_name'] as String? ?? '',
      organizationType: json['organization_type'] as String? ?? '',
      region: json['region'] as String? ?? '',
      officialPhone: json['official_phone'] as String? ?? '',
      officialEmail: json['official_email'] as String? ?? '',
      website: json['website'] as String? ?? '',
      groupTitle: json['group_title'] as String? ?? '',
      groupDescription: json['group_description'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      documents: json['documents'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminComment: json['admin_comment'] as String? ?? '',
      createdGroupId: json['created_group_id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      reviewedAt: DateTime.tryParse(json['reviewed_at'] as String? ?? ''),
    );
  }
}
