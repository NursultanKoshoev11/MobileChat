import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/data/models.dart';
import 'package:mobile_chat/shared/ui_helpers.dart';

void main() {
  test('UserProfile parses phone user JSON', () {
    final user = UserProfile.fromJson({
      'id': 'U-1',
      'mobile': '+996700123456',
      'display_name': 'Nursultan',
      'created_at': '2026-05-14T00:00:00Z',
    });

    expect(user.id, 'U-1');
    expect(user.mobile, '+996700123456');
    expect(user.displayName, 'Nursultan');
  });

  test('UserProfile handles phone fallback and separated admin roles', () {
    final admin = UserProfile.fromJson({
      'id': 'U-ADMIN',
      'phone': '+996700000000',
      'display_name': 'Admin',
      'role': 'platform_admin',
      'created_at': 'bad-date',
    });
    final superAdmin = UserProfile.fromJson({
      'id': 'U-SUPER',
      'display_name': 'Super',
      'role': 'super_admin',
    });

    expect(admin.mobile, '+996700000000');
    expect(admin.createdAt, isNull);
    expect(admin.isPlatformAdmin, isTrue);
    expect(admin.isSuperAdmin, isFalse);
    expect(admin.canReviewGroupCreationRequests, isTrue);
    expect(admin.canManageAllGroups, isFalse);

    expect(superAdmin.isPlatformAdmin, isFalse);
    expect(superAdmin.isSuperAdmin, isTrue);
    expect(superAdmin.canReviewGroupCreationRequests, isTrue);
    expect(superAdmin.canManageAllGroups, isTrue);
    expect(superAdmin.toJson()['role'], 'super_admin');
  });

  test('AppSession keeps refresh token', () {
    final session = AppSession.fromJson({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'user': {
        'id': 'U-1',
        'mobile': '+996700123456',
        'display_name': 'Nursultan',
        'created_at': '2026-05-14T00:00:00Z',
      },
    });

    expect(session.accessToken, 'access');
    expect(session.refreshToken, 'refresh');
    expect(session.toJson()['refresh_token'], 'refresh');
  });

  test('UserProfile and AppSession preserve avatar data', () {
    final user = UserProfile.fromJson({
      'id': 'U-AVATAR',
      'display_name': 'Avatar User',
      'role': 'user',
      'avatar_data': 'data:image/png;base64,QQ==',
      'created_at': '2026-05-14T00:00:00Z',
    });
    final copied = user.copyWith(avatarData: 'data:image/png;base64,Qg==');
    final session = AppSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      user: copied,
    );

    expect(user.avatarData, 'data:image/png;base64,QQ==');
    expect(user.avatarBytes, isNotNull);
    expect(user.avatarBytes!.single, 65);
    expect(copied.avatarData, 'data:image/png;base64,Qg==');
    expect(session.toJson()['user']['avatar_data'], 'data:image/png;base64,Qg==');
  });

  test('ChatGroup canInvite works for admin and owner', () {
    final owner = ChatGroup.fromJson({
      'id': 'G-1',
      'title': 'Owner group',
      'visibility': 'private',
      'owner_id': 'U-1',
      'member_count': 1,
      'unread_public_request_count': 0,
      'my_role': 'owner',
    });
    final admin = owner.copyWith(myRole: 'admin');
    final member = owner.copyWith(myRole: 'member');

    expect(owner.canInvite, isTrue);
    expect(admin.canInvite, isTrue);
    expect(member.canInvite, isFalse);
  });

  test('ChatGroup parses defaults and copyWith overrides fields', () {
    final group = ChatGroup.fromJson({
      'id': 'G-1',
      'title': 'Group',
      'visibility': 'public',
    });

    expect(group.description, '');
    expect(group.ownerId, '');
    expect(group.avatarData, '');
    expect(group.memberCount, 0);
    expect(group.unreadPublicRequestCount, 0);
    expect(group.isPublic, isTrue);

    final updated = group.copyWith(
      title: 'Updated',
      avatarData: 'data:image/png;base64,QQ==',
      memberCount: 5,
      unreadPublicRequestCount: 2,
      myRole: 'admin',
    );
    expect(updated.title, 'Updated');
    expect(updated.avatarData, 'data:image/png;base64,QQ==');
    expect(updated.avatarBytes, isNotNull);
    expect(updated.memberCount, 5);
    expect(updated.unreadPublicRequestCount, 2);
    expect(updated.canInvite, isTrue);
  });

  test('GroupMember and ChatMessage parse JSON', () {
    final member = GroupMember.fromJson({
      'user_id': 'U-2',
      'display_name': 'Member',
      'phone': '+996700000002',
      'role': 'member',
    });
    final message = ChatMessage.fromJson({
      'id': 'M-1',
      'group_id': 'G-1',
      'sender_id': 'U-2',
      'sender_name': 'Member',
      'text': 'Hello',
      'created_at': '2026-05-14T00:00:00Z',
    });

    expect(member.userId, 'U-2');
    expect(member.phone, '+996700000002');
    expect(message.groupId, 'G-1');
    expect(message.text, 'Hello');
  });

  test('GroupCreationRequest parses complete and legacy JSON', () {
    final request = GroupCreationRequest.fromJson({
      'id': 'GCR-1',
      'requester_id': 'U-1',
      'applicant_name': 'Applicant',
      'position': 'Director',
      'organization_name': 'Organization',
      'organization_type': 'ngo',
      'region': 'Bishkek',
      'official_phone': '+996700000000',
      'official_email': 'info@example.com',
      'website': 'https://example.com',
      'group_title': 'Official Group',
      'group_description': 'Description',
      'reason': 'Reason',
      'documents': 'Documents',
      'status': 'pending',
      'admin_comment': '',
      'created_group_id': '',
      'created_at': '2026-05-14T00:00:00Z',
      'updated_at': '2026-05-14T01:00:00Z',
      'reviewed_at': null,
    });
    final legacy = GroupCreationRequest.fromJson({'id': 'GCR-2'});

    expect(request.requesterId, 'U-1');
    expect(request.groupTitle, 'Official Group');
    expect(request.createdAt, isNotNull);
    expect(legacy.status, 'pending');
    expect(legacy.organizationName, '');
  });

  test('UI helpers format values', () {
    expect(avatarText('Nursultan'), 'N');
    expect(avatarText('  '), '?');
    expect(compactTime(DateTime(2026, 5, 14, 9, 7)), '09:07');
  });
}
