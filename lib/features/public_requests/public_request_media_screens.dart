import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/blocked_users.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../shared/koom_ui.dart';
import 'public_request_media_widgets.dart';
import '../safety/safety_ui.dart';

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

/// Minimum size of an interactive area, per the platform accessibility
/// guidelines. Used for the menus and links on the post card.
const double kKoomMinTapTarget = 48;

/// A post card: author row, one type chip plus a status dot, title, body,
/// media, poll and a footer with the vote count and the comment link.
///
/// The constructor is kept source-compatible with the previous version: the
/// publications list, the moderation screen and the detail screens all build
/// this widget with the same named arguments.
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
    this.safetyMenu,
  });

  final PublicRequest request;
  final VoidCallback onTap;
  final ValueChanged<String> onVote;
  final bool canModerate;
  final ValueChanged<String>? onStatus;
  final bool compact;
  final bool showOpenAction;

  /// Report / block menu for other users' publications.
  final Widget? safetyMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final content = request.content;
    final canOpen = request.interactionMode == 'discussion';

    return KoomCard(
      margin: const EdgeInsets.only(bottom: KoomSpacing.md),
      padding: const EdgeInsets.all(KoomSpacing.lg),
      onTap: canOpen && showOpenAction ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(
            request: request,
            canModerate: canModerate,
            onStatus: onStatus,
            safetyMenu: safetyMenu,
          ),
          const SizedBox(height: KoomSpacing.md),
          _MetaRow(request: request),
          const SizedBox(height: KoomSpacing.md),
          Text(
            request.title,
            style: textTheme.titleMedium?.copyWith(height: 1.3),
          ),
          if (request.displayBody.isNotEmpty) ...[
            const SizedBox(height: KoomSpacing.sm),
            Text(
              request.displayBody,
              maxLines: compact ? (content.hasMedia ? 3 : 5) : null,
              overflow:
                  compact ? TextOverflow.ellipsis : TextOverflow.visible,
              style: textTheme.bodyMedium,
            ),
          ],
          if (content.hasMedia) ...[
            const SizedBox(height: KoomSpacing.lg),
            PublicRequestMediaView(content: content, compact: compact),
          ],
          if (request.interactionMode != 'read_only') ...[
            const SizedBox(height: KoomSpacing.lg),
            _PollBlock(request: request, onVote: onVote),
          ],
          const SizedBox(height: KoomSpacing.sm),
          Divider(color: colors.border, height: 1),
          _FooterRow(
            request: request,
            showOpenAction: showOpenAction,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.request,
    required this.canModerate,
    required this.onStatus,
    required this.safetyMenu,
  });

  final PublicRequest request;
  final bool canModerate;
  final ValueChanged<String>? onStatus;
  final Widget? safetyMenu;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final textTheme = Theme.of(context).textTheme;
    final authorName = request.authorId.isEmpty
        ? text.deletedAccount
        : request.authorName.trim().isEmpty
            ? text.unnamedUser
            : request.authorName.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kKoomMinTapTarget),
      child: Row(
        children: [
          KoomAvatar(
            label: authorName,
            radius: 21,
            imageBytes: request.authorAvatarBytes,
          ),
          const SizedBox(width: KoomSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                Text(
                  koomRelativeTime(text, request.createdAt.toLocal()),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (safetyMenu != null) safetyMenu!,
          if (canModerate && onStatus != null)
            SizedBox(
              width: kKoomMinTapTarget,
              height: kKoomMinTapTarget,
              child: PopupMenuButton<String>(
                key: ValueKey('public_request_status_${request.id}'),
                tooltip: text.adminStatus,
                padding: EdgeInsets.zero,
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
            ),
        ],
      ),
    );
  }
}

/// One chip for the post type, and the status as a dot plus a quiet label.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.request});

  final PublicRequest request;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    // Both halves are Flexible so neither can claim its natural width: the
    // chip has its own max width, and on a narrow phone at a large text scale
    // that would otherwise leave the status dot no room at all.
    return Row(
      children: [
        Flexible(
          child: KoomStatusPill(
            key: ValueKey('public_request_type_${request.id}'),
            label: _requestTypeLabel(text, request.requestType),
            icon: _requestTypeIcon(request.requestType),
          ),
        ),
        const SizedBox(width: KoomSpacing.md),
        Flexible(
          child: KoomStatusDot(
            key: ValueKey('public_request_status_dot_${request.id}'),
            color: _statusColor(context, request.status),
            label: _statusLabel(text, request.status),
          ),
        ),
      ],
    );
  }
}

/// Vote total on the left, comment link on the right.
class _FooterRow extends StatelessWidget {
  const _FooterRow({
    required this.request,
    required this.showOpenAction,
    required this.onTap,
  });

  final PublicRequest request;
  final bool showOpenAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final totalVotes = request.supportCount + request.opposeCount;
    final isDiscussion = request.interactionMode == 'discussion';

