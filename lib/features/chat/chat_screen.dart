import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/moderation.dart';
import '../../data/realtime_client.dart';
import '../../shared/ui_helpers.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.api, required this.user, required this.group});

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

  bool get canPublishAnnouncement => widget.group.myRole == 'owner' || widget.group.myRole == 'admin';

  @override
  void initState() {
    super.initState();
    realtime = RealtimeClient(api: widget.api);
    scrollController.addListener(handleScroll);
    loadInitialMessages();
    connectRealtime();
  }

  @override
  void dispose() {
    scrollController.removeListener(handleScroll);
    scrollController.dispose();
    realtimeSubscription?.cancel();
    realtime.dispose();
    messageController.dispose();
    super.dispose();
  }

  void handleScroll() {
    if (!scrollController.hasClients || loadingOlder || !hasMoreOlder || messages.isEmpty) return;
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 160) {
      loadOlderMessages();
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
      final older = await widget.api.fetchMessages(widget.group.id, limit: 50, before: oldest);
      if (!mounted) return;
      setState(() {
        final newItems = older.reversed.where((message) => !messages.any((item) => item.id == message.id)).toList();
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
      if (event.groupId == widget.group.id && message != null) {
        final exists = messages.any((item) => item.id == message.id);
        if (!exists && mounted) {
          setState(() => messages.add(message));
        }
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
      final message = await widget.api.sendMessage(groupId: widget.group.id, text: text);
      messageController.clear();
      if (!messages.any((item) => item.id == message.id)) {
        setState(() => messages.add(message));
      }
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

  Future<void> inviteById() async {
    final userId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const InviteByIdSheet(),
    );
    if (userId == null || userId.trim().isEmpty) return;
    try {
      await widget.api.inviteUserById(groupId: widget.group.id, targetUserId: userId.trim());
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
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: widget.group.isPublic ? MobileChatTheme.primary : MobileChatTheme.primaryDark,
              child: Text(avatarText(widget.group.title), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.group.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${widget.group.isPublic ? 'Public' : 'Invite only'} · announcements',
                    style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12),
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
      body: Column(
        children: [
          if (!widget.group.isPublic && inviteCode.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: SelectableText('Invite code: $inviteCode'),
            ),
          if (!canPublishAnnouncement)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'Only administrators can publish official announcements. Use Public requests to share ideas, complaints, problems, or requirements.',
                style: TextStyle(color: MobileChatTheme.textStrong),
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
    );
  }

  Widget buildAnnouncementComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, -8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Official announcement'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : send,
              icon: sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.campaign_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessages() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return ListView(padding: const EdgeInsets.all(16), children: [ErrorBanner(message: error!)]);
    if (messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.campaign_outlined, size: 72, color: MobileChatTheme.primary),
          SizedBox(height: 16),
          Text('No announcements yet', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          SizedBox(height: 8),
          Text('Official announcements from administrators will appear here.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),
        ],
      );
    }
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length + (loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (loadingOlder && index == messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final message = messages[messages.length - 1 - index];
        return MessageBubble(message: message, mine: message.senderId == widget.user.id);
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? MobileChatTheme.mineBubble : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('${message.senderName} · official', style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            Text(message.text, style: const TextStyle(color: MobileChatTheme.textStrong)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(compactTime(message.createdAt.toLocal()), style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 11)),
            ),
          ],
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite by ID', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: controller, decoration: const InputDecoration(labelText: 'User ID')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Invite')),
        ],
      ),
    );
  }
}
