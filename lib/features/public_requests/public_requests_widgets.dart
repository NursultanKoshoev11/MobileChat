import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/blocked_users.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../services/group_realtime_service.dart';
import '../../shared/koom_ui.dart';
import '../../shared/phone_input.dart';
import '../../shared/ui_helpers.dart';
import '../safety/safety_ui.dart';
import 'public_request_media_screens.dart';
import 'public_request_media_widgets.dart';

class EmptyPostsView extends StatelessWidget {
  const EmptyPostsView({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomCard(
      showShadow: false,
      child: KoomEmptyState(
        icon: Icons.feed_outlined,
        title: text.noPostsYet,
        message: text.postsDescription,
        action: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: Text(text.newPost),
        ),
      ),
    );
  }
}

class GroupAccessSheet extends StatefulWidget {
  const GroupAccessSheet({
    super.key,
    required this.groupTitle,
    required this.code,
    String? qrValue,
    this.onRotate,
  }) : qrValue = qrValue ?? code;
  final String groupTitle;
  final String code;
  final String qrValue;

  /// Owner/admin only: issues a new code and returns the new (code, QR).
  final Future<(String, String)> Function()? onRotate;

  @override
  State<GroupAccessSheet> createState() => _GroupAccessSheetState();
}

class _GroupAccessSheetState extends State<GroupAccessSheet> {
  late String code = widget.code;
  late String qrValue = widget.qrValue;
  bool rotating = false;

  Future<void> rotate() async {
    final onRotate = widget.onRotate;
    if (onRotate == null || rotating) return;
    final text = AppLanguageScope.textOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.rotateInviteCodeConfirmTitle),
        content: Text(text.rotateInviteCodeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm_rotate_invite_code'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.rotateInviteCode),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => rotating = true);
    try {
      final (newCode, newQr) = await onRotate();
      if (!mounted) return;
      setState(() {
        if (newCode.isNotEmpty) {
          code = newCode;
          qrValue = newQr.isEmpty ? newCode : newQr;
        }
      });
      showAppSnack(context, text.inviteCodeRotated);
    } catch (error) {
      if (mounted) {
        showAppSnack(context, localizedMessage(context, error.toString()));
      }
    } finally {
      if (mounted) setState(() => rotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final groupTitle = widget.groupTitle;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(KoomSpacing.md),
        padding: const EdgeInsets.fromLTRB(
          KoomSpacing.lg,
          KoomSpacing.lg,
          KoomSpacing.lg,
          KoomSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: KoomRadii.lgAll,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    groupTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: KoomSpacing.md),
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textStrong,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: KoomSpacing.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(KoomSpacing.lg),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: KoomRadii.mdAll,
                ),
                child: QrImageView(
                  data: qrValue,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: KoomSpacing.md),
            Text(
              text.isKy
                  ? 'Бул кодду же QR кодду башка колдонуучуга бериңиз.'
                  : 'Передайте этот код или QR другому пользователю.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.onRotate != null) ...[
              const SizedBox(height: KoomSpacing.md),
              OutlinedButton.icon(
                key: const ValueKey('rotate_invite_code_button'),
                onPressed: rotating ? null : rotate,
                icon: rotating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.autorenew_rounded),
                label: Text(text.rotateInviteCode),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InviteByPhoneSheet extends StatefulWidget {
  const InviteByPhoneSheet({super.key, required this.api, required this.group});
  final ApiClient api;
  final ChatGroup group;

  @override
  State<InviteByPhoneSheet> createState() => _InviteByPhoneSheetState();
}

class _InviteByPhoneSheetState extends State<InviteByPhoneSheet> {
  final phoneController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.inviteUserByPhone(
        groupId: widget.group.id,
        mobile: '+996${normalizeKgMobileInput(phoneController.text)}',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(
        context,
        AppLanguageScope.textOf(context).isKy
            ? 'Чакыруу жөнөтүлдү.'
            : 'Приглашение отправлено.',
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text.isKy ? 'Телефон менен чакыруу' : 'Пригласить по телефону',
            style: Theme.of(
              context,
            ).textTheme.titleLarge,
          ),
          const SizedBox(height: KoomSpacing.lg),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: kgMobileDigits,
            inputFormatters: const [KgMobileInputFormatter()],
            decoration: InputDecoration(
              labelText: text.mobileNumber,
              hintText: '700123456',
              prefixText: '+996 ',
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
              counterText: '',
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: KoomSpacing.md),
            ErrorBanner(message: error!),
          ],
          const SizedBox(height: KoomSpacing.lg),
          FilledButton(
            onPressed: loading ? null : submit,
            child: Text(
              loading
                  ? text.pleaseWait
                  : (text.isKy ? 'Чакыруу жөнөтүү' : 'Отправить приглашение'),
            ),
          ),
        ],
      ),
    );
  }
}

