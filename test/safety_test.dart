import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/api_client.dart';
import 'package:koom/data/blocked_users.dart';
import 'package:koom/data/public_request.dart';
import 'package:koom/data/safety.dart';
import 'package:koom/features/safety/safety_ui.dart';

class FakeSafetyApi with SafetyEndpoints {
  FakeSafetyApi({this.failWith, this.blocks = const []});

  final Object? failWith;
  final List<Map<String, dynamic>> blocks;
  final List<(String, String, Map<String, dynamic>?)> calls = [];

  @override
  Future<dynamic> sendSafetyRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    calls.add((method, path, body));
    final failure = failWith;
    if (failure != null) throw failure;
    if (method == 'GET' && path == '/api/me/blocks') return blocks;
    if (path == '/api/reports') {
      return {'id': 'R1', 'status': 'open', 'created_at': '2026-01-01T00:00:00Z'};
    }
    return null;
  }
}

PublicRequestComment comment(String id, String authorId) =>
    PublicRequestComment.fromJson({
      'id': id,
      'request_id': 'P1',
      'author_id': authorId,
      'author_name': 'User $authorId',
      'body': 'text',
      'created_at': '2026-01-01T00:00:00Z',
    });

Widget harness(Widget child) => AppLanguageScope(
      controller: AppLanguageController(),
      child: MaterialApp(
        theme: KoomTheme.light,
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('SafetyEndpoints', () {
    test('submitReport sends the documented payload', () async {
      final api = FakeSafetyApi();
      final receipt = await api.submitReport(
        targetType: ReportTargetType.comment,
        targetId: 'C1',
        reason: ReportReason.spam,
        details: '  details  ',
      );
      expect(receipt.id, 'R1');
      expect(api.calls.single.$1, 'POST');
      expect(api.calls.single.$2, '/api/reports');
      expect(api.calls.single.$3, {
        'target_type': 'comment',
        'target_id': 'C1',
        'reason': 'spam',
        'details': 'details',
      });
    });

    test('details are optional and capped at 1000 characters', () async {
      final api = FakeSafetyApi();
      await api.submitReport(
          targetType: 'user', targetId: 'U1', reason: 'other');
      expect(api.calls.last.$3!.containsKey('details'), isFalse);
      await api.submitReport(
          targetType: 'user',
          targetId: 'U1',
          reason: 'other',
          details: 'x' * 1500);
      expect((api.calls.last.$3!['details'] as String).length, 1000);
    });

    test('404 and 405 map to FeatureUnavailableException', () async {
      for (final status in [404, 405]) {
        final api = FakeSafetyApi(
            failWith: ApiException('Server error $status', statusCode: status));
        await expectLater(
          api.submitReport(targetType: 'user', targetId: 'U1', reason: 'spam'),
          throwsA(isA<FeatureUnavailableException>()),
        );
        await expectLater(
            api.blockUser('U1'), throwsA(isA<FeatureUnavailableException>()));
        await expectLater(api.fetchBlockedUsers(),
            throwsA(isA<FeatureUnavailableException>()));
      }
    });

    test('other server errors are passed through', () async {
      final api = FakeSafetyApi(
          failWith: const ApiException('boom', statusCode: 500));
      await expectLater(api.blockUser('U1'), throwsA(isA<ApiException>()));
    });

    test('block endpoints use the documented paths', () async {
      final api = FakeSafetyApi();
      await api.blockUser('U 1');
      await api.unblockUser('U2');
      await api.fetchGroupReports('G1');
      await api.resolveReport('R1', action: 'dismissed');
      expect(api.calls.map((c) => '${c.$1} ${c.$2}'), [
        'POST /api/users/U%201/block',
        'DELETE /api/users/U2/block',
        'GET /api/groups/G1/reports',
        'POST /api/reports/R1/resolve',
      ]);
      expect(api.calls.last.$3, {'action': 'dismissed'});
    });
  });

  group('BlockedUsersController', () {
    test('loads blocks and filters content client-side', () async {
      final controller = BlockedUsersController();
      final api = FakeSafetyApi(blocks: [
        {'user_id': 'U2', 'display_name': 'Bad', 'blocked_at': '2026-01-01T00:00:00Z'},
      ]);
      await controller.load(api);
      expect(controller.isBlocked('U2'), isTrue);
      expect(controller.isBlocked('U3'), isFalse);
      expect(controller.isBlocked(''), isFalse);
      expect(controller.isBlocked(null), isFalse);

      final visible = controller.visible(
        [comment('C1', 'U1'), comment('C2', 'U2'), comment('C3', '')],
        (item) => item.authorId,
      );
      expect(visible.map((item) => item.id), ['C1', 'C3']);
    });

    test('block hides content immediately and unblock restores it', () async {
      final controller = BlockedUsersController();
      final api = FakeSafetyApi();
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.block(api, userId: 'U9', displayName: 'Spammer');
      expect(controller.isBlocked('U9'), isTrue);
      expect(controller.users.single.displayName, 'Spammer');
      expect(notifications, 1);
      expect(
        controller.visible([comment('C1', 'U9')], (c) => c.authorId),
        isEmpty,
      );

      await controller.unblock(api, 'U9');
      expect(controller.isBlocked('U9'), isFalse);
      expect(notifications, 2);
    });

    test('a failed block does not hide content', () async {
      final controller = BlockedUsersController();
      final api = FakeSafetyApi(
          failWith: const ApiException('nope', statusCode: 404));
      await expectLater(
        controller.block(api, userId: 'U9', displayName: 'X'),
        throwsA(isA<FeatureUnavailableException>()),
      );
      expect(controller.isBlocked('U9'), isFalse);
    });

    test('load failure keeps current state; clear forgets everything',
        () async {
      final controller = BlockedUsersController();
      await controller.block(FakeSafetyApi(), userId: 'U1', displayName: 'A');
      await controller.load(FakeSafetyApi(
          failWith: const ApiException('x', statusCode: 404)));
      expect(controller.isBlocked('U1'), isTrue);
      controller.clear();
      expect(controller.blockedIds, isEmpty);
    });
  });

  group('SafetyTarget', () {
    test('never offers report or block for own content', () {
      const own = SafetyTarget(
        targetType: ReportTargetType.comment,
        targetId: 'C1',
        authorId: 'ME',
        authorName: 'Me',
        currentUserId: 'ME',
      );
      expect(own.canReport, isFalse);
      expect(own.canActOnAuthor, isFalse);
      expect(safetyMenuEntries(AppText(AppLanguage.ru), own), isEmpty);
    });

    test('deleted-account content can be reported but not blocked', () {
      const orphan = SafetyTarget(
        targetType: ReportTargetType.comment,
        targetId: 'C1',
        authorId: '',
        authorName: '',
        currentUserId: 'ME',
      );
      expect(orphan.canReport, isTrue);
      expect(orphan.canActOnAuthor, isFalse);
      expect(safetyMenuEntries(AppText(AppLanguage.ru), orphan).length, 1);
    });
  });

  testWidgets('own content renders no safety menu', (tester) async {
    await tester.pumpWidget(harness(ContentSafetyMenuButton(
      api: FakeSafetyApi(),
      target: const SafetyTarget(
        targetType: ReportTargetType.publicRequest,
        targetId: 'P1',
        authorId: 'ME',
        authorName: 'Me',
        currentUserId: 'ME',
      ),
    )));
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('menu offers report, report user and block for others',
      (tester) async {
    await tester.pumpWidget(harness(ContentSafetyMenuButton(
      api: FakeSafetyApi(),
      target: const SafetyTarget(
        targetType: ReportTargetType.publicRequest,
        targetId: 'P1',
        authorId: 'U2',
        authorName: 'Other',
        currentUserId: 'ME',
      ),
    )));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Пожаловаться'), findsOneWidget);
    expect(find.text('Пожаловаться на пользователя'), findsOneWidget);
    expect(find.text('Заблокировать'), findsOneWidget);
  });

  testWidgets('report sheet requires a reason and submits details',
      (tester) async {
    String? sentReason;
    String? sentDetails;
    await tester.pumpWidget(harness(ReportSheet(
      targetType: ReportTargetType.comment,
      onSubmit: (reason, details) async {
        sentReason = reason;
        sentDetails = details;
      },
    )));

    ButtonStyleButton submit() => tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('report_submit_button')));

    for (final reason in ReportReason.values) {
      expect(find.byKey(ValueKey('report_reason_$reason')), findsOneWidget);
    }
    expect(submit().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('report_reason_abuse')));
    await tester.pump();
    expect(submit().onPressed, isNotNull);

    await tester.enterText(
        find.byKey(const ValueKey('report_details_field')), 'Rude words');
    await tester.tap(find.byKey(const ValueKey('report_submit_button')));
    await tester.pumpAndSettle();
    expect(sentReason, 'abuse');
    expect(sentDetails, 'Rude words');
  });

  testWidgets('report flow confirms with a snackbar', (tester) async {
    final api = FakeSafetyApi();
    await tester.pumpWidget(harness(Builder(
      builder: (context) => TextButton(
        onPressed: () => showReportSheet(
          context,
          api: api,
          targetType: ReportTargetType.publicRequest,
          targetId: 'P1',
        ),
        child: const Text('report'),
      ),
    )));
    await tester.tap(find.text('report'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report_reason_spam')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report_submit_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Жалоба отправлена'), findsOneWidget);
    expect(api.calls.single.$3!['target_id'], 'P1');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('missing backend endpoint shows a friendly message',
      (tester) async {
    final api = FakeSafetyApi(
        failWith: const ApiException('Server error 404', statusCode: 404));
    await tester.pumpWidget(harness(Builder(
      builder: (context) => TextButton(
        onPressed: () => showReportSheet(
          context,
          api: api,
          targetType: ReportTargetType.user,
          targetId: 'U2',
        ),
        child: const Text('report'),
      ),
    )));
    await tester.tap(find.text('report'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report_reason_other')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('report_submit_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportSheet), findsNothing);
    expect(find.textContaining('пока недоступна'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('block requires confirmation', (tester) async {
    final controller = BlockedUsersController();
    final api = FakeSafetyApi();
    await tester.pumpWidget(harness(Builder(
      builder: (context) => TextButton(
        onPressed: () => confirmAndBlockUser(
          context,
          api: api,
          userId: 'U2',
          displayName: 'Other',
          controller: controller,
        ),
        child: const Text('block'),
      ),
    )));
    await tester.tap(find.text('block'));
    await tester.pumpAndSettle();
    expect(find.text('Заблокировать Other?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(controller.isBlocked('U2'), isFalse);
    expect(api.calls, isEmpty);

    await tester.tap(find.text('block'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_block_button')));
    await tester.pumpAndSettle();
    expect(controller.isBlocked('U2'), isTrue);
    expect(api.calls.single.$2, '/api/users/U2/block');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
