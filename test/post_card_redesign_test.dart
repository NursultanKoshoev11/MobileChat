import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';
import 'package:koom/data/public_request.dart';
import 'package:koom/features/public_requests/public_request_media_screens.dart';
import 'package:koom/features/public_requests/public_request_media_widgets.dart';
import 'package:koom/features/public_requests/public_requests_widgets.dart';
import 'package:koom/shared/koom_ui.dart';

void main() {
  Future<void> pumpLocalized(
    WidgetTester tester,
    Widget child, {
    AppLanguage language = AppLanguage.ru,
  }) async {
    final controller = AppLanguageController();
    controller.setLanguage(language);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(
          theme: KoomTheme.light,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  PublicRequest request({
    String status = 'under_review',
    String interactionMode = 'discussion',
    int commentCount = 7,
    String? myVote,
  }) {
    return PublicRequest.fromJson({
      'id': 'REQ-CARD',
      'group_id': 'G-1',
      'author_id': 'U-1',
      'author_name': 'Нурсултан',
      'request_type': 'idea',
      'interaction_mode': interactionMode,
      'title': 'Детская площадка во дворе',
      'body': 'Нужна новая площадка.',
      'status': status,
      'support_count': 4,
      'oppose_count': 1,
      'comment_count': commentCount,
      'my_vote': myVote,
      'created_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 3))
          .toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  group('MediaPublicRequestCard', () {
    testWidgets('renders one type chip and the status as a dot', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        MediaPublicRequestCard(
          request: request(),
          onTap: () {},
          onVote: (_) {},
        ),
      );

      // The post type keeps a chip ...
      expect(
        find.byKey(const ValueKey('public_request_type_REQ-CARD')),
        findsOneWidget,
      );
      // ... and it is the only chip on the card: the status is no longer a
      // second shouty pill.
      expect(find.byType(KoomStatusPill), findsOneWidget);

      // The status is a coloured dot plus a quiet label.
      final dot = find.byKey(
        const ValueKey('public_request_status_dot_REQ-CARD'),
      );
      expect(dot, findsOneWidget);
      expect(find.byType(KoomStatusDot), findsOneWidget);
      expect(
        find.descendant(of: dot, matching: find.text('На рассмотрении')),
        findsOneWidget,
      );

      // Calmer typography: nothing on the card is w900 any more.
      final cardTexts = tester
          .widgetList<Text>(find.byType(Text))
          .where((widget) => widget.style?.fontWeight != null);
      expect(
        cardTexts.every(
          (widget) => widget.style!.fontWeight!.index <
              FontWeight.w900.index,
        ),
        isTrue,
      );
    });

    testWidgets('shows the comment count and opens the comments', (
      tester,
    ) async {
      var opened = 0;
      await pumpLocalized(
        tester,
        MediaPublicRequestCard(
          request: request(commentCount: 7),
          onTap: () => opened++,
          onVote: (_) {},
        ),
      );

      final count = find.byKey(
        const ValueKey('public_request_comment_count_REQ-CARD'),
      );
      expect(count, findsOneWidget);
      expect(tester.widget<Text>(count).data, '7');

      // The footer also carries the vote total.
      expect(
        find.byKey(const ValueKey('public_request_vote_total_REQ-CARD')),
        findsOneWidget,
      );
      expect(find.textContaining('Голосов: 5'), findsOneWidget);

      final link = find.byKey(
        const ValueKey('public_request_read_REQ-CARD'),
      );
      expect(link, findsOneWidget);
      // The comment link is a real tap target.
      expect(
        tester.getSize(link).height,
        greaterThanOrEqualTo(kKoomMinTapTarget),
      );
      await tester.tap(link);
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('voting reports the option that was tapped', (tester) async {
      final votes = <String>[];
      await pumpLocalized(
        tester,
        MediaPublicRequestCard(
          request: request(myVote: 'support'),
          onTap: () {},
          onVote: votes.add,
        ),
      );

      expect(find.text('Поддерживаю'), findsOneWidget);
      expect(find.text('Не поддерживаю'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('public_request_support_REQ-CARD')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('public_request_oppose_REQ-CARD')),
      );
      await tester.pump();

      expect(votes, <String>['support', 'oppose']);
    });

    testWidgets('read-only posts show the mode instead of a vote total', (
      tester,
    ) async {
      await pumpLocalized(
        tester,
        MediaPublicRequestCard(
          request: request(interactionMode: 'read_only'),
          onTap: () {},
          onVote: (_) {},
        ),
      );

      expect(
        find.byKey(const ValueKey('public_request_vote_total_REQ-CARD')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('public_request_read_REQ-CARD')),
        findsNothing,
      );
      expect(find.text('Только текст'), findsOneWidget);
    });

    testWidgets('the card is built in Kyrgyz too', (tester) async {
      await pumpLocalized(
        tester,
        MediaPublicRequestCard(
          request: request(),
          onTap: () {},
          onVote: (_) {},
        ),
        language: AppLanguage.ky,
      );

      expect(find.text('Добуш берүү'), findsOneWidget);
      expect(find.text('Колдойм'), findsOneWidget);
      expect(find.text('Колдобойм'), findsOneWidget);
    });
  });

  group('skeleton placeholders', () {
    testWidgets('the comment list placeholder uses skeletons, not a spinner', (
      tester,
    ) async {
      await pumpLocalized(tester, const CommentListSkeleton());

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(KoomSkeleton), findsWidgets);
      // Avatar circle plus text lines for each placeholder row.
      final skeletons = tester.widgetList<KoomSkeleton>(
        find.byType(KoomSkeleton),
      );
      expect(skeletons.any((item) => item.shape == BoxShape.circle), isTrue);
      expect(
        skeletons.any((item) => item.shape != BoxShape.circle),
        isTrue,
      );
    });

    testWidgets('a remote photo shows a skeleton while it loads', (
      tester,
    ) async {
      final content = PublicRequestContent(
        text: '',
        photos: const [
          PublicRequestPhoto(
            name: 'photo.jpg',
            sizeBytes: 1024,
            fileId: 'F-1',
            url: 'https://media.invalid/photo.jpg',
          ),
        ],
        videos: const [],
      );

      await pumpLocalized(
        tester,
        PublicRequestMediaView(content: content),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(KoomSkeleton), findsWidgets);
    });
  });

  test('the new labels are written in both languages', () {
    const ru = AppText(AppLanguage.ru);
    const ky = AppText(AppLanguage.ky);
    final pairs = <String, List<String>>{
      'unnamedUser': [ru.unnamedUser, ky.unnamedUser],
      'voting': [ru.voting, ky.voting],
      'votesLabel': [ru.votesLabel, ky.votesLabel],
      'voteSupport': [ru.voteSupport, ky.voteSupport],
      'voteOppose': [ru.voteOppose, ky.voteOppose],
      'voteToggleHint': [ru.voteToggleHint, ky.voteToggleHint],
      'justNow': [ru.justNow, ky.justNow],
      'minuteShort': [ru.minuteShort, ky.minuteShort],
      'hourShort': [ru.hourShort, ky.hourShort],
      'dayShort': [ru.dayShort, ky.dayShort],
      'moreActions': [ru.moreActions, ky.moreActions],
      'deleteItem': [ru.deleteItem, ky.deleteItem],
      'sendComment': [ru.sendComment, ky.sendComment],
      'beFirstToComment': [ru.beFirstToComment, ky.beFirstToComment],
      'photosLabel': [ru.photosLabel, ky.photosLabel],
      'videosLabel': [ru.videosLabel, ky.videosLabel],
      'mediaUnavailable': [ru.mediaUnavailable, ky.mediaUnavailable],
      'photoTooLarge': [ru.photoTooLarge, ky.photoTooLarge],
      'videoTooLarge': [ru.videoTooLarge, ky.videoTooLarge],
      'mediaLimitsHint': [ru.mediaLimitsHint, ky.mediaLimitsHint],
      'addTextOrMedia': [ru.addTextOrMedia, ky.addTextOrMedia],
      'addVideo': [ru.addVideo, ky.addVideo],
      'videoAdded': [ru.videoAdded, ky.videoAdded],
      'photoLabel': [ru.photoLabel, ky.photoLabel],
    };
    pairs.forEach((name, values) {
      expect(values.first, isNotEmpty, reason: '$name has no Russian text');
      expect(values.last, isNotEmpty, reason: '$name has no Kyrgyz text');
      expect(
        values.last,
        isNot(values.first),
        reason: '$name repeats the Russian text instead of Kyrgyz',
      );
    });
  });

  test('relative time is localized and falls back to a date', () {
    const ru = AppText(AppLanguage.ru);
    const ky = AppText(AppLanguage.ky);
    final now = DateTime(2026, 11, 24, 12);

    expect(
      koomRelativeTime(ru, now.subtract(const Duration(seconds: 20)), now: now),
      'только что',
    );
    expect(
      koomRelativeTime(ky, now.subtract(const Duration(seconds: 20)), now: now),
      'азыр эле',
    );
    expect(
      koomRelativeTime(ru, now.subtract(const Duration(minutes: 7)), now: now),
      '7 мин',
    );
    expect(
      koomRelativeTime(ky, now.subtract(const Duration(hours: 4)), now: now),
      '4 саат',
    );
    expect(
      koomRelativeTime(ru, now.subtract(const Duration(days: 3)), now: now),
      '3 дн',
    );
    expect(
      koomRelativeTime(ru, DateTime(2026, 3, 5), now: now),
      '05.03.2026',
    );
  });
}