    // Both halves of the footer live in a flex slot of the row below, so every
    // label here can be Flexible and ellipsize. Narrow phones at a large text
    // scale, and Kyrgyz labels (which run longer than the Russian), both need
    // that: nothing in this row may claim its natural width.
    Widget stat(IconData icon, String label, {Key? labelKey}) {
      return SizedBox(
        height: kKoomMinTapTarget,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colors.textMuted),
            const SizedBox(width: KoomSpacing.sm),
            Flexible(
              child: Text(
                label,
                key: labelKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final leading = request.interactionMode == 'read_only'
        ? stat(
            Icons.visibility_outlined,
            _interactionModeLabel(text, request.interactionMode),
          )
        : stat(
            Icons.how_to_vote_outlined,
            '${text.votesLabel}: $totalVotes',
            labelKey: ValueKey('public_request_vote_total_${request.id}'),
          );

    Widget? trailing;
    if (isDiscussion && showOpenAction) {
      trailing = SizedBox(
        height: kKoomMinTapTarget,
        child: Material(
          color: Colors.transparent,
          borderRadius: KoomRadii.smAll,
          child: InkWell(
            key: ValueKey('public_request_read_${request.id}'),
            borderRadius: KoomRadii.smAll,
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: KoomSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: KoomSpacing.sm),
                  Flexible(
                    child: Text(
                      text.comments,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: KoomSpacing.sm),
                  Text(
                    '${request.commentCount}',
                    key: ValueKey(
                      'public_request_comment_count_${request.id}',
                    ),
                    maxLines: 1,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (isDiscussion) {
      trailing = stat(
        Icons.chat_bubble_outline_rounded,
        '${text.comments}: ${request.commentCount}',
        labelKey: ValueKey('public_request_comment_count_${request.id}'),
      );
    }

    final footer = trailing;
    if (footer == null) return leading;

    // Same heuristic as [KoomResponsiveActions]: on a narrow phone, or at a
    // large text scale, the vote total and the comment link stop sharing a
    // line. Side by side there is not enough width for both in either
    // language, and the Kyrgyz labels are the longer pair.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBodySize = MediaQuery.textScalerOf(context).scale(14);
        final stackVertically =
            constraints.maxWidth < 340 || scaledBodySize > 17.5;

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [leading, footer],
          );
        }

        // Expanded keeps the link pinned right; Flexible lets it give way
        // rather than claim its natural width and push the row over the edge.
        return Row(
          children: [
            Expanded(child: leading),
            const SizedBox(width: KoomSpacing.sm),
            Flexible(child: footer),
          ],
        );
      },
    );
  }
}

class _PollBlock extends StatelessWidget {
  const _PollBlock({required this.request, required this.onVote});

  final PublicRequest request;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final totalVotes = request.supportCount + request.opposeCount;
    final supportPercent = totalVotes == 0
        ? 0
        : ((request.supportCount / totalVotes) * 100).round();
    final opposePercent = totalVotes == 0 ? 0 : 100 - supportPercent;

    return Container(
      padding: const EdgeInsets.all(KoomSpacing.md),
      decoration: BoxDecoration(
        color: colors.page,
        borderRadius: KoomRadii.mdAll,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.poll_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: KoomSpacing.sm),
              Expanded(
                child: Text(text.voting, style: textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: KoomSpacing.md),
          _PollOption(
            key: ValueKey('public_request_support_${request.id}'),
            label: text.voteSupport,
            votes: request.supportCount,
            percentage: supportPercent,
            selected: request.supportedByMe,
            onTap: () => onVote('support'),
          ),
          const SizedBox(height: KoomSpacing.sm),
          _PollOption(
            key: ValueKey('public_request_oppose_${request.id}'),
            label: text.voteOppose,
            votes: request.opposeCount,
            percentage: opposePercent,
            selected: request.opposedByMe,
            onTap: () => onVote('oppose'),
          ),
          if (request.myVote != null) ...[
            const SizedBox(height: KoomSpacing.sm),
            Text(
              text.voteToggleHint,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
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
    final textTheme = Theme.of(context).textTheme;
    final progress = (percentage / 100).clamp(0.0, 1.0).toDouble();

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $percentage%, $votes',
      child: Material(
        color:
            selected ? scheme.primary.withValues(alpha: 0.09) : colors.surface,
        borderRadius: KoomRadii.smAll,
        child: InkWell(
          borderRadius: KoomRadii.smAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KoomSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: selected ? scheme.primary : colors.textMuted,
                    ),
                    const SizedBox(width: KoomSpacing.sm),
                    Expanded(
                      child: Text(label, style: textTheme.titleSmall),
                    ),
                    Text(
                      '$percentage%',
                      style: textTheme.labelLarge?.copyWith(
                        color: selected ? scheme.primary : colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KoomSpacing.sm),
                ClipRRect(
                  borderRadius: KoomRadii.pillAll,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(height: 5, color: colors.border),
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

Color _statusColor(BuildContext context, String value) {
  return switch (value) {
    'resolved' || 'accepted' => const Color(0xFF16A36A),
    'rejected' => context.appColors.danger,
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
      body: ListenableBuilder(
        listenable: BlockedUsersController.instance,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            KoomSpacing.lg,
            KoomSpacing.md,
            KoomSpacing.lg,
            KoomSpacing.xl,
          ),
          children: [
            if (BlockedUsersController.instance.isBlocked(request.authorId))
              const BlockedContentNotice()
            else
              MediaPublicRequestCard(
                request: request,
                onTap: () {},
                onVote: (_) {},
                canModerate: canModerate,
                onStatus: onStatusChanged,
                compact: false,
                showOpenAction: false,
                safetyMenu: ContentSafetyMenuButton(
                  api: api,
                  target: SafetyTarget(
                    targetType: ReportTargetType.publicRequest,
                    targetId: request.id,
                    authorId: request.authorId,
                    authorName: request.authorName,
                    currentUserId: currentUserId,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
