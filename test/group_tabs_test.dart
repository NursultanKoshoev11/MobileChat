import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/appearance.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/group_statistics.dart';
import 'package:koom/data/models.dart';
import 'package:koom/data/public_request.dart';
import 'package:koom/data/public_requests_api.dart';
import 'package:koom/data/session_store.dart';
import 'package:koom/features/public_requests/public_requests_screen.dart';
import 'package:koom/services/group_realtime_service.dart';

UserProfile _user() => UserProfile(
      id: 'U-1',
      displayName: 'Айбек',
      createdAt: DateTime.utc(2026, 1, 1),
      role: 'user',
    );

ChatGroup _group(String? myRole) => ChatGroup.fromJson({
      'id': 'G-1',
      'title': 'Двор',
      'visibility': 'private',
      'owner_id': myRole == 'owner' ? 'U-1' : 'OWNER',
      'my_role': myRole,
      'member_count': 2,
    });

class _FakeApi extends ApiClient {
  _FakeApi()
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  @override
  Future<void> markPublicRequestsRead(String groupId) async {}

  @override
  Future<String> issueWebSocketToken() async => '';
}

class _FakeRequestsApi extends PublicRequestsApi {
  _FakeRequestsApi({this.moderationCount = 0})
      : super(
          baseUrl: 'https://koom.example',
          sessionStore: const SessionStore(),
        );

  final int moderationCount;

  @override
  Future<List<PublicRequest>> listRequests(
    String groupId, {
    bool mineOnly = false,
    DateTime? before,
    String? beforeId,
    int limit = 50,
  }) async =>
      const <PublicRequest>[];

  @override
  Future<List<GroupMember>> listGroupMembers(String groupId) async => const [
        GroupMember(userId: 'U-1', displayName: 'Айбек', role: 'owner'),
        GroupMember(userId: 'U-2', displayName: 'Нурлан', role: 'member'),
      ];

  @override
  Future<int> countModerationItems(
    String groupId, {
    String status = 'pending',
  }) async =>
      moderationCount;

  @override
  Future<List<ContentModerationItem>> listModerationItems(
    String groupId, {
    String status = 'pending',
    int limit = 50,
  }) async =>
      const <ContentModerationItem>[];

  @override
  Future<GroupStatistics> fetchStatistics(
    String groupId, {
    String period = 'month',
    String granularity = 'day',
    DateTime? from,
    DateTime? to,
  }) async =>
      GroupStatistics.fromJson(const <String, dynamic>{'group_id': 'G-1'});
}

/// Keeps the screen off the network: it opens a group websocket in production.
class _NoopRealtime extends GroupRealtimeService {
  _NoopRealtime() : super(api: _FakeApi(), groupId: 'G-1');

  @override
  Future<void> connect({
    required void Function(GroupRealtimeEvent event) onEvent,
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
          builder: (context, body) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: body ?? const SizedBox.shrink(),
          ),
          home: child,
        ),
      ),
    );

Widget _screen(String? myRole, {int moderationCount = 0}) =>
    PublicRequestsScreen(
      api: _FakeApi(),
      user: _user(),
      group: _group(myRole),
      requestsApi: _FakeRequestsApi(moderationCount: moderationCount),
      realtime: _NoopRealtime(),
    );

void main() {
  testWidgets('a moderator sees feed, members, statistics and moderation tabs',
      (tester) async {
    await tester.pumpWidget(_harness(_screen('owner', moderationCount: 2)));
    await tester.pumpAndSettle();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Лента'), findsOneWidget);
    expect(find.text('Участники'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('Модерация'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('group_tab_moderation')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a plain member gets no moderation tab', (tester) async {
    await tester.pumpWidget(_harness(_screen('member')));
    await tester.pumpAndSettle();

    expect(find.text('Лента'), findsOneWidget);
    expect(find.text('Участники'), findsOneWidget);
    expect(find.text('Статистика'), findsOneWidget);
    expect(find.text('Модерация'), findsNothing);
  });

  testWidgets('the members tab lists the group members', (tester) async {
    await tester.pumpWidget(_harness(_screen('owner')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Участники'));
    await tester.pumpAndSettle();

    expect(find.text('Нурлан'), findsOneWidget);
  });

  testWidgets('a group update that drops my role shrinks the tab set',
      (tester) async {
    final api = _FakeApi();
    final requestsApi = _FakeRequestsApi(moderationCount: 2);
    final realtime = _NoopRealtime();

    Widget screen(String? myRole) => _harness(PublicRequestsScreen(
          api: api,
          user: _user(),
          group: _group(myRole),
          requestsApi: requestsApi,
          realtime: realtime,
        ));

    await tester.pumpWidget(screen('owner'));
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(4));

    // Select the last tab, so a shorter tab set has to move the selection too.
    await tester.tap(find.text('Модерация'));
    await tester.pumpAndSettle();

    // A group payload without my_role (a partial response, or rights that
    // were taken away) must not leave the controller and the tabs disagreeing.
    await tester.pumpWidget(screen(null));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Tab), findsNWidgets(3));
    expect(find.text('Модерация'), findsNothing);
    expect(
      tester.widget<TabBar>(find.byKey(const ValueKey('group_tab_bar'))).tabs,
      hasLength(3),
    );
  });

  testWidgets('the new-post button only belongs to the feed tab',
      (tester) async {
    await tester.pumpWidget(_harness(_screen('owner')));
    await tester.pumpAndSettle();

    const fab = ValueKey('public_request_create_action');
    expect(find.byKey(fab), findsOneWidget);

    await tester.tap(find.text('Статистика'));
    await tester.pumpAndSettle();
    expect(find.byKey(fab), findsNothing);

    await tester.tap(find.text('Лента'));
    await tester.pumpAndSettle();
    expect(find.byKey(fab), findsOneWidget);
  });
}
