import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_chat/data/api_client.dart';
import 'package:mobile_chat/data/group_invitation.dart';
import 'package:mobile_chat/data/models.dart';
import 'package:mobile_chat/data/public_request.dart';
import 'package:mobile_chat/data/public_requests_api.dart';
import 'package:mobile_chat/data/session_store.dart';
import 'package:mobile_chat/main.dart' as app;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://koom.servemp3.com',
);
const testPhone = String.fromEnvironment(
  'TEST_AUTH_PHONE',
  defaultValue: '+996555555555',
);
const testActor2Phone = String.fromEnvironment(
  'TEST_ACTOR2_PHONE',
  defaultValue: '+996700000001',
);
const testActor3Phone = String.fromEnvironment(
  'TEST_ACTOR3_PHONE',
  defaultValue: '+996700000002',
);
const testActor4Phone = String.fromEnvironment(
  'TEST_ACTOR4_PHONE',
  defaultValue: '+996700000003',
);
const testActor5Phone = String.fromEnvironment(
  'TEST_ACTOR5_PHONE',
  defaultValue: '+996700000004',
);
const testCode = String.fromEnvironment(
  'TEST_AUTH_CODE',
  defaultValue: '111111',
);
const testDisplayName = String.fromEnvironment(
  'TEST_AUTH_DISPLAY_NAME',
  defaultValue: 'Koom QA Owner',
);
const testActor2DisplayName = String.fromEnvironment(
  'TEST_ACTOR2_DISPLAY_NAME',
  defaultValue: 'Koom QA Supporter',
);
const testActor3DisplayName = String.fromEnvironment(
  'TEST_ACTOR3_DISPLAY_NAME',
  defaultValue: 'Koom QA Opponent',
);
const testActor4DisplayName = String.fromEnvironment(
  'TEST_ACTOR4_DISPLAY_NAME',
  defaultValue: 'Koom QA Observer',
);
const testActor5DisplayName = String.fromEnvironment(
  'TEST_ACTOR5_DISPLAY_NAME',
  defaultValue: 'Koom QA Reviewer',
);
const expectedUserRole = String.fromEnvironment(
  'TEST_EXPECTED_USER_ROLE',
  defaultValue: 'user',
);
const expectedGroupRole = String.fromEnvironment(
  'TEST_EXPECTED_GROUP_ROLE',
  defaultValue: 'owner',
);
const tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase Test Lab five-person working group flow',
      (tester) async {
    final crew = await authenticateCrew();
    await preflightAccountRole(crew.primary);
    await (const SessionStore()).clear();

    app.main();
    await settle(tester, seconds: 5);

    await loginIfNeeded(tester);
    await waitForKey(tester, 'groups_screen', seconds: 20);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final groupTitle = 'QA Auto Group $stamp';
    final postTitle = 'QA Discussion $stamp';
    final postBody = 'Automated Firebase Test Lab discussion body $stamp.';
    final voteOnlyTitle = 'QA Vote Only $stamp';
    final readOnlyTitle = 'QA Read Only $stamp';
    final supporterPostTitle = 'QA Supporter Idea $stamp';
    final observerPostTitle = 'QA Observer Report $stamp';
    final reviewerPostTitle = 'QA Reviewer Review $stamp';
    final commentBody = 'Owner UI comment $stamp.';
    final realtimeCommentBody = 'Realtime API comment $stamp.';

    await openOrCreateGroup(tester, groupTitle);
    await waitForKey(tester, 'public_requests_screen', seconds: 25);

    await exerciseGroupOwnerToolsBeforeMembers(tester);

    await createDiscussionPost(tester, postTitle, postBody);
    await waitForText(tester, postTitle, seconds: 25);
    var createdRequest = await waitForRequestByTitle(postTitle);
    expect(createdRequest.displayBody, postBody);

    await ensureCrewMembership(
      crew: crew,
      groupId: createdRequest.groupId,
    );
    await exerciseGroupOwnerToolsAfterMembers(tester);
    await exerciseFivePersonWorkingGroupFlow(
      crew: crew,
      groupId: createdRequest.groupId,
      mainRequestId: createdRequest.id,
      observerPostTitle: observerPostTitle,
      reviewerPostTitle: reviewerPostTitle,
      stamp: stamp,
    );
    await exerciseAdministrativeApiFlows(
      crew: crew,
      groupId: createdRequest.groupId,
      requestId: createdRequest.id,
      stamp: stamp,
    );
    await exercisePlatformApiFlows(
      crew: crew,
      groupId: createdRequest.groupId,
      stamp: stamp,
    );
    final mediaRequest = await exerciseMediaUploadAndRenderFlow(
      tester: tester,
      crew: crew,
      groupId: createdRequest.groupId,
      stamp: stamp,
    );

    await crew.primary.requestsApi.createRequest(
      groupId: createdRequest.groupId,
      type: 'problem',
      interactionMode: 'vote_only',
      title: voteOnlyTitle,
      body: 'Vote-only Firebase Test Lab body $stamp.',
    );
    await crew.primary.requestsApi.createRequest(
      groupId: createdRequest.groupId,
      type: 'announcement',
      interactionMode: 'read_only',
      title: readOnlyTitle,
      body: 'Read-only Firebase Test Lab announcement $stamp.',
    );
    await crew.supporter.requestsApi.createRequest(
      groupId: createdRequest.groupId,
      type: 'idea',
      interactionMode: 'discussion',
      title: supporterPostTitle,
      body: 'Second actor creates a discussion publication $stamp.',
    );

    await refreshPublicRequests(tester);
    await waitForText(tester, voteOnlyTitle, seconds: 25);
    await waitForText(tester, readOnlyTitle, seconds: 25);
    await waitForText(tester, supporterPostTitle, seconds: 25);
    await waitForRequestByTitle(observerPostTitle, seconds: 25);
    await waitForRequestByTitle(reviewerPostTitle, seconds: 25);
    await waitForRequestByTitle(
      mediaRequest.title,
      matcher: (request) => request.content.photos.isNotEmpty,
      reason: 'Media publication must keep photo metadata in the API.',
    );

    await exercisePublishedPostActions(
      tester,
      requestId: createdRequest.id,
      title: postTitle,
    );

    await crew.supporter.requestsApi.support(createdRequest.id);
    await crew.opponent.requestsApi.oppose(createdRequest.id);
    await crew.observer.requestsApi.support(createdRequest.id);
    await crew.reviewer.requestsApi.oppose(createdRequest.id);
    await crew.supporter.requestsApi.support(
      (await waitForRequestByTitle(voteOnlyTitle)).id,
    );
    await crew.opponent.requestsApi.oppose(
      (await waitForRequestByTitle(voteOnlyTitle)).id,
    );

    await exerciseModerationStatusAction(tester, createdRequest.id);
    createdRequest = await waitForRequestByTitle(
      postTitle,
      matcher: (request) => request.status == 'under_review',
      reason: 'Moderation status must update through the API immediately.',
    );

    await crew.supporter.requestsApi.addComment(
      requestId: createdRequest.id,
      body: realtimeCommentBody,
    );
    await crew.opponent.requestsApi.addComment(
      requestId: createdRequest.id,
      body: 'Opponent API comment $stamp.',
    );

    await waitForRequestByTitle(
      postTitle,
      matcher: (request) =>
          request.supportCount >= 2 &&
          request.opposeCount >= 3 &&
          request.commentCount >= 5,
      reason: 'Five-person votes and comments must update request counters.',
    );

    await openPostDetails(tester, createdRequest.id);
    await waitForKey(tester, 'comment_field', seconds: 15);

    await waitForCommentByBody(createdRequest.id, realtimeCommentBody);
    await refreshRequestDetailsComments(tester);
    await waitForVisibleText(tester, realtimeCommentBody, seconds: 25);

    await enterTextByKey(tester, 'comment_field', commentBody);
    await tapByKey(tester, 'comment_submit_button');
    await waitForCommentSubmission(tester, commentBody, seconds: 25);
    await waitForCommentByBody(createdRequest.id, commentBody);

    final comments = await crew.primary.requestsApi.listComments(
      createdRequest.id,
    );
    expect(
      comments.map((comment) => comment.body),
      containsAll(<String>[commentBody, realtimeCommentBody]),
    );

    final voteOnlyRequest = await waitForRequestByTitle(
      voteOnlyTitle,
      matcher: (request) =>
          request.supportCount >= 1 && request.opposeCount >= 1,
      reason: 'Vote-only publication must collect votes from two actors.',
    );
    expect(voteOnlyRequest.interactionMode, 'vote_only');

    final readOnlyRequest = await waitForRequestByTitle(readOnlyTitle);
    expect(readOnlyRequest.interactionMode, 'read_only');

    await safeBack(tester);
    await waitForKey(tester, 'public_requests_screen', seconds: 10);
    await refreshPublicRequests(tester);
    await openPostDetails(tester, mediaRequest.id);
    await waitForKey(tester, 'public_request_media_view', seconds: 15);
    await scrollUntilKeyVisible(
      tester,
      'public_request_media_photos',
      seconds: 15,
    );
    await safeBack(tester);

    await waitForStatistics(
      actor: crew.primary,
      groupId: createdRequest.groupId,
      minRequests: 5,
      minComments: 7,
      minSupportVotes: 2,
      minOpposeVotes: 3,
    );

    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<QaCrew> authenticateCrew() async {
  final primary = QaActor(
    name: 'primary',
    phone: testPhone,
    displayName: testDisplayName,
  );
  final supporter = QaActor(
    name: 'supporter',
    phone: testActor2Phone,
    displayName: testActor2DisplayName,
  );
  final opponent = QaActor(
    name: 'opponent',
    phone: testActor3Phone,
    displayName: testActor3DisplayName,
  );
  final observer = QaActor(
    name: 'observer',
    phone: testActor4Phone,
    displayName: testActor4DisplayName,
  );
  final reviewer = QaActor(
    name: 'reviewer',
    phone: testActor5Phone,
    displayName: testActor5DisplayName,
  );

  for (final actor in <QaActor>[
    primary,
    supporter,
    opponent,
    observer,
    reviewer,
  ]) {
    await actor.signIn();
  }

  final ids = <String>{
    primary.session.user.id,
    supporter.session.user.id,
    opponent.session.user.id,
    observer.session.user.id,
    reviewer.session.user.id,
  };
  expect(
    ids.length,
    5,
    reason:
        'Firebase QA needs five different test phones/users. Configure TEST_AUTH_PHONE and TEST_ACTOR2_PHONE through TEST_ACTOR5_PHONE.',
  );

  return QaCrew(
    primary: primary,
    supporter: supporter,
    opponent: opponent,
    observer: observer,
    reviewer: reviewer,
  );
}

Future<void> preflightAccountRole(QaActor primary) async {
  final expectedRole = expectedUserRole.trim();
  if (expectedRole.isNotEmpty && expectedRole != 'any') {
    expect(
      primary.session.user.role,
      expectedRole,
      reason:
          'TEST_AUTH_PHONE=$testPhone must be configured as $expectedRole on $apiBaseUrl.',
    );
  }

  final expectedMembership = expectedGroupRole.trim();
  if (expectedMembership.isEmpty || expectedMembership == 'any') return;

  final allowedRoles =
      expectedMembership.split(',').map((role) => role.trim()).toSet();
  final groups = await primary.api.fetchGroups();
  expect(
    groups.any((group) => allowedRoles.contains(group.myRole)),
    isTrue,
    reason:
        'TEST_AUTH_PHONE=$testPhone must have one of these group roles: $expectedMembership.',
  );
}

Future<void> loginIfNeeded(WidgetTester tester) async {
  if (find.byKey(const ValueKey('auth_mobile_field')).evaluate().isEmpty) {
    return;
  }

  await enterTextByKey(tester, 'auth_mobile_field', testPhone);
  await tapByKey(tester, 'auth_submit_button');
  await waitForKey(tester, 'auth_code_field', seconds: 15);

  await enterTextByKey(tester, 'auth_code_field', testCode);
  if (find
      .byKey(const ValueKey('auth_display_name_field'))
      .evaluate()
      .isNotEmpty) {
    await enterTextByKey(tester, 'auth_display_name_field', testDisplayName);
  }

  await tapByKey(tester, 'auth_submit_button');
  await waitForKey(tester, 'groups_screen', seconds: 25);
}

Future<void> openOrCreateGroup(WidgetTester tester, String groupTitle) async {
  await tapCreateGroupAction(tester);
  await settle(tester, seconds: 3);

  final openedCreateGroupSheet =
      find.byType(BottomSheet).evaluate().isNotEmpty &&
          find.byType(EditableText).evaluate().length >= 2;

  if (openedCreateGroupSheet) {
    await enterEditableTextAt(tester, 0, groupTitle);
    await enterEditableTextAt(tester, 1, 'Created by Firebase Test Lab.');
    await tapLastFilledButton(tester);
    await waitForKey(tester, 'public_requests_screen', seconds: 25);
    return;
  }

  await safeBack(tester);
  await settle(tester, seconds: 2);

  if (await openFirstVisibleGroup(tester)) return;

  await joinFirstPublicGroupForNonAdmin(tester);
  await refreshGroups(tester);
  if (await openFirstVisibleGroup(tester)) return;

  fail(
    'No group is available for the QA flow. Use a platform_admin/super_admin '
    'TEST_AUTH_PHONE to create groups, or keep at least one public group joinable.',
  );
}

Future<void> tapCreateGroupAction(WidgetTester tester) async {
  if (find
      .byKey(const ValueKey('groups_create_action'))
      .evaluate()
      .isNotEmpty) {
    await tapByKey(tester, 'groups_create_action');
    return;
  }
  await tapByKey(tester, 'groups_empty_create_action');
}

Future<bool> openFirstVisibleGroup(WidgetTester tester) async {
  final tiles = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key as ValueKey<String>).value.startsWith('group_tile_'),
  );
  if (tiles.evaluate().isEmpty) return false;
  await tester.tap(tiles.first, warnIfMissed: false);
  await settle(tester, seconds: 5);
  return find
      .byKey(const ValueKey('public_requests_screen'))
      .evaluate()
      .isNotEmpty;
}

