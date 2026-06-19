import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../data/models.dart';
import '../../data/moderation.dart';
import '../../data/public_requests_api.dart';
import '../../shared/ui_helpers.dart';

class GroupModerationScreen extends StatefulWidget {
  const GroupModerationScreen({
    super.key,
    required this.api,
    required this.group,
  });

  final PublicRequestsApi api;
  final ChatGroup group;

  @override
  State<GroupModerationScreen> createState() => _GroupModerationScreenState();
}

class _GroupModerationScreenState extends State<GroupModerationScreen> {
  late Future<List<ContentModerationItem>> itemsFuture;
  final Set<String> busyItemIds = <String>{};

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
    return items;
  }

  Future<void> refresh() async {
    final next = loadItems();
    setState(() => itemsFuture = next);
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
      await refresh();
      if (!mounted) return;
      showAppSnack(
        context,
        approve ? 'Material approved.' : 'Material rejected.',
      );
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => busyItemIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('On review'),
        actions: [
          IconButton(
            onPressed: refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const AppSettingsButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<ContentModerationItem>>(
          future: itemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [ErrorBanner(message: snapshot.error.toString())],
              );
            }
            final items = snapshot.data ?? const <ContentModerationItem>[];
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.verified_user_outlined,
                    size: 72,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Review queue is empty',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'There are no new comments or posts waiting for review.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final created = item.createdAt == null
        ? ''
        : '${item.createdAt!.day.toString().padLeft(2, '0')}.${item.createdAt!.month.toString().padLeft(2, '0')}.${item.createdAt!.year} '
            '${item.createdAt!.hour.toString().padLeft(2, '0')}:${item.createdAt!.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    _iconForType(item.contentType),
                    color: colorScheme.primary,
                  ),
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
                            ? 'Author: User'
                            : 'Author: ${item.authorName}',
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
                _InfoChip(label: 'Reason: ${item.reasonLabel}'),
                if (item.provider.isNotEmpty)
                  _InfoChip(label: 'Check: ${item.provider}'),
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
              item.body.isEmpty ? 'Empty text' : item.body,
              style: const TextStyle(height: 1.35),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: loading ? null : onApprove,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
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
