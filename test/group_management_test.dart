import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/models.dart';
import 'package:koom/data/public_requests_api.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/features/groups/group_members_screen.dart';
import 'package:koom/features/groups/group_sheets.dart';
import 'package:koom/features/public_requests/public_requests_widgets.dart';

GroupMember _member(String id, String role) =>
    GroupMember(userId: id, displayName: 'User $id', role: role);

ChatGroup _group({required String myRole, String ownerId = 'OWNER'}) =>
    ChatGroup.fromJson({
      'id': 'G-1',
      'title': 'Двор',
      'visibility': 'private',
      'owner_id': ownerId,
      'my_role': myRole,
    });

class _FakeMembersApi extends PublicRequestsApi {
  _FakeMembersApi(this.members)
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  List<GroupMember> members;
  final removed = <String>[];
  int loads = 0;
  Object? removeError;

  @override
  Future<List<GroupMember>> listGroupMembers(String groupId) async {
    loads++;
    return List.of(members);
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    final error = removeError;
    if (error != null) throw error;
    removed.add(userId);
    members = members.where((m) => m.userId != userId).toList();
  }
}

class _FakeJoinApi extends ApiClient {
  _FakeJoinApi()
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  final codes = <String>[];

  @override
  Future<ChatGroup> joinByInviteCode(String inviteCode) async {
    codes.add(inviteCode);
    return _group(myRole: 'member');
  }
}

