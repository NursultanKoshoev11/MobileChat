import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/data/models.dart';
import 'package:mobile_chat/shared/ui_helpers.dart';

void main() {
  test('avatarText returns first uppercase character', () {
    expect(avatarText('mobile'), 'M');
    expect(avatarText(' Chat'), 'C');
    expect(avatarText(''), '?');
  });

  test('compactTime formats hour and minute', () {
    final time = DateTime(2026, 5, 14, 7, 5);
    expect(compactTime(time), '07:05');
  });

  test('AppSession serializes and deserializes current session model', () {
    final session = AppSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: UserProfile(
        id: 'U-TEST',
        displayName: 'Tester',
        role: 'user',
        createdAt: DateTime.parse('2026-05-14T00:00:00Z'),
      ),
    );

    final restored = AppSession.fromJson(session.toJson());
    expect(restored.accessToken, 'access-token');
    expect(restored.refreshToken, 'refresh-token');
    expect(restored.user.id, 'U-TEST');
    expect(restored.user.displayName, 'Tester');
  });

  test('ChatGroup parses role and visibility', () {
    final group = ChatGroup.fromJson({
      'id': 'G-TEST',
      'title': 'Test Group',
      'description': 'Description',
      'visibility': 'private',
      'owner_id': 'U-OWNER',
      'member_count': 3,
      'unread_public_request_count': 1,
      'invite_code': 'ABC123',
      'qr_pass': 'QR123',
      'my_role': 'admin',
      'created_at': '2026-05-14T00:00:00Z',
    });

    expect(group.isPublic, isFalse);
    expect(group.canInvite, isTrue);
    expect(group.inviteCode, 'ABC123');
    expect(group.qrPass, 'QR123');
    expect(group.memberCount, 3);
    expect(group.unreadPublicRequestCount, 1);
  });
}