class PublicRequestDetailsScreen extends StatefulWidget {
  const PublicRequestDetailsScreen({
    super.key,
    required this.api,
    required this.request,
    required this.canModerate,
    required this.currentUserId,
    this.onStatusChanged,
    this.onRequestChanged,
  });
  final PublicRequestsApi api;
  final PublicRequest request;
  final bool canModerate;
  final String currentUserId;
  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<PublicRequest>? onRequestChanged;

  @override
  State<PublicRequestDetailsScreen> createState() =>
      _PublicRequestDetailsScreenState();
}

class _PublicRequestDetailsScreenState
    extends State<PublicRequestDetailsScreen> {
  final commentController = TextEditingController();
  final commentsScrollController = ScrollController();
  late PublicRequest request;
  late Future<List<PublicRequestComment>> commentsFuture;
  late final GroupRealtimeService realtime;
  List<PublicRequestComment> cachedComments = const <PublicRequestComment>[];
  bool sending = false;
  bool commentsLoaded = false;
  bool voteInFlight = false;
  String? error;

  @override
  void initState() {
    super.initState();
    commentController.addListener(_handleCommentTextChanged);
    request = widget.request;
    commentsFuture = loadComments();
    realtime = GroupRealtimeService(
      api: ApiClient(
        baseUrl: widget.api.baseUrl,
        sessionStore: widget.api.sessionStore,
      ),
      groupId: request.groupId,
    );
    unawaited(realtime.connect(onEvent: handleRealtimeEvent));
    BlockedUsersController.instance.addListener(_handleBlockedUsersChanged);
  }

  void _handleBlockedUsersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    BlockedUsersController.instance.removeListener(_handleBlockedUsersChanged);
    realtime.close();
    commentController.removeListener(_handleCommentTextChanged);
    commentController.dispose();
    commentsScrollController.dispose();
    super.dispose();
  }

  void _handleCommentTextChanged() {
    if (mounted) setState(() {});
  }

  bool get canSubmitComment =>
      !sending && commentController.text.trim().isNotEmpty;

  Future<List<PublicRequestComment>> loadComments() async {
    final comments = await widget.api.listComments(request.id);
    cachedComments = comments;
    commentsLoaded = true;
    return comments;
  }

  Future<void> refreshComments({bool silent = false}) async {
    final next = loadComments();
    if (silent) {
      final comments = await next;
      if (mounted) {
        setState(() {
          commentsFuture = Future.value(comments);
        });
      }
      return;
    }
    setState(() {
      commentsFuture = next;
    });
    await next;
  }

  void handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != request.groupId) return;
    if (event.type == 'connection.ready') return;
    if (event.requestId != request.id) return;
    switch (event.type) {
      case 'public_request.comment_created':
        final payload = event.payload;
        if (payload is Map<String, dynamic>) {
          final commentPayload = payload['comment'];
          if (commentPayload is Map<String, dynamic>) {
            final comment = PublicRequestComment.fromJson(commentPayload);
            // Realtime events are not filtered server-side.
            if (BlockedUsersController.instance.isBlocked(comment.authorId)) {
              break;
            }
            addRealtimeComment(comment);
          }
        }
        break;
      case 'public_request.comment_deleted':
        final payload = event.payload;
        if (payload is Map<String, dynamic>) {
          removeRealtimeComment(payload['comment_id'] as String? ?? '');
        }
        break;
      case 'public_request.voted':
      case 'public_request.vote_cleared':
        final payload = event.payload;
        if (payload is Map<String, dynamic>) {
          applyVoteUpdate(PublicRequestVoteUpdate.fromJson(payload));
        }
        break;
    }
  }

  void addRealtimeComment(
    PublicRequestComment comment, {
    bool updateRequestCount = true,
  }) {
    if (cachedComments.any((item) => item.id == comment.id)) return;
    final updated = [...cachedComments, comment]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setComments(updated);
    if (updateRequestCount) {
      setRequest(
        request.copyWith(
          commentCount: request.commentCount + 1,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  void removeRealtimeComment(
    String commentId, {
    bool updateRequestCount = true,
  }) {
    if (commentId.isEmpty ||
        !cachedComments.any((comment) => comment.id == commentId)) {
      return;
    }
    final updated =
        cachedComments.where((comment) => comment.id != commentId).toList();
    setComments(updated);
    if (updateRequestCount) {
      setRequest(
        request.copyWith(
          commentCount: request.commentCount > 0 ? request.commentCount - 1 : 0,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  void setComments(List<PublicRequestComment> comments) {
    if (!mounted) return;
    cachedComments = comments;
    commentsLoaded = true;
    setState(() {});
  }

  Future<void> scrollToLatestComment() async {
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !commentsScrollController.hasClients) return;
    await commentsScrollController.animateTo(
      commentsScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void setRequest(PublicRequest next) {
    if (!mounted) return;
    setState(() => request = next);
    widget.onRequestChanged?.call(next);
  }

  void applyVoteUpdate(PublicRequestVoteUpdate update) {
    if (update.requestId != request.id || !update.hasCounts) return;
    var next = request.copyWith(
      supportCount: update.supportCount!,
      opposeCount: update.opposeCount!,
      updatedAt: DateTime.now(),
    );
    if (update.voterId == widget.currentUserId) {
      next = next.copyWith(myVote: update.voteType);
    }
    setRequest(next);
  }

  Future<void> vote(String voteType) async {
    if (request.interactionMode == 'read_only' || voteInFlight) return;
    voteInFlight = true;
    final previous = request;
    setRequest(optimisticPublicRequestVote(request, voteType));
    try {
      final PublicRequestVoteUpdate update;
      if (previous.myVote == voteType) {
        update = await widget.api.clearVote(previous.id);
      } else if (voteType == 'support') {
        update = await widget.api.support(previous.id);
      } else {
        update = await widget.api.oppose(previous.id);
      }
      if (mounted) applyVoteUpdate(update);
    } catch (e) {
      setRequest(previous);
      if (mounted) {
        showAppSnack(context, localizedMessage(context, e.toString()));
      }
    } finally {
      voteInFlight = false;
    }
  }

  Future<void> submitComment() async {
    final body = commentController.text.trim();
    if (body.isEmpty || sending || request.interactionMode != 'discussion') {
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final comment = await widget.api.addComment(
        requestId: request.id,
        body: body,
      );
      commentController.clear();
      addRealtimeComment(comment, updateRequestCount: false);
      setRequest(
        request.copyWith(
          commentCount: request.commentCount + 1,
          updatedAt: DateTime.now(),
        ),
      );
      await scrollToLatestComment();
    } on ModerationPendingException catch (e) {
      commentController.clear();
      if (mounted) {
        setState(() => error = null);
        showAppSnack(context, e.message);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> deleteComment(PublicRequestComment comment) async {
    if (!widget.canModerate && comment.authorId != widget.currentUserId) return;
    final previousComments = cachedComments;
    final previousRequest = request;
    removeRealtimeComment(comment.id, updateRequestCount: false);
    setRequest(
      request.copyWith(
        commentCount:
            request.commentCount - 1 < 0 ? 0 : request.commentCount - 1,
        updatedAt: DateTime.now(),
      ),
    );
    try {
      await widget.api.deleteComment(comment.id);
    } catch (e) {
      setComments(previousComments);
      setRequest(previousRequest);
      if (mounted) {
        showAppSnack(context, localizedMessage(context, e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(text.readPost),
        actions: const [AppSettingsButton()],
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refreshComments,
          child: FutureBuilder<List<PublicRequestComment>>(
            future: commentsFuture,
            builder: (context, snapshot) {
              final comments = BlockedUsersController.instance.visible(
                commentsLoaded
                    ? cachedComments
                    : snapshot.data ?? const <PublicRequestComment>[],
                (comment) => comment.authorId,
              );
              return ListView(
                key: const ValueKey('request_details_comments_list'),
                controller: commentsScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  KoomSpacing.lg,
                  KoomSpacing.md,
                  KoomSpacing.lg,
                  KoomSpacing.xl,
                ),
                children: [
                  if (BlockedUsersController.instance
                      .isBlocked(request.authorId))
                    const BlockedContentNotice()
                  else
                    MediaPublicRequestCard(
                      request: request,
                      safetyMenu: ContentSafetyMenuButton(
                        api: widget.api,
                        target: SafetyTarget(
                          targetType: ReportTargetType.publicRequest,
                          targetId: request.id,
                          authorId: request.authorId,
                          authorName: request.authorName,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                      onTap: () {},
                      onVote: vote,
                      canModerate: widget.canModerate,
                      onStatus: widget.onStatusChanged == null
                          ? null
                          : (status) {
                              setRequest(
                                request.copyWith(
                                  status: status,
                                  updatedAt: DateTime.now(),
                                ),
                              );
                              widget.onStatusChanged!(status);
                            },
                      compact: false,
                      showOpenAction: false,
                    ),
                  const SizedBox(height: KoomSpacing.xl),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.10),
                          borderRadius: KoomRadii.smAll,
                        ),
                        child: Icon(
                          Icons.forum_outlined,
                          size: 19,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: KoomSpacing.md),
                      Expanded(
                        child: Text(
                          text.comments,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KoomSpacing.md,
                          vertical: KoomSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.page,
                          borderRadius: KoomRadii.pillAll,
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          '${comments.length}',
                          key: const ValueKey('request_comments_count'),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KoomSpacing.md),
                  if (error != null) ...[
                    ErrorBanner(message: error!),
                    const SizedBox(height: KoomSpacing.md),
                  ],
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !commentsLoaded)
                    const CommentListSkeleton()
                  else if (snapshot.hasError)
                    ErrorBanner(message: snapshot.error.toString())
                  else if (comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KoomSpacing.xl,
                        vertical: KoomSpacing.xxl,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: KoomRadii.lgAll,
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 30,
                            color: colors.textMuted,
                          ),
                          const SizedBox(height: KoomSpacing.md),
                          Text(
                            text.noCommentsYet,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: KoomSpacing.xs),
                          Text(
                            text.beFirstToComment,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else
                    ...comments.map(
                      (comment) => _CommentTile(
                        comment: comment,
                        canDelete: widget.canModerate ||
                            comment.authorId == widget.currentUserId,
                        onDelete: () => deleteComment(comment),
                        safetyTarget: SafetyTarget(
                          targetType: ReportTargetType.comment,
                          targetId: comment.id,
                          authorId: comment.authorId,
                          authorName: comment.authorName,
                          currentUserId: widget.currentUserId,
                        ),
                        onSafetyAction: (action, target) =>
                            handleSafetyMenuAction(
                          context,
                          action,
                          api: widget.api,
                          target: target,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: request.interactionMode == 'discussion'
          ? AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Material(
                  color: colors.surface,
                  elevation: KoomElevation.high,
                  shadowColor: colors.shadow,
                  child: Padding(
                    padding: const EdgeInsets.all(KoomSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('comment_field'),
                            controller: commentController,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              if (canSubmitComment) submitComment();
                            },
                            // Borders, fill and radius all come from the theme's
                            // InputDecorationTheme (KoomRadii.sm) so the
                            // composer matches every other field in the app.
                            decoration: InputDecoration(
                              hintText: text.addComment,
                              prefixIcon:
                                  const Icon(Icons.chat_bubble_outline_rounded),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: KoomSpacing.lg,
                                vertical: KoomSpacing.md,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: KoomSpacing.sm),
                        SizedBox(
                          width: kKoomMinTapTarget,
                          height: kKoomMinTapTarget,
                          child: IconButton.filled(
                            tooltip: text.sendComment,
                            onPressed: canSubmitComment ? submitComment : null,
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
    required this.safetyTarget,
    required this.onSafetyAction,
  });
  final PublicRequestComment comment;
  final bool canDelete;
  final VoidCallback onDelete;
  final SafetyTarget safetyTarget;
  final void Function(String action, SafetyTarget target) onSafetyAction;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final authorName = comment.authorId.isEmpty
        ? text.deletedAccount
        : comment.authorName.trim().isEmpty
            ? text.unnamedUser
            : comment.authorName.trim();
    final hasMenu = canDelete || safetyTarget.canReport;

    return Padding(
      padding: const EdgeInsets.only(bottom: KoomSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KoomAvatar(
            label: authorName,
            radius: 18,
            imageBytes: comment.authorAvatarBytes,
          ),
          const SizedBox(width: KoomSpacing.md),
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                KoomSpacing.md,
                KoomSpacing.md,
                hasMenu ? KoomSpacing.xs : KoomSpacing.md,
                KoomSpacing.md,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                // Square-ish corner towards the avatar, so the bubble reads as
                // belonging to it.
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(KoomSpacing.xs),
                  topRight: Radius.circular(KoomRadii.md),
                  bottomLeft: Radius.circular(KoomRadii.md),
                  bottomRight: Radius.circular(KoomRadii.md),
                ),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: KoomSpacing.sm),
                      Text(
                        koomRelativeTime(text, comment.createdAt.toLocal()),
                        style: textTheme.bodySmall,
                      ),
                      if (hasMenu)
                        SizedBox(
                          width: kKoomMinTapTarget,
                          height: kKoomMinTapTarget,
                          child: PopupMenuButton<String>(
                            key: ValueKey('comment_menu_${comment.id}'),
                            tooltip: text.moreActions,
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: colors.textMuted,
                            ),
                            onSelected: (value) {
                              if (value == 'delete') {
                                onDelete();
                              } else if (SafetyMenuAction.isSafetyAction(
                                value,
                              )) {
                                onSafetyAction(value, safetyTarget);
                              }
                            },
                            itemBuilder: (_) => [
                              if (canDelete)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline_rounded),
                                      const SizedBox(width: KoomSpacing.md),
                                      Text(text.deleteItem),
                                    ],
                                  ),
                                ),
                              ...safetyMenuEntries(text, safetyTarget),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: KoomSpacing.xs),
                  Text(comment.body, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder rows for the comment list, shown while the first page loads.
///
/// Mirrors [_CommentTile]: a round avatar next to a name line and two lines of
/// body text, so the list does not jump when the real comments arrive.
class CommentListSkeleton extends StatelessWidget {
  const CommentListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < itemCount; index++)
          const Padding(
            padding: EdgeInsets.only(bottom: KoomSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KoomSkeleton.circle(size: 36),
                SizedBox(width: KoomSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KoomSkeleton(width: 120, height: 12),
                      SizedBox(height: KoomSpacing.sm),
                      KoomSkeleton(height: 12),
                      SizedBox(height: KoomSpacing.sm),
                      KoomSkeleton(width: 190, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
