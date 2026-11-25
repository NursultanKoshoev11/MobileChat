import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koom/app/localization.dart';
import 'package:koom/app/theme.dart';

void main() {
  List<String> allTextValues(AppText text) => [
        text.appTitle,
        text.languageLabel,
        text.groups,
        text.adminRequests,
        text.myRequests,
        text.groupRequests,
        text.requestGroup,
        text.invitations,
        text.joinByCode,
        text.scanQr,
        text.profile,
        text.createGroup,
        text.newGroup,
        text.logout,
        text.noGroupsYet,
        text.noGroups,
        text.createGroupOrApprove,
        text.sendGroupRequestOrJoin,
        text.publicGroup,
        text.privateGroup,
        text.copyInviteCode,
        text.inviteCodeCopied,
        text.enterMobileNumber,
        text.mobileNumber,
        text.code,
        text.displayNameNewOnly,
        text.continueText,
        text.pleaseWait,
        text.verifyAndContinue,
        text.changeMobileNumber,
        text.codeRequired,
        text.resendCode,
        text.resendCodeIn(45),
        text.displayNameRequiredForNewAccount,
        text.existingAccountHint,
        text.newAccountHint,
        text.newest,
        text.popular,
        text.resolved,
        text.mine,
        text.newPost,
        text.noPostsYet,
        text.noPopularPosts,
        text.noResolvedPosts,
        text.noMyPosts,
        text.postsDescription,
        text.postPublished,
        text.postType,
        text.announcement,
        text.suggestion,
        text.complaint,
        text.requirement,
        text.problem,
        text.idea,
        text.interactionMode,
        text.textOnly,
        text.votingOnly,
        text.discussionWithComments,
        text.title,
        text.description,
        text.publish,
        text.publishing,
        text.read,
        text.readPost,
        text.comments,
        text.noCommentsYet,
        text.readOnlyPost,
        text.voteOnlyPost,
        text.addComment,
        text.adminStatus,
        text.statusNew,
        text.statusUnderReview,
        text.statusAccepted,
        text.statusRejected,
        text.statusResolved,
        text.manageAdmins,
        text.manageAdminsHint,
        text.manageAdminsDescription,
        text.makeAdmin,
        text.removeAdmin,
        text.adminAssigned,
        text.adminRemoved,
        text.statistics,
        text.codeAndQr,
        text.inviteByPhone,
        text.lightMode,
        text.darkMode,
        text.settings,
        text.close,
        text.blockComments,
        text.blockCommentsDescription,
        text.blockCommentsButton,
        text.unblockCommentsButton,
        text.blockDuration,
        text.blockReason,
        text.mutedDone,
        text.unmutedDone,
        text.oneHour,
        text.threeHours,
        text.sixHours,
        text.twelveHours,
        text.oneDay,
        text.sevenDays,
        text.thirtyDays,
        text.forever,
        text.avatarTooLarge,
        text.moderationQueueTitle,
        text.refresh,
        text.moderationQueueEmptyTitle,
        text.moderationQueueEmptyMessage,
        text.moderationApproved,
        text.moderationRejected,
        text.author,
        text.reason,
        text.moderationCheck,
        text.emptyBodyText,
        text.reject,
        text.approve,
        // Navigation rebuild.
        text.notifications,
        text.searchGroupsHint,
        text.clearSearch,
        text.groupsSearchEmptyTitle,
        text.groupsSearchEmptyMessage,
        text.allFilter,
        text.noNotificationsTitle,
        text.noNotificationsMessage,
        text.noInvitationsTitle,
        text.noInvitationsMessage,
        text.newPostsSectionTitle,
        text.newPostsInGroup('A'),
        text.newPostsCount(3),
        text.invitationsCountLabel(2),
        text.invitedBy,
        text.invitationNew,
        text.acceptInvitation,
        text.declineInvitation,
        text.invitationAccepted,
        text.invitationDeclined,
        text.groupFeed,
        text.groupModeration,
        text.reports,
        text.changeGroupPhoto,
        text.uploading,
      ];

  test('AppLanguage metadata and controller notify on real changes', () {
    final controller = AppLanguageController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    expect(AppLanguage.ru.shortName, 'RU');
    expect(AppLanguage.ky.shortName, 'KG');
    expect(AppLanguage.ru.displayName, isNotEmpty);
    expect(AppLanguage.ky.displayName, isNotEmpty);
    expect(controller.language, AppLanguage.ru);
    expect(controller.text.isKy, isFalse);

    controller.setLanguage(AppLanguage.ru);
    expect(notifications, 0);

    controller.setLanguage(AppLanguage.ky);
    expect(controller.language, AppLanguage.ky);
    expect(controller.text.isKy, isTrue);
    expect(notifications, 1);
  });

  test('AppText labels never leak broken placeholder characters', () {
    for (final language in AppLanguage.values) {
      final text = AppText(language);
      expect(text.avatarTooLarge, isNot(contains('?')));
      expect(text.avatarTooLarge.length, greaterThan(10));
      for (final value in allTextValues(text)) {
        expect(value, isNot(contains('?')),
            reason: 'Placeholder "?" found in: $value');
      }
    }
  });

  test('moderation labels are really translated, not duplicated', () {
    final ru = AppText(AppLanguage.ru);
    final ky = AppText(AppLanguage.ky);
    final pairs = <String, List<String>>{
      'avatarTooLarge': [ru.avatarTooLarge, ky.avatarTooLarge],
      'moderationQueueTitle': [
        ru.moderationQueueTitle,
        ky.moderationQueueTitle
      ],
      'refresh': [ru.refresh, ky.refresh],
      'moderationQueueEmptyTitle': [
        ru.moderationQueueEmptyTitle,
        ky.moderationQueueEmptyTitle
      ],
      'moderationQueueEmptyMessage': [
        ru.moderationQueueEmptyMessage,
        ky.moderationQueueEmptyMessage
      ],
      'moderationApproved': [ru.moderationApproved, ky.moderationApproved],
      'moderationRejected': [ru.moderationRejected, ky.moderationRejected],
      'reason': [ru.reason, ky.reason],
      'moderationCheck': [ru.moderationCheck, ky.moderationCheck],
      'emptyBodyText': [ru.emptyBodyText, ky.emptyBodyText],
      'reject': [ru.reject, ky.reject],
      'approve': [ru.approve, ky.approve],
      'notifications': [ru.notifications, ky.notifications],
      'searchGroupsHint': [ru.searchGroupsHint, ky.searchGroupsHint],
      'clearSearch': [ru.clearSearch, ky.clearSearch],
      'groupsSearchEmptyTitle': [
        ru.groupsSearchEmptyTitle,
        ky.groupsSearchEmptyTitle
      ],
      'groupsSearchEmptyMessage': [
        ru.groupsSearchEmptyMessage,
        ky.groupsSearchEmptyMessage
      ],
      'allFilter': [ru.allFilter, ky.allFilter],
      'resendCode': [ru.resendCode, ky.resendCode],
      'resendCodeIn': [ru.resendCodeIn(45), ky.resendCodeIn(45)],
      'noNotificationsTitle': [
        ru.noNotificationsTitle,
        ky.noNotificationsTitle
      ],
      'noNotificationsMessage': [
        ru.noNotificationsMessage,
        ky.noNotificationsMessage
      ],
      'noInvitationsTitle': [ru.noInvitationsTitle, ky.noInvitationsTitle],
      'noInvitationsMessage': [
        ru.noInvitationsMessage,
        ky.noInvitationsMessage
      ],
      'newPostsSectionTitle': [
        ru.newPostsSectionTitle,
        ky.newPostsSectionTitle
      ],
      'newPostsInGroup': [ru.newPostsInGroup('A'), ky.newPostsInGroup('A')],
      'newPostsCount': [ru.newPostsCount(3), ky.newPostsCount(3)],
      'invitationsCountLabel': [
        ru.invitationsCountLabel(2),
        ky.invitationsCountLabel(2)
      ],
      'invitedBy': [ru.invitedBy, ky.invitedBy],
      'invitationNew': [ru.invitationNew, ky.invitationNew],
      'acceptInvitation': [ru.acceptInvitation, ky.acceptInvitation],
      'declineInvitation': [ru.declineInvitation, ky.declineInvitation],
      'invitationAccepted': [ru.invitationAccepted, ky.invitationAccepted],
      'invitationDeclined': [ru.invitationDeclined, ky.invitationDeclined],
      'groupFeed': [ru.groupFeed, ky.groupFeed],
      'groupModeration': [ru.groupModeration, ky.groupModeration],
      'reports': [ru.reports, ky.reports],
      'changeGroupPhoto': [ru.changeGroupPhoto, ky.changeGroupPhoto],
      'uploading': [ru.uploading, ky.uploading],
    };
    pairs.forEach((name, values) {
      expect(values.first, isNot(values.last),
          reason: '$name is identical in Russian and Kyrgyz');
    });
  });

  test('AppText exposes non-empty labels for both languages', () {
    for (final language in AppLanguage.values) {
      final values = allTextValues(AppText(language));
      expect(values, everyElement(isNotEmpty));
    }
    expect(LanguageMenuButton().key, isNull);
  });

  testWidgets('LanguageMenuButton changes language through popup',
      (tester) async {
    final controller = AppLanguageController();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(
          theme: KoomTheme.light,
          home: const Scaffold(body: LanguageMenuButton()),
        ),
      ),
    );

    expect(find.text('RU'), findsOneWidget);
    await tester.tap(find.text('RU'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLanguage.ky.displayName));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.ky);
    expect(find.text('KG'), findsOneWidget);
  });

  testWidgets('AppLanguageScope exposes controller and text', (tester) async {
    final controller = AppLanguageController()..setLanguage(AppLanguage.ky);
    late AppLanguage scopedLanguage;
    late bool scopedTextIsKy;

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: Builder(
          builder: (context) {
            scopedLanguage = AppLanguageScope.controllerOf(context).language;
            scopedTextIsKy = AppLanguageScope.textOf(context).isKy;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(scopedLanguage, AppLanguage.ky);
    expect(scopedTextIsKy, isTrue);
  });
}
