import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
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
    final content = request.content;
    return Scaffold(
      appBar: AppBar(title: Text(text.readPost), actions: const [AppSettingsButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          MediaPublicRequestCard(
            request: request,
            onTap: () {},
            onVote: (_) {},
            canModerate: canModerate,
            onStatus: onStatusChanged,
          ),
          if (request.displayBody.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border(context)),
              ),
              child: Text(request.displayBody, style: TextStyle(color: _strong(context), height: 1.35)),
            ),
          ],
          if (content.hasMedia) ...[
            const SizedBox(height: 12),
            PublicRequestMediaView(content: content, compact: false),
          ],
        ],
      ),
    );
  }
}
