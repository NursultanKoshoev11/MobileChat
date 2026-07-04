import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../services/group_realtime_service.dart';
import '../../shared/ui_helpers.dart';
import 'public_request_media_widgets.dart';

class EmptyPostsView extends StatelessWidget {
  const EmptyPostsView({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.feed_outlined, size: 72, color: MobileChatTheme.primary),
        const SizedBox(height: 16),
        Text(
          text.noPostsYet,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          text.postsDescription,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appColors.textMuted),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(text.newPost),
          ),
        ),
      ],
    );
  }
}

class GroupAccessSheet extends StatelessWidget {
  const GroupAccessSheet({
    super.key,
    required this.groupTitle,
    required this.code,
    String? qrValue,
  }) : qrValue = qrValue ?? code;

  final String groupTitle;
  final String code;
  final String qrValue;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
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
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: qrValue,
                  version: QrVersions.auto,
                  size: 210,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text.isKy
                  ? 'Бул кодду же QR кодду башка колдонуучуга бериңиз.'
                  : 'Передайте этот код или QR другому пользователю.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600),
            ),
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
  final phoneController = TextEditingController(text: '+996');
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
      await widget.api.inviteUserByPhone(groupId: widget.group.id, mobile: phoneController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(
        context,
        AppLanguageScope.textOf(context).isKy ? 'Чакыруу жөнөтүлдү.' : 'Приглашение отправлено.',
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('invite_phone_field'),
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: text.mobileNumber,
              hintText: '+996700123456',
              prefixIcon: const Icon(Icons.phone_iphone_rounded),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: error!),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('invite_phone_submit_button'),
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

class PublicRequestCard extends StatelessWidget {
  const PublicRequestCard({
    super.key,
    required this.request,
    required this.onTap,
    required this.onVote,
    this.canModerate = false,
    this.onStatus,
  });

  final PublicRequest request;
  final VoidCallback onTap;
  final ValueChanged<String> onVote;
  final bool canModerate;
  final ValueChanged<String>? onStatus;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final statusText = [
      _typeLabel(text, request.requestType),
      _modeLabel(text, request.interactionMode),
      _statusLabel(text, request.status),
      if (canModerate && onStatus != null) text.adminStatus,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: ValueKey('public_request_card_${request.id}'),
        elevation: 2,
        shadowColor: colors.shadow,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: request.interactionMode == 'discussion' ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        statusText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (canModerate && onStatus != null)
                      _StatusButton(requestId: request.id, onChanged: onStatus!),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  request.title,
                  style: TextStyle(color: colors.textStrong, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                if (request.displayBody.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(request.displayBody, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                if (request.content.hasMedia) ...[
                  const SizedBox(height: 10),
                  PublicRequestMediaView(content: request.content),
                ],
                const SizedBox(height: 10),
                Text(
                  '${text.isKy ? 'Автор' : 'Автор'}: ${request.authorName}',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (request.interactionMode == 'discussion')
                      FilledButton.tonal(
                        key: ValueKey('public_request_read_${request.id}'),
                        onPressed: onTap,
                        child: Text(text.read),
                      ),
                    if (request.interactionMode != 'read_only')
                      OutlinedButton.icon(
                        key: ValueKey('public_request_support_${request.id}'),
                        onPressed: () => onVote('support'),
                        icon: Icon(
                          request.supportedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        ),
                        label: Text('${request.supportCount}'),
                      ),
                    if (request.interactionMode != 'read_only')
                      OutlinedButton.icon(
                        key: ValueKey('public_request_oppose_${request.id}'),
                        onPressed: () => onVote('oppose'),
                        icon: Icon(
                          request.opposedByMe ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined,
                        ),
                        label: Text('${request.opposeCount}'),
                      ),
                    if (request.interactionMode == 'discussion')
                      Text('${request.commentCount} ${text.comments}', style: TextStyle(color: colors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.requestId, required this.onChanged});

  final String requestId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return PopupMenuButton<String>(
      key: ValueKey('public_request_status_$requestId'),
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem(
          key: const ValueKey('public_request_status_under_review'),
          value: 'under_review',
          child: Text(text.statusUnderReview),
        ),
        PopupMenuItem(
          key: const ValueKey('public_request_status_resolved'),
          value: 'resolved',
          child: Text(text.statusResolved),
        ),
        PopupMenuItem(
          key: const ValueKey('public_request_status_new'),
          value: 'new',
          child: Text(text.statusNew),
        ),
        PopupMenuItem(
          key: const ValueKey('public_request_status_rejected'),
          value: 'rejected',
          child: Text(text.statusRejected),
        ),
      ],
      tooltip: text.adminStatus,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(Icons.sync_alt_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class CreatePublicRequestSheet extends StatefulWidget {
  const CreatePublicRequestSheet({super.key, required this.api, required this.group});

  final PublicRequestsApi api;
  final ChatGroup group;

  @override
  State<CreatePublicRequestSheet> createState() => _CreatePublicRequestSheetState();
}

class _CreatePublicRequestSheetState extends State<CreatePublicRequestSheet> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  String type = 'announcement';
  String interactionMode = 'read_only';
  bool loading = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final title = titleController.text.trim();
    final body = bodyController.text.trim();
    if (title.isEmpty || body.isEmpty || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.createRequest(
        groupId: widget.group.id,
        type: type,
        interactionMode: interactionMode,
        title: title,
        body: body,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ModerationPendingException catch (e) {
      titleController.clear();
      bodyController.clear();
      if (mounted) {
        setState(() => error = null);
        showAppSnack(context, e.message);
        Navigator.of(context).pop(false);
      }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text.newPost,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: type,
              decoration: InputDecoration(labelText: text.postType),
              items: [
                DropdownMenuItem(value: 'announcement', child: Text(text.announcement)),
                DropdownMenuItem(value: 'suggestion', child: Text(text.suggestion)),
                DropdownMenuItem(value: 'complaint', child: Text(text.complaint)),
                DropdownMenuItem(value: 'requirement', child: Text(text.requirement)),
                DropdownMenuItem(value: 'problem', child: Text(text.problem)),
                DropdownMenuItem(value: 'idea', child: Text(text.idea)),
              ],
              onChanged: loading ? null : (value) => setState(() => type = value ?? 'announcement'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: interactionMode,
              decoration: InputDecoration(labelText: text.interactionMode),
              items: [
                DropdownMenuItem(value: 'read_only', child: Text(text.textOnly)),
                DropdownMenuItem(value: 'vote_only', child: Text(text.votingOnly)),
                DropdownMenuItem(value: 'discussion', child: Text(text.discussionWithComments)),
              ],
              onChanged: loading ? null : (value) => setState(() => interactionMode = value ?? 'read_only'),
            ),
            const SizedBox(height: 12),
            TextField(controller: titleController, decoration: InputDecoration(labelText: text.title)),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              minLines: 4,
              maxLines: 8,
              decoration: InputDecoration(labelText: text.description),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: loading ? null : submit,
              child: Text(loading ? text.publishing : text.publish),
            ),
          ],
        ),
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
  });

  final PublicRequestsApi api;
  final PublicRequest request;
  final bool canModerate;
  final String currentUserId;
  final ValueChanged<String>? onStatusChanged;

  @override
  State<PublicRequestDetailsScreen> createState() => _PublicRequestDetailsScreenState();
}

class _PublicRequestDetailsScreenState extends State<PublicRequestDetailsScreen> {
  final commentController = TextEditingController();
  late Future<List<PublicRequestComment>> commentsFuture;
  late final GroupRealtimeService realtime;
  List<PublicRequestComment> cachedComments = const <PublicRequestComment>[];
  Timer? realtimeRefreshDebounce;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    commentsFuture = loadComments();
    realtime = GroupRealtimeService(
      api: ApiClient(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore),
      groupId: widget.request.groupId,
    );
    unawaited(realtime.connect(onEvent: handleRealtimeEvent));
  }

  @override
  void dispose() {
    realtimeRefreshDebounce?.cancel();
    unawaited(realtime.close());
    commentController.dispose();
    super.dispose();
  }

  Future<List<PublicRequestComment>> fetchSortedComments() async {
    final comments = await widget.api.listComments(widget.request.id);
    return [...comments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<List<PublicRequestComment>> loadComments() async {
    final comments = await fetchSortedComments();
    cachedComments = comments;
    return comments;
  }

  Future<void> refreshComments({bool silent = false}) async {
    final next = fetchSortedComments();
    if (silent) {
      final comments = await next;
      if (mounted) setComments(comments);
      return;
    }
    setState(() => commentsFuture = next);
    final comments = await next;
    if (mounted) setComments(comments);
  }

  void handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != widget.request.groupId) return;
    if (event.type == 'connection.ready') {
      realtimeRefreshDebounce?.cancel();
      realtimeRefreshDebounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) unawaited(refreshComments(silent: true).catchError((_) {}));
      });
      return;
    }
    if (event.requestId != widget.request.id) return;
    switch (event.type) {
      case 'public_request.comment_created':
        final comment = _commentFromRealtimePayload(event.payload);
        if (comment == null) {
          unawaited(refreshComments(silent: true).catchError((_) {}));
        } else {
          addRealtimeComment(comment);
        }
        break;
      case 'public_request.comment_deleted':
        final commentId = _commentIdFromRealtimePayload(event.payload);
        if (commentId.isEmpty) {
          unawaited(refreshComments(silent: true).catchError((_) {}));
        } else {
          removeRealtimeComment(commentId);
        }
        break;
    }
  }

  PublicRequestComment? _commentFromRealtimePayload(dynamic payload) {
    if (payload is! Map<String, dynamic>) return null;
    final commentPayload = payload['comment'];
    if (commentPayload is Map<String, dynamic>) {
      return PublicRequestComment.fromJson(commentPayload);
    }
    return null;
  }

  String _commentIdFromRealtimePayload(dynamic payload) {
    if (payload is! Map<String, dynamic>) return '';
    return payload['comment_id'] as String? ?? '';
  }

  bool _sameComments(List<PublicRequestComment> a, List<PublicRequestComment> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].body != b[i].body ||
          a[i].authorName != b[i].authorName ||
          a[i].createdAt != b[i].createdAt) {
        return false;
      }
    }
    return true;
  }

  void addRealtimeComment(PublicRequestComment comment) {
    if (cachedComments.any((item) => item.id == comment.id)) return;
    final updated = [...cachedComments, comment]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setComments(updated);
  }

  void removeRealtimeComment(String commentId) {
    if (commentId.isEmpty) return;
    final updated = cachedComments.where((comment) => comment.id != commentId).toList();
    setComments(updated);
  }

  void setComments(List<PublicRequestComment> comments) {
    if (!mounted || _sameComments(cachedComments, comments)) return;
    cachedComments = comments;
    setState(() => commentsFuture = Future.value(comments));
  }

  Future<void> submitComment() async {
    final body = commentController.text.trim();
    if (body.isEmpty || sending || widget.request.interactionMode != 'discussion') return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final created = await widget.api.addComment(requestId: widget.request.id, body: body);
      commentController.clear();
      addRealtimeComment(created);
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
    try {
      await widget.api.deleteComment(comment.id);
      removeRealtimeComment(comment.id);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(title: Text(text.readPost), actions: const [AppSettingsButton()]),
      body: RefreshIndicator(
        onRefresh: refreshComments,
        child: FutureBuilder<List<PublicRequestComment>>(
          future: commentsFuture,
          initialData: cachedComments,
          builder: (context, snapshot) {
            final comments = snapshot.data ?? cachedComments;
            final isInitialLoading = snapshot.connectionState == ConnectionState.waiting && comments.isEmpty;
            return ListView(
              key: const ValueKey('request_details_comments_list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                PublicRequestCard(
                  request: widget.request,
                  onTap: () {},
                  onVote: (_) {},
                  canModerate: widget.canModerate,
                  onStatus: widget.onStatusChanged,
                ),
                const SizedBox(height: 12),
                if (widget.request.displayBody.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(widget.request.displayBody, style: TextStyle(color: colors.textStrong, height: 1.35)),
                  ),
                if (widget.request.content.hasMedia) ...[
                  const SizedBox(height: 12),
                  PublicRequestMediaView(content: widget.request.content, compact: false),
                ],
                const SizedBox(height: 18),
                Text(
                  text.comments,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (error != null) ...[
                  ErrorBanner(message: error!),
                  const SizedBox(height: 10),
                ],
                if (isInitialLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  ErrorBanner(message: snapshot.error.toString())
                else if (comments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      text.isKy ? 'Комментарий азырынча жок.' : 'Комментариев пока нет.',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  )
                else
                  ...comments.map(
                    (comment) => _CommentTile(
                      key: ValueKey('comment_${comment.id}'),
                      comment: comment,
                      canDelete: widget.canModerate || comment.authorId == widget.currentUserId,
                      onDelete: () => deleteComment(comment),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: widget.request.interactionMode == 'discussion'
          ? SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('comment_field'),
                        controller: commentController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => submitComment(),
                        decoration: InputDecoration(
                          hintText: text.isKy ? 'Комментарий кошуу' : 'Добавить комментарий',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const ValueKey('comment_submit_button'),
                      onPressed: sending ? null : submitComment,
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });

  final PublicRequestComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final authorInitial = comment.authorName.isEmpty ? '?' : comment.authorName.substring(0, 1).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              authorInitial,
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.authorName, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(comment.body, style: TextStyle(color: colors.textStrong, height: 1.3)),
              ],
            ),
          ),
          if (canDelete)
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
    );
  }
}

String _typeLabel(AppText text, String value) {
  switch (value) {
    case 'announcement':
      return text.announcement;
    case 'suggestion':
      return text.suggestion;
    case 'complaint':
      return text.complaint;
    case 'requirement':
      return text.requirement;
    case 'problem':
      return text.problem;
    case 'idea':
      return text.idea;
    default:
      return value;
  }
}

String _modeLabel(AppText text, String value) {
  switch (value) {
    case 'read_only':
      return text.textOnly;
    case 'vote_only':
      return text.votingOnly;
    case 'discussion':
      return text.discussionWithComments;
    default:
      return value;
  }
}

String _statusLabel(AppText text, String value) {
  switch (value) {
    case 'new':
      return text.statusNew;
    case 'under_review':
      return text.statusUnderReview;
    case 'resolved':
      return text.statusResolved;
    case 'rejected':
      return text.statusRejected;
    default:
      return value;
  }
}