Future<void> joinFirstPublicGroupForNonAdmin(WidgetTester tester) async {
  final api =
      ApiClient(baseUrl: apiBaseUrl, sessionStore: const SessionStore());
  final groups = await api.searchPublicGroups('');
  if (groups.isEmpty) return;
  try {
    await api.joinPublicGroup(groups.first.id);
  } catch (_) {
    // Already joined or forbidden groups should not hide the real UI failure.
  }
}

Future<void> refreshGroups(WidgetTester tester) async {
  if (find.byType(Scrollable).evaluate().isEmpty) return;
  await tester.fling(find.byType(Scrollable).first, const Offset(0, 350), 800);
  await settle(tester, seconds: 5);
}

Future<void> createDiscussionPost(
  WidgetTester tester,
  String title,
  String body,
) async {
  await tapByKey(tester, 'public_request_create_action');
  await waitForKey(tester, 'post_title_field', seconds: 15);

  await enterTextByKey(tester, 'post_title_field', title);
  await enterTextByKey(tester, 'post_body_field', body);

  await tester.tap(
    find.byKey(const ValueKey('post_mode_dropdown')),
    warnIfMissed: false,
  );
  await settle(tester, seconds: 1);
  if (find
      .byKey(const ValueKey('post_mode_discussion'))
      .evaluate()
      .isNotEmpty) {
    await tester.tap(
      find.byKey(const ValueKey('post_mode_discussion')).last,
      warnIfMissed: false,
    );
    await settle(tester, seconds: 1);
  }

  await tapByKey(tester, 'post_submit_button');
  await settle(tester, seconds: 8);
}

