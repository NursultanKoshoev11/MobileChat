import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/home_shell.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/group_invitation.dart';
import 'package:koom/data/models.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/services/user_realtime_service.dart';

UserProfile _user() => UserProfile(
      id: 'U-1',
      displayName: 'Айбек',
      createdAt: DateTime.utc(2026, 1, 1),
      role: 'user',
    );

ChatGroup _group(String id, String title, {int unread = 0}) =>
    ChatGroup.fromJson({
      'id': id,
      'title': title,
      'visibility': 'private',
      'owner_id': 'OWNER',
      'my_role': 'member',
      'member_count': 3,
      'unread_public_request_count': unread,
    });

GroupInvitation _invitation(String id, String groupTitle) =>
    GroupInvitation.fromJson({
      'id': id,
      'group_id': 'G-$id',
      'group_title': groupTitle,
      'inviter_name': 'Нурлан',
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });

class _FakeHomeApi extends ApiClient {
  _FakeHomeApi({
    this.groups = const <ChatGroup>[],
    this.invitations = const <GroupInvitation>[],
  }) : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  List<ChatGroup> groups;
  List<GroupInvitation> invitations;

  @override
  Future<List<ChatGroup>> fetchGroups() async => List.of(groups);

  @override
  Future<List<GroupInvitation>> fetchInvitations() async =>
      List.of(invitations);

  @override
  Future<void> markPublicRequestsRead(String groupId) async {}

  @override
  Future<String> issueWebSocketToken() async => '';
}

/// Keeps widget tests off the network: the shell's groups tab opens a
/// websocket in production.
class _NoopUserRealtime extends UserRealtimeService {
  _NoopUserRealtime() : super(api: _FakeHomeApi());

  @override
  Future<void> connect({
    required void Function(UserRealtimeEvent event) onEvent,
    void Function(Object error)? onError,
  }) async {}

  @override
  Future<void> close() async {}
}

Widget _harness(Widget child) => AppAppearanceScope(
      controller: AppAppearanceController(),
      child: AppLanguageScope(
        controller: AppLanguageController(),
        child: MaterialApp(
          theme: KoomTheme.light,
          // Skeleton shimmer repeats forever; turning animations off keeps
          // pumpAndSettle from timing out.
          builder: (context, body) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: body ?? const SizedBox.shrink(),
          ),
          home: child,
        ),
      ),
    );

Widget _shell({
  required GlobalKey<KoomHomeShellState> shellKey,
  required ApiClient api,
  KoomHomeTab initialTab = KoomHomeTab.groups,
  Map<String, String>? initialPushData,
}) =>
    KoomHomeShell(
      key: shellKey,
      api: api,
      session: AppSession(
        accessToken: 'a',
        refreshToken: 'r',
        user: _user(),
      ),
      onSessionChanged: (_) async {},
      onLogout: () async {},
      onAccountDeleted: () async {},
      initialTab: initialTab,
      userRealtime: _NoopUserRealtime(),
      initialPushData: initialPushData,
    );

