import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/data/models.dart';

UserProfile userWithRole(String role) => UserProfile(
  id: 'U-1',
  displayName: 'Test User',
  createdAt: null,
  role: role,
);

void main() {
  test('regular user has no platform capabilities', () {
    final user = userWithRole('user');

    expect(user.isPlatformAdmin, isFalse);
    expect(user.isSuperAdmin, isFalse);
    expect(user.canReviewGroupCreationRequests, isFalse);
    expect(user.canManageAllGroups, isFalse);
    expect(user.canModerateAnyGroup, isFalse);
  });

  test('platform admin can only review group creation requests', () {
    final user = userWithRole('platform_admin');

    expect(user.isPlatformAdmin, isTrue);
    expect(user.isSuperAdmin, isFalse);
    expect(user.canReviewGroupCreationRequests, isTrue);
    expect(user.canManageAllGroups, isFalse);
    expect(user.canModerateAnyGroup, isFalse);
  });

  test('super admin inherits review and owns platform capabilities', () {
    final user = userWithRole('super_admin');

    expect(user.isPlatformAdmin, isFalse);
    expect(user.isSuperAdmin, isTrue);
    expect(user.canReviewGroupCreationRequests, isTrue);
    expect(user.canManageAllGroups, isTrue);
    expect(user.canModerateAnyGroup, isTrue);
  });
}
