import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../shared/ui_helpers.dart';
import 'public_request_media_widgets.dart';

Color _surface(BuildContext context) => Theme.of(context).cardColor;
Color _border(BuildContext context) => Theme.of(context).dividerColor;
Color _muted(BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);
Color _strong(BuildContext context) => Theme.of(context).colorScheme.onSurface;

String _requestTypeLabel(AppText text, String value) {
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

String _interactionModeLabel(AppText text, String value) {
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
    case 'accepted':
      return text.statusAccepted;
    case 'rejected':
      return text.statusRejected;
    default:
      return value;
  }
}

class MediaPublicRequestCard extends StatelessWidget {
  const MediaPublicRequestCard({
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
    final content = request.content;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: _surface(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: _border(context)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: request.interactionMode == 'discussion' ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    [_requestTypeLabel(text, request.requestType), _interactionModeLabel(text, request.interactionMode), _statusLabel(text, request.status)].join(' · '),
                    style: TextStyle(
                      color: _muted(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (canModerate && onStatus != null)
                  PopupMenuButton<String>(
                    onSelected: onStatus,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'under_review', child: Text(text.statusUnderReview)),
                      PopupMenuItem(value: 'resolved', child: Text(text.statusResolved)),
                      PopupMenuItem(value: 'new', child: Text(text.statusNew)),
                      PopupMenuItem(value: 'rejected', child: Text(text.statusRejected)),
                    ],
                    child: Icon(Icons.sync_alt_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(request.title, style: TextStyle(color: _strong(context), fontSize: 17, fontWeight: FontWeight.w800)),
              if (request.displayBody.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(request.displayBody, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (content.hasMedia) ...[
                const SizedBox(height: 10),
                PublicRequestMediaView(content: content),
              ],
              const SizedBox(height: 10),
              Text('${text.isKy ? 'Автор' : 'Автор'}: ${request.authorName}', style: TextStyle(color: _muted(context), fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (request.interactionMode == 'discussion') FilledButton.tonal(onPressed: onTap, child: Text(text.read)),
                if (request.interactionMode != 'read_only')
                  OutlinedButton.icon(
                    onPressed: () => onVote('support'),
                    icon: Icon(request.supportedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined),
                    label: Text('${request.supportCount}'),
                  ),
                if (request.interactionMode != 'read_only')
                  OutlinedButton.icon(
                    onPressed: () => onVote('oppose'),
                    icon: Icon(request.opposedByMe ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined),
                    label: Text('${request.opposeCount}'),
                  ),
                if (request.interactionMode == 'discussion') Text('${request.commentCount} ${text.comments}', style: TextStyle(color: _muted(context))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class MediaPublicRequestDetailsScreen extends StatefulWidget {
  const MediaPublicRequestDetailsScreen({
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
  State<MediaPublicRequestDetailsScreen> createState() =>
      _MediaPublicRequestDetailsScreenState();
}

class _MediaPublicRequestDetailsScreenState
    extends State<MediaPublicRequestDetailsScreen> {
  final commentController = TextEditingController();
  late Future<List<PublicRequestComment>> commentsFuture;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    commentsFuture = widget.api.listComments(widget.request.id);
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> refreshComments() async {
    final next = widget.api.listComments(widget.request.id);
    if (mounted) setState(() => commentsFuture = next);
    await next;
  }

  Future<void> submitComment() async {
    final body = commentController.text.trim();
    if (body.isEmpty ||
        sending ||
        widget.request.interactionMode != 'discussion') return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.api.addComment(requestId: widget.request.id, body: body);
      commentController.clear();
      await refreshComments();
    } on ModerationPendingException catch (e) {
      commentController.clear();
      if (mounted) {
        setState(() => error = null);
        showAppSnack(context, e.message);
      }
      await refreshComments();
    } catch (e) {
      if (mounted) setState(() => error = localizedMessage(context, e.toString()));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> removeComment(PublicRequestComment comment) async {
    if (!widget.canModerate && comment.authorId != widget.currentUserId) return;
    try {
      await widget.api.deleteComment(comment.id);
      await refreshComments();
    } catch (e) {
      if (mounted) showAppSnack(context, localizedMessage(context, e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final content = widget.request.content;
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(text.readPost),
        actions: const [AppSettingsButton()],
      ),
      body: RefreshIndicator(
        onRefresh: refreshComments,
        child: FutureBuilder<List<PublicRequestComment>>(
          future: commentsFuture,
          builder: (context, snapshot) {
            final comments = snapshot.data ?? const <PublicRequestComment>[];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                MediaPublicRequestCard(
                  request: widget.request,
                  onTap: () {},
                  onVote: (_) {},
                  canModerate: widget.canModerate,
                  onStatus: widget.onStatusChanged,
                ),
                if (widget.request.displayBody.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border(context)),
                    ),
                    child: Text(
                      widget.request.displayBody,
                      style: TextStyle(color: _strong(context), height: 1.35),
                    ),
                  ),
                ],
                if (content.hasMedia) ...[
                  const SizedBox(height: 12),
                  PublicRequestMediaView(content: content, compact: false),
                ],
                const SizedBox(height: 18),
                Text(
                  text.comments,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (error != null) ...[
                  ErrorBanner(message: error!),
                  const SizedBox(height: 10),
                ],
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  ErrorBanner(message: localizedMessage(context, snapshot.error.toString()))
                else if (comments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: colors.border),
                    ),
                    child: Text(
                      text.isKy
                          ? 'Комментарий азырынча жок.'
                          : 'Комментариев пока нет.',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  )
                else
                  ...comments.map(
                    (item) => _MediaCommentTile(
                      comment: item,
                      canDelete: widget.canModerate ||
                          item.authorId == widget.currentUserId,
                      onDelete: () => removeComment(item),
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
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => submitComment(),
                      decoration: InputDecoration(
                        hintText: text.isKy
                            ? 'Комментарий кошуу'
                            : 'Добавить комментарий',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : submitComment,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

class _MediaCommentTile extends StatelessWidget {
  const _MediaCommentTile({
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
    final initial = comment.authorName.isEmpty
        ? '?'
        : comment.authorName.substring(0, 1).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: Text(
            initial,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              comment.authorName,
              style: TextStyle(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              comment.body,
              style: TextStyle(color: colors.textStrong, height: 1.3),
            ),
          ]),
        ),
        if (canDelete)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ]),
    );
  }
}
