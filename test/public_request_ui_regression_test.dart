import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/app/localization.dart';
import 'package:mobile_chat/app/theme.dart';
import 'package:mobile_chat/data/public_request.dart';
import 'package:mobile_chat/features/public_requests/public_request_media_screens.dart';
import 'package:mobile_chat/features/public_requests/public_request_media_widgets.dart';

void main() {
  Future<void> pumpLocalized(WidgetTester tester, Widget child) async {
    final language = AppLanguageController();
    addTearDown(language.dispose);
    await tester.pumpWidget(
      AppLanguageScope(
        controller: language,
        child: MaterialApp(
          theme: MobileChatTheme.light,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  PublicRequest request({String body = 'Полный текст публикации'}) {
    return PublicRequest.fromJson({
      'id': 'REQ-UI',
      'group_id': 'G-1',
      'author_id': 'U-1',
      'author_name': 'Нурсултан',
      'request_type': 'idea',
      'interaction_mode': 'discussion',
      'title': 'Публикация',
      'body': body,
      'status': 'new',
      'support_count': 2,
      'oppose_count': 1,
      'comment_count': 3,
      'created_at': '2026-07-14T00:00:00Z',
      'updated_at': '2026-07-14T00:00:00Z',
    });
  }

  testWidgets('opened publication hides the extra open action', (tester) async {
    final longBody = List.filled(12, 'Полный текст').join(' ');
    await pumpLocalized(
      tester,
      SingleChildScrollView(
        child: MediaPublicRequestCard(
          request: request(body: longBody),
          onTap: () {},
          onVote: (_) {},
          compact: false,
          showOpenAction: false,
        ),
      ),
    );

    expect(
        find.byKey(const ValueKey('public_request_read_REQ-UI')), findsNothing);
    final bodyText = tester.widget<Text>(find.text(longBody));
    expect(bodyText.maxLines, isNull);
    expect(bodyText.overflow, TextOverflow.visible);
  });

  testWidgets('photo opens in a full-screen contain viewer', (tester) async {
    const onePixelPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Zx9sAAAAASUVORK5CYII=';
    final content = PublicRequestContent(
      text: '',
      photos: const [
        PublicRequestPhoto(
          name: 'photo.png',
          sizeBytes: 68,
          base64Data: onePixelPng,
        ),
      ],
    );

    await pumpLocalized(
      tester,
      Center(child: PublicRequestMediaView(content: content)),
    );

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images.any((image) => image.fit == BoxFit.contain), isTrue);
  });

  test('vote updates stay local and group actions are not duplicated', () {
    final source = File(
      'lib/features/public_requests/public_requests_screen.dart',
    ).readAsStringSync();

    final voteStart = source.indexOf('Future<void> vote(');
    final statusStart = source.indexOf('Future<void> updateStatus(', voteStart);
    expect(voteStart, greaterThanOrEqualTo(0));
    expect(statusStart, greaterThan(voteStart));
    final voteBody = source.substring(voteStart, statusStart);
    expect(voteBody, isNot(contains('refresh(')));
    expect(voteBody, isNot(contains('requestsFuture =')));

    final setRequestsStart = source.indexOf('void setRequests(');
    final currentRequestStart = source.indexOf(
      'PublicRequest currentRequest(',
      setRequestsStart,
    );
    final setRequestsBody = source.substring(
      setRequestsStart,
      currentRequestStart,
    );
    expect(setRequestsBody, isNot(contains('requestsFuture =')));

    final overviewStart = source.indexOf('class _CommunityOverview');
    final whitePillStart = source.indexOf('class _WhitePill', overviewStart);
    final overviewBody = source.substring(overviewStart, whitePillStart);
    expect(overviewBody, isNot(contains('KoomIconTile(')));
    expect(overviewBody, isNot(contains('onStatistics')));
    expect(overviewBody, isNot(contains('onAccess')));

    final mediaSource = File(
      'lib/features/public_requests/public_request_media_widgets.dart',
    ).readAsStringSync();
    expect(
      mediaSource,
      contains('openPublicRequestRemotePhoto(context, remoteUrl)'),
    );
    expect(mediaSource, contains('child: FittedBox('));
    expect(mediaSource, contains('fit: BoxFit.contain'));
  });
}