void main() {
  testWidgets('bottom navigation switches between the three destinations',
      (tester) async {
    final shellKey = GlobalKey<KoomHomeShellState>();
    final api = _FakeHomeApi(groups: [_group('G-1', 'Двор')]);

    await tester.pumpWidget(
      _harness(_shell(shellKey: shellKey, api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(shellKey.currentState!.tab, KoomHomeTab.groups);

    await tester.tap(find.text('Уведомления'));
    await tester.pumpAndSettle();
    expect(shellKey.currentState!.tab, KoomHomeTab.notifications);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      KoomHomeTab.notifications.index,
    );

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(shellKey.currentState!.tab, KoomHomeTab.profile);

    await tester.tap(find.text('Группы'));
    await tester.pumpAndSettle();
    expect(shellKey.currentState!.tab, KoomHomeTab.groups);
  });

  testWidgets('each tab keeps its state while another one is visible',
      (tester) async {
    final shellKey = GlobalKey<KoomHomeShellState>();
    final api = _FakeHomeApi(groups: [_group('G-1', 'Двор')]);

    await tester.pumpWidget(
      _harness(_shell(shellKey: shellKey, api: api)),
    );
    await tester.pumpAndSettle();

    const searchField = ValueKey('groups_search_field');
    await tester.enterText(find.byKey(searchField), 'Дво');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Группы'));
    await tester.pumpAndSettle();

    final textField = find.descendant(
      of: find.byKey(searchField),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(textField).controller?.text, 'Дво');
  });

  testWidgets('a hidden destination stays out of the semantics tree',
      (tester) async {
    final shellKey = GlobalKey<KoomHomeShellState>();
    final api = _FakeHomeApi(groups: [_group('G-1', 'Двор')]);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _harness(_shell(shellKey: shellKey, api: api)),
    );
    await tester.pumpAndSettle();

    // Hidden destinations are laid out, so without an explicit guard screen
    // readers and UI test runners would reach their controls.
    expect(find.bySemanticsLabel('Изменить фото'), findsNothing);

    await tester.tap(find.text('Профиль'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Изменить фото'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('notifications destination badges invitations plus unread posts',
      (tester) async {
    final shellKey = GlobalKey<KoomHomeShellState>();
    final api = _FakeHomeApi(
      groups: [_group('G-1', 'Двор', unread: 3)],
      invitations: [_invitation('I-1', 'Соседи')],
    );

    await tester.pumpWidget(
      _harness(_shell(shellKey: shellKey, api: api)),
    );
    await tester.pumpAndSettle();

    final badge = tester.widget<Badge>(
      find.byKey(const ValueKey('home_tab_notifications_badge')),
    );
    expect((badge.label as Text).data, '4');
  });

  testWidgets('a group notification lands on the groups tab', (tester) async {
    final shellKey = GlobalKey<KoomHomeShellState>();
    final api = _FakeHomeApi(groups: [_group('G-1', 'Двор')]);

    await tester.pumpWidget(_harness(_shell(
      shellKey: shellKey,
      api: api,
      initialTab: KoomHomeTab.profile,
      // The group is not in the list, so nothing is pushed: this asserts the
      // tab the deep link lands on, not the screen it opens.
      initialPushData: const {
        'type': 'public_request.created',
        'group_id': 'G-MISSING',
        'request_id': 'R-1',
      },
    )));
    await tester.pumpAndSettle();

    expect(shellKey.currentState!.tab, KoomHomeTab.groups);
  });

  testWidgets('an invitation notification lands on the notifications tab',
      (tester) async {
    final shellKey = GlobalKey<KoomHomeShellState>();
    final api = _FakeHomeApi(
      invitations: [_invitation('I-1', 'Соседи')],
    );

    await tester.pumpWidget(_harness(_shell(
      shellKey: shellKey,
      api: api,
      initialPushData: const {'type': 'invite.created'},
    )));
    await tester.pumpAndSettle();

    expect(shellKey.currentState!.tab, KoomHomeTab.notifications);
    expect(find.text('Соседи'), findsOneWidget);
  });

  testWidgets('an invitation carrying a group id still lands on notifications',
      (tester) async {
    final shellKey = GlobalKey<KoomHomeShellState>();
    final api = _FakeHomeApi(
      groups: [_group('G-1', 'Двор')],
      invitations: [_invitation('I-1', 'Соседи')],
    );

    // The realtime envelope carries group_id for every event type, and for an
    // invitation it names a group the user is not a member of yet.
    await tester.pumpWidget(_harness(_shell(
      shellKey: shellKey,
      api: api,
      initialPushData: const {
        'type': 'invite.created',
        'group_id': 'G-INVITED',
      },
    )));
    await tester.pumpAndSettle();

    expect(shellKey.currentState!.tab, KoomHomeTab.notifications);
    expect(find.text('Соседи'), findsOneWidget);
  });
}
