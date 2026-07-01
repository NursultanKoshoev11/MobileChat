import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_chat/app/localization.dart';
import 'package:mobile_chat/app/theme.dart';

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
        text.localTestCode,
        text.displayNameNewOnly,
        text.continueText,
        text.pleaseWait,
        text.verifyAndContinue,
        text.changeMobileNumber,
        text.codeRequired,
        text.displayNameRequiredForNewAccount,
        text.existingAccountHint,
        text.newAccountHint,
        text.devSmsAnyCode,
        text.devSmsCode('654321'),
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

  test('AppText exposes non-empty labels for both languages', () {
    for (final language in AppLanguage.values) {
      final values = allTextValues(AppText(language));
      expect(values, everyElement(isNotEmpty));
      expect(values, contains(contains('654321')));
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
          theme: MobileChatTheme.light,
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
