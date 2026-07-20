import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';
import 'public_request_media_widgets.dart';

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
    this.compact = true,
    this.showOpenAction = true,
  });

  final PublicRequest request;
  final VoidCallback onTap;
  final ValueChanged<String> onVote;
  final bool canModerate;
  final ValueChanged<String>? onStatus;
  final bool compact;
  final bool showOpenAction;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final content = request.content;
    final statusColor = _statusColor(context, request.status);
    final canOpen = request.interactionMode == 'discussion';

    return KoomCard(
      margin: const EdgeInsets.only(bottom: 13),
      padding: EdgeInsets.zero,
      onTap: canOpen && showOpenAction ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                KoomAvatar(
                  label: request.authorName,
                  radius: 20,
                  imageBytes: request.authorAvatarBytes,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.authorName.trim().isEmpty
                            ? (text.isKy ? 'Колдонуучу' : 'Пользователь')
                            : request.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        compactTime(request.createdAt.toLocal()),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canModerate && onStatus != null)
                  PopupMenuButton<String>(
                    key: ValueKey('public_request_status_${request.id}'),
                    tooltip: text.adminStatus,
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: onStatus,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        key: const ValueKey(
                          'public_request_status_under_review',
                        ),
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
                  ),
              ],
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                KoomStatusPill(
                  label: _requestTypeLabel(text, request.requestType),
                  icon: _requestTypeIcon(request.requestType),
                ),
                KoomStatusPill(
                  label: _statusLabel(text, request.status),
                  icon: _statusIcon(request.status),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.title,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.15,
              ),
            ),
            if (request.displayBody.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                request.displayBody,
                maxLines: compact ? (content.hasMedia ? 3 : 5) : null,
                overflow: compact
                    ? TextOverflow.ellipsis
                    : TextOverflow.visible,
                style: TextStyle(
                  color: colors.textStrong,
                  height: 1.42,
                  fontSize: 14,
                ),
              ),
            ],
            if (content.hasMedia) ...[
              const SizedBox(height: 12),
              PublicRequestMediaView(content: content, compact: compact),
            ],
            const SizedBox(height: 13),
            Divider(color: colors.border),
            const SizedBox(height: 5),
            Row(
              children: [
                if (request.interactionMode != 'read_only')
                  Expanded(
                    child: _RequestActionButton(
                      key: ValueKey('public_request_support_${request.id}'),
                      icon: request.supportedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${request.supportCount}',
                      selected: request.supportedByMe,
                      onTap: () => onVote('support'),
                    ),
                  ),
                if (request.interactionMode != 'read_only')
                  Expanded(
                    child: _RequestActionButton(
                      key: ValueKey('public_request_oppose_${request.id}'),
                      icon: request.opposedByMe
                          ? Icons.thumb_down_alt_rounded
                          : Icons.thumb_down_alt_outlined,
                      label: '${request.opposeCount}',
                      selected: request.opposedByMe,
                      onTap: () => onVote('oppose'),
                    ),
                  ),
                if (request.interactionMode == 'discussion' && showOpenAction)
                  Expanded(
                    child: _RequestActionButton(
                      key: ValueKey('public_request_read_${request.id}'),
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '${request.commentCount}',
                      onTap: onTap,
                    ),
                  ),
                if (request.interactionMode == 'read_only') ...[
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _interactionModeLabel(text, request.interactionMode),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
                Icon(
                  Icons.ios_share_rounded,
                  size: 19,
                  color: colors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestActionButton extends StatelessWidget {
  const _RequestActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = selected
        ? Theme.of(context).colorScheme.primary
        : colors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _requestTypeIcon(String value) {
  return switch (value) {
    'announcement' => Icons.campaign_outlined,
    'suggestion' => Icons.lightbulb_outline_rounded,
    'complaint' => Icons.report_problem_outlined,
    'requirement' => Icons.assignment_outlined,
    'problem' => Icons.build_circle_outlined,
    'idea' => Icons.auto_awesome_outlined,
    _ => Icons.article_outlined,
  };
}

IconData _statusIcon(String value) {
  return switch (value) {
    'new' => Icons.fiber_new_rounded,
    'under_review' => Icons.hourglass_top_rounded,
    'resolved' => Icons.task_alt_rounded,
    'accepted' => Icons.check_circle_outline_rounded,
    'rejected' => Icons.cancel_outlined,
    _ => Icons.info_outline_rounded,
  };
}

Color _statusColor(BuildContext context, String value) {
  return switch (value) {
    'resolved' || 'accepted' => const Color(0xFF16A36A),
    'rejected' => Theme.of(context).colorScheme.error,
    'under_review' => const Color(0xFFF59E0B),
    _ => Theme.of(context).colorScheme.primary,
  };
}

class MediaPublicRequestDetailsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.readPost),
        actions: const [AppSettingsButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          MediaPublicRequestCard(
            request: request,
            onTap: () {},
            onVote: (_) {},
            canModerate: canModerate,
            onStatus: onStatusChanged,
            compact: false,
            showOpenAction: false,
          ),
        ],
      ),
    );
  }
}
