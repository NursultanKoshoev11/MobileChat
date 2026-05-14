import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
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
  late Future<List<ChatMessage>> messagesFuture;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    messagesFuture = widget.api.fetchMessages(widget.group.id);
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => messagesFuture = widget.api.fetchMessages(widget.group.id));
    await messagesFuture;
  }

  Future<void> send() async {
    final text = messageController.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.api.sendMessage(groupId: widget.group.id, text: text);
      messageController.clear();
      await refresh();
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
                    '${widget.group.isPublic ? 'Public' : 'Invite only'} · ${widget.group.memberCount} members',
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
          if (!widget.group.isPublic && widget.group.inviteCode != null && widget.group.inviteCode!.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: SelectableText('Invite code: ${widget.group.inviteCode}'),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: FutureBuilder<List<ChatMessage>>(
                future: messagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(padding: const EdgeInsets.all(16), children: [ErrorBanner(message: snapshot.error.toString())]);
                  }
                  final messages = snapshot.data ?? const [];
                  if (messages.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.chat_bubble_outline_rounded, size: 72, color: MobileChatTheme.primary),
                        SizedBox(height: 16),
                        Text('No messages yet', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                        SizedBox(height: 8),
                        Text('Start the group conversation.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),
                      ],
                    );
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      return MessageBubble(message: message, mine: message.senderId == widget.user.id);
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
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
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending ? null : send,
                    icon: sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
                child: Text('${message.senderName} · ${message.senderId}', style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)),
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
