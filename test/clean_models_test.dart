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

  test('UI helpers format values', () {
    expect(avatarText('mobile'), 'M');
    expect(avatarText(''), '?');
    expect(compactTime(DateTime(2026, 5, 14, 7, 5)), '07:05');
  });
}