Future<void> exercisePublishedPostActions(
  WidgetTester tester, {
  required String requestId,
  required String title,
}) async {
  await tapPublicRequestAction(tester, 'public_request_support_$requestId');
  await waitForRequestByTitle(
    title,
    matcher: (request) => request.supportCount >= 1,
    reason: 'Owner support vote must update request counters through the API.',
  );

  await tapPublicRequestAction(tester, 'public_request_oppose_$requestId');
  await waitForRequestByTitle(
    title,
    matcher: (request) => request.opposeCount >= 1,
    reason: 'Owner oppose vote must update request counters through the API.',
  );
}

Future<void> exerciseGroupOwnerToolsBeforeMembers(WidgetTester tester) async {
  await openGroupMenuAction(tester, 'statistics');
  await waitForKey(tester, 'group_statistics_screen', seconds: 20);
  await safeBack(tester);

  await openGroupMenuAction(tester, 'access');
  await waitForKey(tester, 'group_access_sheet', seconds: 15);
  await safeBack(tester);

  await openGroupMenuAction(tester, 'admins');
  await waitForKey(tester, 'manage_admin_phone_field', seconds: 15);
  await waitForKey(tester, 'manage_admin_make_button', seconds: 5);
  await waitForKey(tester, 'manage_admin_remove_button', seconds: 5);
  await safeBack(tester);

  await openGroupMenuAction(tester, 'invite');
  await waitForKey(tester, 'invite_phone_field', seconds: 15);
  await waitForKey(tester, 'invite_phone_submit_button', seconds: 5);
  await safeBack(tester);

  await openGroupMenuAction(tester, 'moderation');
  await waitForKey(tester, 'moderation_screen', seconds: 20);
  await safeBack(tester);

  await openGroupMenuAction(tester, 'settings');
  await waitForKey(tester, 'app_settings_sheet', seconds: 10);
  await safeBack(tester);
}

