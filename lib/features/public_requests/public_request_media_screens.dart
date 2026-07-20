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
                overflow:
                    compact ? TextOverflow.ellipsis : TextOverflow.visible,
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
            if (request.interactionMode != 'read_only') ...[
              const SizedBox(height: 14),
              _TelegramPoll(
                request: request,
                onVote: onVote,
              ),
            ] else ...[
              const SizedBox(height: 13),
              Divider(color: colors.border),
              const SizedBox(height: 8),
              Row(
                children: [
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
                ],
              ),
            ],
            if (request.interactionMode == 'discussion' && showOpenAction) ...[
              const SizedBox(height: 10),
              Material(
                color: colors.page,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  key: ValueKey('public_request_read_${request.id}'),
                  borderRadius: BorderRadius.circular(15),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 19,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            text.comments,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${request.commentCount}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TelegramPoll extends StatelessWidget {
  const _TelegramPoll({required this.request, required this.onVote});

  final PublicRequest request;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final totalVotes = request.supportCount + request.opposeCount;
    final supportPercent = totalVotes == 0
        ? 0
        : ((request.supportCount / totalVotes) * 100).round();
    final opposePercent = totalVotes == 0 ? 0 : 100 - supportPercent;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: colors.page,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.poll_outlined,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.isKy ? 'Добуш берүү' : 'Голосование',
                  style: TextStyle(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                text.isKy ? '$totalVotes добуш' : '$totalVotes голосов',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TelegramPollOption(
            key: ValueKey('public_request_support_${request.id}'),
            label: text.isKy ? 'Колдойм' : 'Поддерживаю',
            votes: request.supportCount,
            percentage: supportPercent,
            selected: request.supportedByMe,
            onTap: () => onVote('support'),
          ),
          const SizedBox(height: 8),
          _TelegramPollOption(
            key: ValueKey('public_request_oppose_${request.id}'),
            label: text.isKy ? 'Колдобойм' : 'Не поддерживаю',
            votes: request.opposeCount,
            percentage: opposePercent,
            selected: request.opposedByMe,
            onTap: () => onVote('oppose'),
          ),
          if (request.myVote != null) ...[
            const SizedBox(height: 8),
            Text(
              text.isKy
                  ? 'Тандалган вариантты кайра бассаңыз, добуш өчүрүлөт.'
                  : 'Нажмите выбранный вариант ещё раз, чтобы убрать голос.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TelegramPollOption extends StatelessWidget {
  const _TelegramPollOption({
    super.key,
    required this.label,
    required this.votes,
    required this.percentage,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int votes;
  final int percentage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final progress = (percentage / 100).clamp(0.0, 1.0).toDouble();

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $percentage%, $votes',
      child: Material(
        color:
            selected ? scheme.primary.withValues(alpha: 0.09) : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 21,
                      color: selected ? scheme.primary : colors.textMuted,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        color: selected ? scheme.primary : colors.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 5,
                          color: colors.border,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: constraints.maxWidth * progress,
                          height: 5,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          title: Text(text.readPost), actions: const [AppSettingsButton()]),
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