Widget _harness(Widget child) => AppAppearanceScope(
      controller: AppAppearanceController(),
      child: AppLanguageScope(
        controller: AppLanguageController(),
        child: MaterialApp(theme: KoomTheme.light, home: child),
      ),
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('canRemoveGroupMember', () {
    bool can(String? myRole, GroupMember member) => canRemoveGroupMember(
          myRole: myRole,
          myUserId: 'ME',
          member: member,
        );

    test('owner removes anyone but themselves', () {
      expect(can('owner', _member('A', 'admin')), isTrue);
      expect(can('owner', _member('M', 'member')), isTrue);
      expect(can('owner', _member('ME', 'owner')), isFalse);
    });

    test('admin removes plain members only', () {
      expect(can('admin', _member('M', 'member')), isTrue);
      expect(can('admin', _member('A', 'admin')), isFalse);
      expect(can('admin', _member('O', 'owner')), isFalse);
      expect(can('admin', _member('ME', 'admin')), isFalse);
    });

    test('members remove nobody', () {
      expect(can('member', _member('M', 'member')), isFalse);
      expect(can(null, _member('M', 'member')), isFalse);
    });
  });

  group('GroupMembersScreen', () {
    testWidgets('admin removes a member after confirming, list refreshes',
        (tester) async {
      final api = _FakeMembersApi([
        _member('O', 'owner'),
        _member('A', 'admin'),
        _member('ME', 'admin'),
        _member('M', 'member'),
      ]);
      await tester.pumpWidget(_harness(GroupMembersScreen(
        api: api,
        group: _group(myRole: 'admin', ownerId: 'O'),
        currentUserId: 'ME',
      )));
      await tester.pumpAndSettle();

      // Only the plain member can be removed by an admin.
      expect(find.byKey(const ValueKey('member_actions_M')), findsOneWidget);
      expect(find.byKey(const ValueKey('member_actions_A')), findsNothing);
      expect(find.byKey(const ValueKey('member_actions_O')), findsNothing);
      expect(find.byKey(const ValueKey('member_actions_ME')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('member_actions_M')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить из группы'));
      await tester.pumpAndSettle();
      expect(find.text('Удалить участника из группы?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(api.removed, isEmpty);

      await tester.tap(find.byKey(const ValueKey('member_actions_M')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить из группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm_remove_member')));
      await tester.pumpAndSettle();

      expect(api.removed, ['M']);
      expect(api.loads, 2);
      expect(find.byKey(const ValueKey('group_member_M')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('owner can remove admins and members', (tester) async {
      final api = _FakeMembersApi([
        _member('ME', 'owner'),
        _member('A', 'admin'),
        _member('M', 'member'),
      ]);
      await tester.pumpWidget(_harness(GroupMembersScreen(
        api: api,
        group: _group(myRole: 'owner', ownerId: 'ME'),
        currentUserId: 'ME',
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('member_actions_A')), findsOneWidget);
      expect(find.byKey(const ValueKey('member_actions_M')), findsOneWidget);
      expect(find.byKey(const ValueKey('member_actions_ME')), findsNothing);
    });

    testWidgets('old server: shows a localized "not available yet" message',
        (tester) async {
      final api = _FakeMembersApi([_member('ME', 'owner'), _member('M', 'member')])
        ..removeError = const FeatureUnavailableException();
      await tester.pumpWidget(_harness(GroupMembersScreen(
        api: api,
        group: _group(myRole: 'owner', ownerId: 'ME'),
        currentUserId: 'ME',
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('member_actions_M')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить из группы'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm_remove_member')));
      await tester.pumpAndSettle();
      expect(find.textContaining('пока недоступна'), findsOneWidget);
      expect(find.byKey(const ValueKey('group_member_M')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('PublicRequestsApi new endpoints', () {
    Future<PublicRequestsApi> signedIn() async {
      FlutterSecureStorage.setMockInitialValues({});
      const store = SessionStore();
      await store.save(AppSession.fromJson({
        'access_token': 'access',
        'refresh_token': 'refresh',
        'user': {'id': 'U-1', 'display_name': 'Tester'},
      }));
      return PublicRequestsApi(baseUrl: 'https://koom.example', sessionStore: store);
    }

    test('removeGroupMember sends DELETE and accepts 204', () async {
      final api = await signedIn();
      final calls = <String>[];
      await http.runWithClient(
        () => api.removeGroupMember(groupId: 'G-1', userId: 'U-2'),
        () => MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response('', 204);
        }),
      );
      expect(calls, ['DELETE /api/groups/G-1/members/U-2']);
    });

    test('removeGroupMember on an old server -> FeatureUnavailableException',
        () async {
      final api = await signedIn();
      for (final status in [404, 405]) {
        await expectLater(
          http.runWithClient(
            () => api.removeGroupMember(groupId: 'G-1', userId: 'U-2'),
            () => MockClient((_) async => http.Response('', status)),
          ),
          throwsA(isA<FeatureUnavailableException>()),
        );
      }
    });

    test('removeGroupMember keeps a 403 as a regular API error', () async {
      final api = await signedIn();
      await expectLater(
        http.runWithClient(
          () => api.removeGroupMember(groupId: 'G-1', userId: 'U-2'),
          () => MockClient(
              (_) async => http.Response('{"error":"forbidden"}', 403)),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });

    test('rotateGroupInviteCode posts to /invite-code/rotate', () async {
      final api = await signedIn();
      final calls = <String>[];
      final group = await http.runWithClient(
        () => api.rotateGroupInviteCode('G-1'),
        () => MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            '{"id":"G-1","title":"Двор","visibility":"private",'
            '"invite_code":"K7M2P-QX9ZT","qr_pass":"INV1.x.y"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(calls, ['POST /api/groups/G-1/invite-code/rotate']);
      expect(group.inviteCode, 'K7M2P-QX9ZT');
    });
  });

  group('invite codes UI', () {
    testWidgets('join sheet accepts a pasted new-format code', (tester) async {
      final api = _FakeJoinApi();
      await tester.pumpWidget(_harness(Scaffold(body: JoinByCodeSheet(api: api))));
      await tester.enterText(find.byType(TextField), 'k7m2p qx9zt');
      await tester.pump();
      expect(find.text('K7M2P-QX9ZT'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.codes, ['K7M2P-QX9ZT']);
    });

    testWidgets('join sheet still accepts old AAA-999 codes', (tester) async {
      final api = _FakeJoinApi();
      await tester.pumpWidget(_harness(Scaffold(body: JoinByCodeSheet(api: api))));
      await tester.enterText(find.byType(TextField), 'abc234');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.codes, ['ABC-234']);
    });

    testWidgets('admins rotate the code after a confirmation', (tester) async {
      var rotations = 0;
      await tester.pumpWidget(_harness(Scaffold(
        body: GroupAccessSheet(
          groupTitle: 'Двор',
          code: 'ABC-234',
          onRotate: () async {
            rotations++;
            return ('K7M2P-QX9ZT', 'INV1.new.sig');
          },
        ),
      )));
      expect(find.text('ABC-234'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rotate_invite_code_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('перестанут работать'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm_rotate_invite_code')));
      await tester.pumpAndSettle();
      expect(rotations, 1);
      expect(find.text('K7M2P-QX9ZT'), findsOneWidget);
      expect(find.text('ABC-234'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('members do not get a rotate action', (tester) async {
      await tester.pumpWidget(_harness(const Scaffold(
        body: GroupAccessSheet(groupTitle: 'Двор', code: 'ABC-234'),
      )));
      expect(
          find.byKey(const ValueKey('rotate_invite_code_button')), findsNothing);
    });
  });
}
