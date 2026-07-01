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

  test('UserProfile handles phone fallback and admin roles', () {
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
    expect(superAdmin.isPlatformAdmin, isTrue);
    expect(superAdmin.isSuperAdmin, isTrue);
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

  test('ChatGroup canInvite works for admin and owner', () {
    final admin = ChatGroup.fromJson({
      'id': 'G-1',
      'title': 'Group',
      'description': '',
      'visibility': 'private',
      'owner_id': 'U-1',
      'member_count': 1,
      'my_role': 'admin',
      'created_at': '2026-05-14T00:00:00Z',
    });

    expect(admin.isPublic, isFalse);
    expect(admin.canInvite, isTrue);
  });

  test('ChatGroup parses defaults and copyWith overrides fields', () {
    final group = ChatGroup.fromJson({
      'id': 'G-2',
      'title': 'Public Group',
      'visibility': 'public',
      'created_at': 'bad-date',
    });
    final changed = group.copyWith(
      title: 'Private Group',
      description: 'Updated',
      visibility: 'private',
      ownerId: 'U-OWNER',
      memberCount: 8,
      unreadPublicRequestCount: 4,
      inviteCode: 'INVITE',
      qrPass: 'QR',
      myRole: 'owner',
      createdAt: DateTime.parse('2026-05-14T00:00:00Z'),
    );

    expect(group.description, '');
    expect(group.ownerId, '');
    expect(group.memberCount, 0);
    expect(group.unreadPublicRequestCount, 0);
    expect(group.createdAt, isNull);
    expect(group.isPublic, isTrue);
    expect(group.canInvite, isFalse);
    expect(changed.id, 'G-2');
    expect(changed.title, 'Private Group');
    expect(changed.description, 'Updated');
    expect(changed.visibility, 'private');
    expect(changed.ownerId, 'U-OWNER');
    expect(changed.memberCount, 8);
    expect(changed.unreadPublicRequestCount, 4);
    expect(changed.inviteCode, 'INVITE');
    expect(changed.qrPass, 'QR');
    expect(changed.canInvite, isTrue);
    expect(changed.createdAt, DateTime.parse('2026-05-14T00:00:00Z'));

    final same = group.copyWith();
    expect(same.id, group.id);
    expect(same.title, group.title);
    expect(same.description, group.description);
    expect(same.visibility, group.visibility);
    expect(same.ownerId, group.ownerId);
    expect(same.memberCount, group.memberCount);
    expect(same.unreadPublicRequestCount, group.unreadPublicRequestCount);
    expect(same.inviteCode, group.inviteCode);
    expect(same.qrPass, group.qrPass);
    expect(same.myRole, group.myRole);
    expect(same.createdAt, group.createdAt);
  });

  test('GroupMember and ChatMessage parse JSON', () {
    final member = GroupMember.fromJson({
      'user_id': 'U-1',
      'phone': '+996700123456',
    });
    final message = ChatMessage.fromJson({
      'id': 'M-1',
      'group_id': 'G-1',
      'sender_id': 'U-1',
      'sender_name': 'Nursultan',
      'text': 'Hello',
      'created_at': '2026-05-14T07:05:00Z',
    });

    expect(member.displayName, 'User');
    expect(member.role, 'member');
    expect(member.phone, '+996700123456');
    expect(message.id, 'M-1');
    expect(message.groupId, 'G-1');
    expect(message.senderId, 'U-1');
    expect(message.senderName, 'Nursultan');
    expect(message.text, 'Hello');
    expect(message.createdAt, DateTime.parse('2026-05-14T07:05:00Z'));
  });

  test('GroupCreationRequest parses complete and legacy JSON', () {
    final complete = GroupCreationRequest.fromJson({
      'id': 'R-1',
      'requester_id': 'U-1',
      'applicant_name': 'Applicant',
      'position': 'Director',
      'organization_name': 'Org',
      'organization_type': 'Public',
      'region': 'Bishkek',
      'official_phone': '+996700123456',
      'official_email': 'org@example.test',
      'website': 'https://example.test',
      'group_title': 'Org Group',
      'group_description': 'About',
      'reason': 'Need communication',
      'documents': 'doc.pdf',
      'status': 'approved',
      'admin_comment': 'ok',
      'created_group_id': 'G-NEW',
      'created_at': '2026-05-14T00:00:00Z',
      'updated_at': '2026-05-15T00:00:00Z',
      'reviewed_at': '2026-05-16T00:00:00Z',
    });
    final legacy = GroupCreationRequest.fromJson({'id': 'R-2'});

    expect(complete.requesterId, 'U-1');
    expect(complete.applicantName, 'Applicant');
    expect(complete.position, 'Director');
    expect(complete.organizationName, 'Org');
    expect(complete.organizationType, 'Public');
    expect(complete.region, 'Bishkek');
    expect(complete.officialPhone, '+996700123456');
    expect(complete.officialEmail, 'org@example.test');
    expect(complete.website, 'https://example.test');
    expect(complete.groupTitle, 'Org Group');
    expect(complete.groupDescription, 'About');
    expect(complete.reason, 'Need communication');
    expect(complete.documents, 'doc.pdf');
    expect(complete.status, 'approved');
    expect(complete.adminComment, 'ok');
    expect(complete.createdGroupId, 'G-NEW');
    expect(complete.createdAt, DateTime.parse('2026-05-14T00:00:00Z'));
    expect(complete.updatedAt, DateTime.parse('2026-05-15T00:00:00Z'));
    expect(complete.reviewedAt, DateTime.parse('2026-05-16T00:00:00Z'));
    expect(legacy.status, 'pending');
    expect(legacy.requesterId, '');
    expect(legacy.reviewedAt, isNull);
  });

  test('UI helpers format values', () {
    expect(avatarText('mobile'), 'M');
    expect(avatarText(''), '?');
    expect(compactTime(DateTime(2026, 5, 14, 7, 5)), '07:05');
  });
}