Future<void> exerciseGroupOwnerToolsAfterMembers(WidgetTester tester) async {
  await openGroupMenuAction(tester, 'mute');
  await waitForKey(tester, 'comment_mute_sheet', seconds: 15);
  await waitForKey(tester, 'comment_mute_member_dropdown', seconds: 10);
  await waitForKey(tester, 'comment_mute_duration_dropdown', seconds: 10);
  await waitForKey(tester, 'comment_mute_reason_field', seconds: 10);
  await safeBack(tester);
}

Future<void> exerciseFivePersonWorkingGroupFlow({
  required QaCrew crew,
  required String groupId,
  required String mainRequestId,
  required String observerPostTitle,
  required String reviewerPostTitle,
  required int stamp,
}) async {
  await exerciseInvitationDeclineAcceptFlow(
    owner: crew.primary,
    actor: crew.reviewer,
    groupId: groupId,
  );

  await exerciseGroupConversation(
    crew: crew,
    groupId: groupId,
    stamp: stamp,
  );

  final observerPost = await crew.observer.requestsApi.createRequest(
    groupId: groupId,
    type: 'problem',
    interactionMode: 'discussion',
    title: observerPostTitle,
    body: 'Observer creates a real working-group report $stamp.',
  );
  final reviewerPost = await crew.reviewer.requestsApi.createRequest(
    groupId: groupId,
    type: 'suggestion',
    interactionMode: 'discussion',
    title: reviewerPostTitle,
    body: 'Reviewer creates a follow-up suggestion $stamp.',
  );

  await crew.primary.requestsApi.support(observerPost.id);
  await crew.supporter.requestsApi.support(observerPost.id);
  await crew.opponent.requestsApi.oppose(observerPost.id);
  await crew.reviewer.requestsApi.addComment(
    requestId: observerPost.id,
    body: 'Reviewer asks for details on observer report $stamp.',
  );
  await crew.primary.requestsApi.updateStatus(
    requestId: observerPost.id,
    status: 'under_review',
  );

  await crew.primary.requestsApi.support(reviewerPost.id);
  await crew.observer.requestsApi.addComment(
    requestId: reviewerPost.id,
    body: 'Observer discusses reviewer suggestion $stamp.',
  );

  final crossComments = <QaActor, String>{
    crew.supporter: 'Supporter discusses owner publication $stamp.',
    crew.opponent: 'Opponent challenges owner publication $stamp.',
    crew.observer: 'Observer adds field details $stamp.',
    crew.reviewer: 'Reviewer adds admin-facing summary $stamp.',
  };
  for (final entry in crossComments.entries) {
    await entry.key.requestsApi.addComment(
      requestId: mainRequestId,
      body: entry.value,
    );
    await waitForCommentByBody(
      mainRequestId,
      entry.value,
      actor: crew.primary,
    );
  }

  await exerciseOneHourCommentBlock(
    admin: crew.primary,
    mutedActor: crew.observer,
    requestId: mainRequestId,
    groupId: groupId,
    stamp: stamp,
  );

  await crew.primary.requestsApi.updateGroupMemberRoleByPhone(
    groupId: groupId,
    phone: crew.reviewer.phone,
    role: 'admin',
  );
  await waitForGroupMemberRole(
    actor: crew.primary,
    groupId: groupId,
    phone: crew.reviewer.phone,
    role: 'admin',
  );
  await crew.primary.requestsApi.updateGroupMemberRoleByPhone(
    groupId: groupId,
    phone: crew.reviewer.phone,
    role: 'member',
  );
  await waitForGroupMemberRole(
    actor: crew.primary,
    groupId: groupId,
    phone: crew.reviewer.phone,
    role: 'member',
  );
}

