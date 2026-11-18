import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/blocked_users.dart';
import '../../data/models.dart';
import '../../data/moderation.dart';
import '../../data/realtime_client.dart';
import '../../data/safety.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';
import '../safety/safety_ui.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen(
      {super.key, required this.api, required this.user, required this.group});

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  late final RealtimeClient realtime;
  StreamSubscription<RealtimeEvent>? realtimeSubscription;
  final List<ChatMessage> messages = [];
  bool loading = true;
  bool sending = false;
  bool loadingOlder = false;
  bool hasMoreOlder = true;
  String? error;

  bool get canPublishAnnouncement =>
      widget.group.myRole == 'owner' || widget.group.myRole == 'admin';

  @override
  void initState() {
    super.initState();
    realtime = RealtimeClient(api: widget.api);
    scrollController.addListener(handleScroll);
    BlockedUsersController.instance.addListener(_handleBlockedUsersChanged);
    unawaited(_initializeChat());
  }

  void _handleBlockedUsersChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeChat() async {
    await loadInitialMessages();
    if (!mounted) return;
    await connectRealtime();
  }

  @override
  void dispose() {
    BlockedUsersController.instance.removeListener(_handleBlockedUsersChanged);
    scrollController.removeListener(handleScroll);
    scrollController.dispose();
    realtimeSubscription?.cancel();
    realtime.dispose();
    messageController.dispose();
    super.dispose();
  }

  void handleScroll() {
    if (!scrollController.hasClients ||
        loadingOlder ||
        !hasMoreOlder ||
        messages.isEmpty) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      loadOlderMessages();
    }
  }

  int _compareMessages(ChatMessage a, ChatMessage b) {
    final byDate = a.createdAt.compareTo(b.createdAt);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  void _upsertMessage(ChatMessage message) {
    final index = messages.indexWhere((item) => item.id == message.id);
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages.add(message);
    }
    messages.sort(_compareMessages);
  }

  Future<void> _syncMessagesAfterReconnect() async {
    try {
      if (messages.isEmpty) {
        await loadInitialMessages();
        return;
      }
      final catchUpFrom = messages.last;
      final latest = await widget.api.fetchMessages(widget.group.id, limit: 50);
      if (!mounted) return;
      if (latest.isNotEmpty) {
        final newestPage = latest.reversed.toList();
        final oldestInPage = newestPage.first;
        final latestIds = newestPage.map((message) => message.id).toSet();
        setState(() {
          messages.removeWhere((message) => _compareMessages(message, oldestInPage) >= 0 && !latestIds.contains(message.id));
          for (final message in newestPage) {
            _upsertMessage(message);
          }
        });
      }
      var cursor = catchUpFrom;
      while (mounted) {
        final batch = await widget.api.fetchMessagesAfter(
          widget.group.id,
          after: cursor.createdAt,
          afterId: cursor.id,
        );
        if (!mounted || batch.isEmpty) return;
        setState(() {
          for (final message in batch) {
            _upsertMessage(message);
          }
        });
        cursor = batch.last;
        if (batch.length < 100) return;
      }
    } catch (_) {
      // A future reconnect will retry the catch-up read.
    }
  }

  Future<void> loadInitialMessages() async {
    setState(() {
      loading = true;
      error = null;
      hasMoreOlder = true;
    });
    try {
      final loaded = await widget.api.fetchMessages(widget.group.id, limit: 50);
      if (!mounted) return;
      setState(() {
        messages
          ..clear()
          ..addAll(loaded.reversed);
        hasMoreOlder = loaded.length == 50;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadOlderMessages() async {
    if (messages.isEmpty || loadingOlder || !hasMoreOlder) return;
    setState(() => loadingOlder = true);
    try {
      final oldest = messages.first.createdAt;
      final older = await widget.api
          .fetchMessages(widget.group.id, limit: 50, before: oldest, beforeId: messages.first.id);
      if (!mounted) return;
      setState(() {
        final newItems = older.reversed
            .where((message) => !messages.any((item) => item.id == message.id))
            .toList();
        messages.insertAll(0, newItems);
        hasMoreOlder = older.length == 50;
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => loadingOlder = false);
    }
  }

  Future<void> connectRealtime() async {
    realtimeSubscription = realtime.events.listen((event) {
      final message = event.message;
      if (event.groupId != widget.group.id || !mounted) {
        return;
      }
      if (event.type == 'connection.ready') {
        unawaited(_syncMessagesAfterReconnect());
        return;
      }
      if (message == null) return;
      // Realtime events are not filtered server-side.
      if (event.type != 'message.deleted' &&
          BlockedUsersController.instance.isBlocked(message.senderId)) {
        return;
      }
      switch (event.type) {
        case 'message.created':
          setState(() => _upsertMessage(message));
          break;
        case 'message.updated':
          setState(() => _upsertMessage(message));
          break;
        case 'message.deleted':
          setState(() => messages.removeWhere((item) => item.id == message.id));
          break;
      }
    });
    await realtime.connectToGroup(widget.group.id);
  }

  Future<void> refresh() async {
    await loadInitialMessages();
  }

  Future<void> send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending || !canPublishAnnouncement) return;
    setState(() => sending = true);
    try {
      final message =
          await widget.api.sendMessage(groupId: widget.group.id, text: text);
      messageController.clear();
      setState(() => _upsertMessage(message));
    } on ModerationPendingException catch (e) {
      messageController.clear();
      if (!mounted) return;
      showAppSnack(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> showMessageSafetyActions(ChatMessage message) async {
    final target = SafetyTarget(
      targetType: ReportTargetType.message,
      targetId: message.id,
      authorId: message.senderId,
      authorName: message.senderName,
      currentUserId: widget.user.id,
    );
    if (!target.canReport) return;
    final text = AppLanguageScope.textOf(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in safetyMenuEntries(text, target))
              if (entry is PopupMenuItem<String>)
                ListTile(
                  key: entry.key,
                  title: entry.child,
                  onTap: () => Navigator.of(sheetContext).pop(entry.value),
                ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    await handleSafetyMenuAction(
      context,
      action,
      api: widget.api,
      target: target,
    );
  }

  Future<void> inviteById() async {
    final userId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => const InviteByIdSheet(),
    );
    if (userId == null || userId.trim().isEmpty) return;
    try {
      await widget.api.inviteUserById(
          groupId: widget.group.id, targetUserId: userId.trim());
      if (!mounted) return;
      showAppSnack(context, 'Invitation sent.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteCode = widget.group.inviteCode ?? '';
    final colors = context.appColors;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            KoomAvatar(
              label: widget.group.title,
              radius: 20,
              icon: widget.group.isPublic
                  ? Icons.groups_2_rounded
                  : Icons.lock_rounded,
              imageBytes: widget.group.avatarBytes,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.group.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${widget.group.isPublic ? 'Public' : 'Invite only'} · announcements',
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: widget.group.canInvite ? inviteById : null,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      body: KoomPageBackground(
        child: Column(
          children: [
            if (!widget.group.isPublic && inviteCode.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_rounded, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 10),
                    Expanded(child: SelectableText('Invite code: $inviteCode')),
                  ],
                ),
              ),
            if (!canPublishAnnouncement)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Only administrators can publish official announcements. Use Public requests to share ideas, complaints, problems, or requirements.',
                        style:
                            TextStyle(color: colors.textStrong, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                child: buildMessages(),
              ),
            ),
            if (canPublishAnnouncement) buildAnnouncementComposer(),
          ],
        ),
      ),
    );
  }

  Widget buildAnnouncementComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border(top: BorderSide(color: context.appColors.border)),
          boxShadow: [
            BoxShadow(
                color: context.appColors.shadow,
                blurRadius: 18,
                offset: const Offset(0, -8))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(hintText: 'Official announcement'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : send,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.campaign_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessages() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [ErrorBanner(message: error!)]);
    }
    final visibleMessages = BlockedUsersController.instance.visible(
      messages,
      (message) => message.senderId,
    );
    if (visibleMessages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          KoomEmptyState(
            icon: Icons.campaign_outlined,
            title: 'No announcements yet',
            message:
                'Official announcements from administrators will appear here.',
          ),
        ],
      );
    }
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: visibleMessages.length + (loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (loadingOlder && index == visibleMessages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final message = visibleMessages[visibleMessages.length - 1 - index];
        final mine = message.senderId == widget.user.id;
        return MessageBubble(
          message: message,
          mine: mine,
          onLongPress: mine
              ? null
              : () => showMessageSafetyActions(message),
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;

  /// Opens report / block actions for other users' messages.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine
                ? (dark ? const Color(0xFF123A63) : KoomTheme.mineBubble)
                : colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                  color: colors.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('${message.senderName} · official',
                      style: const TextStyle(
                          color: KoomTheme.primaryDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              Text(message.text, style: TextStyle(color: colors.textStrong)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(compactTime(message.createdAt.toLocal()),
                    style: TextStyle(color: colors.textMuted, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InviteByIdSheet extends StatefulWidget {
  const InviteByIdSheet({super.key});

  @override
  State<InviteByIdSheet> createState() => _InviteByIdSheetState();
}

class _InviteByIdSheetState extends State<InviteByIdSheet> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KoomSheetFrame(
      title: 'Invite by ID',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'User ID',
              prefixIcon: Icon(Icons.person_search_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(controller.text),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Invite'),
          ),
        ],
      ),
    );
  }
}
