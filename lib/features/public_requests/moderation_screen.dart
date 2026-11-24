import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/public_requests_api.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

/// Content moderation queue, embedded as the moderation tab of a group.
class GroupModerationView extends StatefulWidget {
  const GroupModerationView({
    super.key,
    required this.api,
    required this.group,
    this.onPendingCountChanged,
  });

  final PublicRequestsApi api;
  final ChatGroup group;

  /// Reports the queue length so the tab badge stays in step with the list.
  final ValueChanged<int>? onPendingCountChanged;

  @override
  State<GroupModerationView> createState() => _GroupModerationViewState();
}

class _GroupModerationViewState extends State<GroupModerationView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Future<List<ContentModerationItem>> itemsFuture;
  final Set<String> busyItemIds = <String>{};
  List<ContentModerationItem> cachedItems = const <ContentModerationItem>[];
  bool itemsLoaded = false;

  @override
  void initState() {
    super.initState();
    itemsFuture = loadItems();
  }

  Future<List<ContentModerationItem>> loadItems() async {
    final items = await widget.api.listModerationItems(widget.group.id);
    items.sort((a, b) {
      final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    cachedItems = items;
    itemsLoaded = true;
    widget.onPendingCountChanged?.call(items.length);
    return items;
  }

  Future<void> refresh() async {
    final next = loadItems();
    setState(() {
      itemsFuture = next;
    });
    await next;
  }

  Future<void> reviewItem(ContentModerationItem item, bool approve) async {
    if (busyItemIds.contains(item.id)) return;
    setState(() => busyItemIds.add(item.id));
    try {
      if (approve) {
        await widget.api.approveModerationItem(item.id);
      } else {
        await widget.api.rejectModerationItem(item.id);
      }
      if (!mounted) return;
      setState(() {
        cachedItems =
            cachedItems.where((value) => value.id != item.id).toList();
        itemsLoaded = true;
      });
      widget.onPendingCountChanged?.call(cachedItems.length);
      final text = AppLanguageScope.textOf(context);
      showAppSnack(
        context,
        approve ? text.moderationApproved : text.moderationRejected,
      );
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => busyItemIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = AppLanguageScope.textOf(context);
    return KoomPageBackground(
      key: const ValueKey('group_moderation_view'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KoomSpacing.lg,
              KoomSpacing.md,
              KoomSpacing.sm,
              0,
            ),
            child: KoomSectionTitle(
              title: text.moderationQueueTitle,
              trailing: IconButton(
                key: const ValueKey('moderation_refresh'),
                onPressed: refresh,
                tooltip: text.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
          onRefresh: refresh,
          child: FutureBuilder<List<ContentModerationItem>>(
            future: itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    KoomSpacing.lg,
                    KoomSpacing.lg,
                    KoomSpacing.lg,
                    KoomSpacing.xl,
                  ),
                  children: const [
                    KoomSkeletonList(
                      itemCount: 3,
                      itemHeight: 188,
                      radius: KoomRadii.lg,
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(KoomSpacing.lg),
                  children: [
                    ErrorBanner(
                      message: localizedMessage(
                        context,
                        snapshot.error.toString(),
                      ),
                    ),
                  ],
                );
              }
              final items = itemsLoaded
                  ? cachedItems
                  : snapshot.data ?? const <ContentModerationItem>[];
              if (items.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(KoomSpacing.lg),
                  children: [
                    KoomCard(
                      showShadow: false,
                      child: KoomEmptyState(
                        icon: Icons.verified_user_outlined,
                        title: text.moderationQueueEmptyTitle,
                        message: text.moderationQueueEmptyMessage,
                      ),
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  KoomSpacing.lg,
                  KoomSpacing.md,
                  KoomSpacing.lg,
                  KoomSpacing.xl,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: KoomSpacing.md),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _ModerationItemCard(
                    item: item,
                    loading: busyItemIds.contains(item.id),
                    onApprove: () => reviewItem(item, true),
                    onReject: () => reviewItem(item, false),
                  );
                },
              );
            },
          ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationItemCard extends StatelessWidget {
  const _ModerationItemCard({
    required this.item,
    required this.loading,
    required this.onApprove,
    required this.onReject,
  });

  final ContentModerationItem item;
  final bool loading;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = AppLanguageScope.textOf(context);
    final created = item.createdAt == null
        ? ''
        : '${item.createdAt!.day.toString().padLeft(2, '0')}.${item.createdAt!.month.toString().padLeft(2, '0')}.${item.createdAt!.year} '
            '${item.createdAt!.hour.toString().padLeft(2, '0')}:${item.createdAt!.minute.toString().padLeft(2, '0')}';

    return KoomCard(
      padding: EdgeInsets.zero,
      showShadow: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                KoomAvatar(
                  label: item.authorName,
                  radius: 21,
                  icon: _iconForType(item.contentType),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.typeLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.authorName.isEmpty
                            ? '${text.author}: User'
                            : '${text.author}: ${item.authorName}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (created.isNotEmpty)
                  Text(
                    created,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(label: '${text.reason}: ${item.reasonLabel}'),
                if (item.provider.isNotEmpty)
                  _InfoChip(label: '${text.moderationCheck}: ${item.provider}'),
              ],
            ),
            if (item.title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              item.body.isEmpty ? text.emptyBodyText : item.body,
              style: const TextStyle(height: 1.35),
            ),
            const SizedBox(height: 14),
            KoomResponsiveActions(
              children: [
                OutlinedButton.icon(
                  onPressed: loading ? null : onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(
                    text.reject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : onApprove,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    text.approve,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'public_request_comment':
        return Icons.mode_comment_outlined;
      case 'public_request':
        return Icons.feed_outlined;
      case 'group_message':
        return Icons.campaign_outlined;
      default:
        return Icons.shield_outlined;
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