Future<void> exerciseAdministrativeApiFlows({
  required QaCrew crew,
  required String groupId,
  required String requestId,
  required int stamp,
}) async {
  await crew.primary.requestsApi.updateGroupMemberRoleByPhone(
    groupId: groupId,
    phone: crew.supporter.phone,
    role: 'admin',
  );
  await waitForGroupMemberRole(
    actor: crew.primary,
    groupId: groupId,
    phone: crew.supporter.phone,
    role: 'admin',
  );

  await crew.primary.requestsApi.updateGroupMemberRoleByPhone(
    groupId: groupId,
    phone: crew.supporter.phone,
    role: 'member',
  );
  await waitForGroupMemberRole(
    actor: crew.primary,
    groupId: groupId,
    phone: crew.supporter.phone,
    role: 'member',
  );

  await crew.primary.requestsApi.setCommentMuteByPhone(
    groupId: groupId,
    phone: crew.supporter.phone,
    durationMinutes: 60,
    reason: 'Firebase Test Lab mute check $stamp',
  );
  await crew.primary.requestsApi.clearCommentMuteByPhone(
    groupId: groupId,
    phone: crew.supporter.phone,
  );

  final tempComment = await crew.supporter.requestsApi.addComment(
    requestId: requestId,
    body: 'Temporary delete check $stamp.',
  );
  await waitForCommentByBody(
    requestId,
    tempComment.body,
    actor: crew.primary,
  );
  await crew.primary.requestsApi.deleteComment(tempComment.id);
  await waitForCommentDeleted(
    actor: crew.primary,
    requestId: requestId,
    commentId: tempComment.id,
  );
}

Future<void> exercisePlatformApiFlows({
  required QaCrew crew,
  required String groupId,
  required int stamp,
}) async {
  final token = await crew.primary.api.issueWebSocketToken();
  expect(token.trim(), isNotEmpty);

  final pushToken = 'firebase-test-lab-$stamp';
  await crew.primary.api
      .registerPushToken(token: pushToken, platform: 'android');
  await crew.primary.api.deletePushToken(token: pushToken, platform: 'android');

  final messageText = 'Firebase chat message $stamp';
  final sent = await crew.supporter.api.sendMessage(
    groupId: groupId,
    text: messageText,
  );
  expect(sent.text, messageText);
  await waitForChatMessage(
    actor: crew.primary,
    groupId: groupId,
    messageText: messageText,
  );

  final groupWithInvite =
      await crew.primary.requestsApi.ensureGroupInviteCode(groupId);
  final inviteCode = groupWithInvite.inviteCode ?? '';
  expect(inviteCode.trim(), isNotEmpty);

  await crew.opponent.requestsApi.leaveGroup(groupId);
  await waitForActorLeftGroup(crew.opponent, groupId);
  final rejoined = await crew.opponent.api.joinByInviteCode(inviteCode);
  expect(rejoined.id, groupId);
  await waitForActorInGroup(crew.opponent, groupId);

  await expectLater(
    crew.opponent.api.joinByInviteCode('INV1.INVALID-$stamp'),
    throwsA(isA<ApiException>()),
  );

  await exerciseNegativeAuthFlow(stamp);
}

Future<PublicRequest> exerciseMediaUploadAndRenderFlow({
  required WidgetTester tester,
  required QaCrew crew,
  required String groupId,
  required int stamp,
}) async {
  final photoBytes = base64Decode(tinyPngBase64);
  final uploaded = await crew.primary.requestsApi.uploadPublicRequestFile(
    groupId: groupId,
    kind: 'photo',
    fileName: 'firebase-test-lab-$stamp.png',
    bytes: photoBytes,
  );
  expect(
    (uploaded['id'] ?? uploaded['url'] ?? '').toString().trim(),
    isNotEmpty,
  );

  final title = 'QA Media $stamp';
  final content = PublicRequestContent(
    text: 'Media Firebase Test Lab body $stamp.',
    photos: [
      PublicRequestPhoto(
        name: 'inline-photo-$stamp.png',
        sizeBytes: photoBytes.length,
        base64Data: tinyPngBase64,
      ),
    ],
  ).toPayload();
  final request = await crew.primary.requestsApi.createRequest(
    groupId: groupId,
    type: 'idea',
    interactionMode: 'discussion',
    title: title,
    body: content,
  );
  expect(request.content.hasMedia, isTrue);
  await refreshPublicRequests(tester);
  await waitForRequestByTitle(
    title,
    matcher: (request) => request.content.photos.length == 1,
    reason: 'Media request must be visible through the API.',
  );
  return request;
}

Future<void> exerciseNegativeAuthFlow(int stamp) async {
  final store = MemorySessionStore();
  final api = ApiClient(baseUrl: apiBaseUrl, sessionStore: store);
  await api.requestPhoneCode(testActor2Phone);
  await expectLater(
    api.verifyPhoneCode(
      mobile: testActor2Phone,
      code: '000000',
      displayName: 'Wrong Code $stamp',
    ),
    throwsA(isA<ApiException>()),
  );
  expect(await store.read(), isNull);
}

Future<void> exerciseModerationStatusAction(
  WidgetTester tester,
  String requestId,
) async {
  await tapPublicRequestAction(tester, 'public_request_status_$requestId');
  await tapByKey(tester, 'public_request_status_under_review');
  await settle(tester, seconds: 4);
}

Future<void> ensureCrewMembership({
  required QaCrew crew,
  required String groupId,
}) async {
  for (final actor in <QaActor>[
    crew.supporter,
    crew.opponent,
    crew.observer,
    crew.reviewer,
  ]) {
    await ensureActorGroupMembership(
      owner: crew.primary,
      actor: actor,
      groupId: groupId,
    );
  }
}

Future<void> exerciseInvitationDeclineAcceptFlow({
  required QaActor owner,
  required QaActor actor,
  required String groupId,
}) async {
  if (await actorHasGroup(actor, groupId)) {
    try {
      await actor.requestsApi.leaveGroup(groupId);
      await waitForActorLeftGroup(actor, groupId);
    } catch (_) {
      return;
    }
  }

  try {
    await owner.api.inviteUserByPhone(groupId: groupId, mobile: actor.phone);
    final firstInvite = await waitForInvitation(
      actor: actor,
      groupId: groupId,
      seconds: 15,
    );
    await actor.api.declineInvitation(firstInvite.id);
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await actorHasGroup(actor, groupId), isFalse);

    await owner.api.inviteUserByPhone(groupId: groupId, mobile: actor.phone);
    final secondInvite = await waitForInvitation(
      actor: actor,
      groupId: groupId,
      seconds: 15,
    );
    await actor.api.acceptInvitation(secondInvite.id);
    await waitForActorInGroup(actor, groupId);
  } catch (_) {
    await ensureActorGroupMembership(
      owner: owner,
      actor: actor,
      groupId: groupId,
    );
  }
}

Future<void> exerciseGroupConversation({
  required QaCrew crew,
  required String groupId,
  required int stamp,
}) async {
  final messages = <QaActor, String>{
    crew.primary: 'Owner opens working group chat $stamp.',
    crew.supporter: 'Supporter confirms the plan $stamp.',
    crew.opponent: 'Opponent raises a risk $stamp.',
    crew.observer: 'Observer shares field note $stamp.',
    crew.reviewer: 'Reviewer records admin summary $stamp.',
  };

  for (final entry in messages.entries) {
    final sent = await entry.key.api.sendMessage(
      groupId: groupId,
      text: entry.value,
    );
    expect(sent.text, entry.value);
  }

  for (final message in messages.values) {
    await waitForChatMessage(
      actor: crew.primary,
      groupId: groupId,
      messageText: message,
    );
  }
}

Future<void> exerciseOneHourCommentBlock({
  required QaActor admin,
  required QaActor mutedActor,
  required String requestId,
  required String groupId,
  required int stamp,
}) async {
  final blockedBody = 'Muted actor should not post this $stamp.';
  final restoredBody = 'Muted actor can comment after unblock $stamp.';

  await admin.requestsApi.setCommentMuteByPhone(
    groupId: groupId,
    phone: mutedActor.phone,
    durationMinutes: 60,
    reason: 'Firebase Test Lab one-hour block $stamp',
  );

  await expectLater(
    mutedActor.requestsApi.addComment(
      requestId: requestId,
      body: blockedBody,
    ),
    throwsA(isA<ApiException>()),
  );
  final commentsWhileMuted = await admin.requestsApi.listComments(requestId);
  expect(
    commentsWhileMuted.map((comment) => comment.body),
    isNot(contains(blockedBody)),
  );

  await admin.requestsApi.clearCommentMuteByPhone(
    groupId: groupId,
    phone: mutedActor.phone,
  );
  await mutedActor.requestsApi.addComment(
    requestId: requestId,
    body: restoredBody,
  );
  await waitForCommentByBody(
    requestId,
    restoredBody,
    actor: admin,
  );
}

Future<void> ensureActorGroupMembership({
  required QaActor owner,
  required QaActor actor,
  required String groupId,
}) async {
  if (await actorHasGroup(actor, groupId)) return;

  try {
    await actor.api.joinPublicGroup(groupId);
  } catch (_) {}
  if (await actorHasGroup(actor, groupId)) return;

  try {
    await owner.api.inviteUserByPhone(groupId: groupId, mobile: actor.phone);
  } catch (_) {}
  try {
    final invites = await actor.api.fetchInvitations();
    for (final invite in invites.where((invite) => invite.groupId == groupId)) {
      await actor.api.acceptInvitation(invite.id);
    }
  } catch (_) {}
  if (await actorHasGroup(actor, groupId)) return;

  fail(
    '${actor.name} (${actor.phone}) could not join group $groupId. '
    'Keep the group public or allow the primary actor to invite by phone.',
  );
}

Future<bool> actorHasGroup(QaActor actor, String groupId) async {
  final groups = await actor.api.fetchGroups();
  return groups.any((group) => group.id == groupId && group.myRole != null);
}

Future<void> waitForActorInGroup(
  QaActor actor,
  String groupId, {
  int seconds = 25,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if (await actorHasGroup(actor, groupId)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('${actor.name} must be a member of group $groupId.');
}

Future<void> waitForActorLeftGroup(
  QaActor actor,
  String groupId, {
  int seconds = 25,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if (!await actorHasGroup(actor, groupId)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('${actor.name} must leave group $groupId.');
}

Future<GroupInvitation> waitForInvitation({
  required QaActor actor,
  required String groupId,
  int seconds = 20,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    final invites = await actor.api.fetchInvitations();
    for (final invite in invites) {
      if (invite.groupId == groupId) return invite;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  fail('${actor.name} must receive invitation to group $groupId.');
}

Future<void> waitForChatMessage({
  required QaActor actor,
  required String groupId,
  required String messageText,
  int seconds = 25,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    final messages = await actor.api.fetchMessages(groupId, limit: 50);
    if (messages.any((message) => message.text == messageText)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('Chat message must be visible through the API.');
}

Future<PublicRequest> waitForRequestByTitle(
  String title, {
  bool Function(PublicRequest request)? matcher,
  String reason = 'Request must be visible through the API.',
  int seconds = 25,
}) async {
  final api = publicRequestsApi();
  final groupsApi =
      ApiClient(baseUrl: apiBaseUrl, sessionStore: const SessionStore());
  final deadline = DateTime.now().add(Duration(seconds: seconds));

  while (DateTime.now().isBefore(deadline)) {
    final groups = await groupsApi.fetchGroups();
    for (final group in groups) {
      if (group.myRole == null) continue;
      final requests = await api.listRequests(group.id);
      for (final request in requests) {
        if (request.title == title && (matcher?.call(request) ?? true)) {
          return request;
        }
      }
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  fail(reason);
}

Future<void> waitForCommentByBody(
  String requestId,
  String body, {
  QaActor? actor,
  int seconds = 25,
}) async {
  final api = actor?.requestsApi ?? publicRequestsApi();
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    final comments = await api.listComments(requestId);
    if (comments.any((comment) => comment.body == body)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  fail('Comment must be visible through the API immediately.');
}

Future<void> waitForCommentDeleted({
  required QaActor actor,
  required String requestId,
  required String commentId,
  int seconds = 25,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    final comments = await actor.requestsApi.listComments(requestId);
    if (comments.every((comment) => comment.id != commentId)) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  fail('Deleted comment $commentId must disappear from the API.');
}

Future<void> waitForGroupMemberRole({
  required QaActor actor,
  required String groupId,
  required String phone,
  required String role,
  int seconds = 25,
}) async {
  final normalizedPhone = normalizePhone(phone);
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    final members = await actor.requestsApi.listGroupMembers(groupId);
    if (members.any(
      (member) =>
          normalizePhone(member.phone ?? '') == normalizedPhone &&
          member.role == role,
    )) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  fail('Member $phone must have role $role in group $groupId.');
}

Future<void> waitForStatistics({
  required QaActor actor,
  required String groupId,
  required int minRequests,
  required int minComments,
  required int minSupportVotes,
  required int minOpposeVotes,
  int seconds = 30,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    final statistics = await actor.requestsApi.fetchStatistics(groupId);
    if (statistics.totalRequests >= minRequests &&
        statistics.totalComments >= minComments &&
        statistics.supportVotes >= minSupportVotes &&
        statistics.opposeVotes >= minOpposeVotes) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  fail('Group statistics must include QA requests, comments, and votes.');
}

String normalizePhone(String value) {
  return value.replaceAll(RegExp(r'[\s\-()]'), '');
}

PublicRequestsApi publicRequestsApi() {
  return PublicRequestsApi(
    baseUrl: apiBaseUrl,
    sessionStore: const SessionStore(),
  );
}

Future<void> openPostDetails(WidgetTester tester, String requestId) async {
  await scrollUntilKeyVisible(tester, 'public_request_read_$requestId');
  final readButton = find.byKey(ValueKey('public_request_read_$requestId'));
  await tester.ensureVisible(readButton.first);
  await tester.tap(readButton.first, warnIfMissed: false);
  await settle(tester, seconds: 4);

  if (find.byKey(const ValueKey('comment_field')).evaluate().isEmpty) {
    final readButtons = find.byType(FilledButton);
    if (readButtons.evaluate().isNotEmpty) {
      await tester.tap(readButtons.first, warnIfMissed: false);
      await settle(tester, seconds: 4);
    }
  }
}

Future<void> waitForCommentSubmission(
  WidgetTester tester,
  String commentBody, {
  int seconds = 20,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.text(commentBody).evaluate().isNotEmpty) return;

    final field = find.byKey(const ValueKey('comment_field'));
    if (field.evaluate().isNotEmpty) {
      final textField = tester.widget<TextField>(field.first);
      if ((textField.controller?.text ?? '').isEmpty) return;
    }
  }

  await waitForText(tester, commentBody, seconds: 1);
}

Future<void> waitForKey(WidgetTester tester, String key,
    {int seconds = 10}) async {
  await waitFor(tester, find.byKey(ValueKey(key)), seconds: seconds);
}

Future<void> waitForText(
  WidgetTester tester,
  String text, {
  int seconds = 10,
}) async {
  await waitFor(tester, find.text(text), seconds: seconds);
}

Future<void> waitForVisibleText(
  WidgetTester tester,
  String text, {
  int seconds = 10,
}) async {
  final finder = find.text(text);
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;

    final scrollable = find.byKey(
      const ValueKey('request_details_comments_list'),
    );
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(
        scrollable.first,
        const Offset(0, -260),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  expect(finder, findsAtLeastNWidgets(1));
}

Future<void> refreshPublicRequests(WidgetTester tester) async {
  await resetFirstScrollableToTop(tester);
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) {
    await settle(tester, seconds: 2);
    return;
  }
  await tester.drag(scrollables.first, const Offset(0, 520),
      warnIfMissed: false);
  await settle(tester, seconds: 4);
}

Future<void> refreshRequestDetailsComments(WidgetTester tester) async {
  final list = find.byKey(const ValueKey('request_details_comments_list'));
  await waitFor(tester, list, seconds: 10);
  await tester.drag(list.first, const Offset(0, 620), warnIfMissed: false);
  await settle(tester, seconds: 3);
}

Future<void> waitFor(WidgetTester tester, Finder finder,
    {int seconds = 10}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsAtLeastNWidgets(1));
}

Future<void> settle(WidgetTester tester, {int seconds = 2}) async {
  await tester.pump(Duration(seconds: seconds));
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 250));
  } catch (_) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await waitFor(tester, finder, seconds: 10);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester, seconds: 1);
}

Future<void> tapPublicRequestAction(WidgetTester tester, String key) async {
  await scrollUntilKeyVisible(tester, key, seconds: 20);
  await tapByKey(tester, key);
}

Future<void> scrollUntilKeyVisible(
  WidgetTester tester,
  String key, {
  int seconds = 20,
}) async {
  final finder = find.byKey(ValueKey(key));
  await resetFirstScrollableToTop(tester);
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (finder.evaluate().isNotEmpty) return;

    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(
        scrollables.first,
        const Offset(0, -420),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 450));
    }
  }

  expect(finder, findsAtLeastNWidgets(1));
}

Future<void> resetFirstScrollableToTop(WidgetTester tester) async {
  for (var index = 0; index < 6; index += 1) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    try {
      await tester.drag(
        scrollables.first,
        const Offset(0, 650),
        warnIfMissed: false,
      );
    } on StateError {
      return;
    }
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> openGroupMenuAction(WidgetTester tester, String action) async {
  await tapByKey(tester, 'group_menu_button');
  await tapByKey(tester, 'group_menu_item_$action');
}

Future<bool> tapFirstKeyPrefix(
  WidgetTester tester,
  String prefix, {
  int seconds = 10,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  Finder finder() => find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith(prefix),
      );

  while (DateTime.now().isBefore(deadline)) {
    final current = finder();
    if (current.evaluate().isNotEmpty) {
      await tester.ensureVisible(current.first);
      await tester.tap(current.first, warnIfMissed: false);
      await settle(tester, seconds: 2);
      return true;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  fail('No tappable widget found for key prefix $prefix');
}

Future<void> enterTextByKey(
    WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await waitFor(tester, finder, seconds: 10);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.enterText(finder.first, value);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> enterEditableTextAt(
    WidgetTester tester, int index, String value) async {
  final fields = find.byType(EditableText);
  expect(fields.evaluate().length, greaterThan(index));
  final finder = fields.at(index);
  await tester.tap(finder, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.enterText(finder, value);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> tapLastFilledButton(WidgetTester tester) async {
  final buttons = find.byType(FilledButton);
  expect(buttons, findsAtLeastNWidgets(1));
  await tester.tap(buttons.last, warnIfMissed: false);
  await settle(tester, seconds: 2);
}

Future<void> safeBack(WidgetTester tester) async {
  try {
    await tester.pageBack();
    await settle(tester, seconds: 2);
  } catch (_) {
    await tester.pump(const Duration(seconds: 1));
  }
}

class QaCrew {
  const QaCrew({
    required this.primary,
    required this.supporter,
    required this.opponent,
    required this.observer,
    required this.reviewer,
  });

  final QaActor primary;
  final QaActor supporter;
  final QaActor opponent;
  final QaActor observer;
  final QaActor reviewer;
}

class QaActor {
  QaActor({
    required this.name,
    required this.phone,
    required this.displayName,
  }) : sessionStore = MemorySessionStore() {
    api = ApiClient(baseUrl: apiBaseUrl, sessionStore: sessionStore);
    requestsApi = PublicRequestsApi(
      baseUrl: apiBaseUrl,
      sessionStore: sessionStore,
    );
  }

  final String name;
  final String phone;
  final String displayName;
  final MemorySessionStore sessionStore;
  late final ApiClient api;
  late final PublicRequestsApi requestsApi;
  AppSession? _session;

  AppSession get session {
    final value = _session;
    if (value == null) throw StateError('$name is not signed in.');
    return value;
  }

  Future<void> signIn() async {
    try {
      await api.requestPhoneCode(phone);
      _session = await api.verifyPhoneCode(
        mobile: phone,
        code: testCode,
        displayName: displayName,
      );
    } on ApiException catch (error) {
      fail(
        '$name ($phone) could not sign in with TEST_AUTH_CODE=$testCode: '
        '$error. Configure the backend test auth/demo whitelist for all five '
        'Firebase QA phones before running Test Lab.',
      );
    }
  }
}

class MemorySessionStore extends SessionStore {
  MemorySessionStore();

  AppSession? _session;

  @override
  Future<AppSession?> read() async => _session;

  @override
  Future<void> save(AppSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}
