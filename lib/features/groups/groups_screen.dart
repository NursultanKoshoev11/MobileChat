import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';
import '../group_creation/admin_group_creation_requests_screen.dart';
import '../group_creation/group_creation_requests_screen.dart';
import '../invitations/invitations_screen.dart';
import '../public_requests/public_requests_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, required this.api, required this.session, required this.onLogout});

  final ApiClient api;
  final AppSession session;
  final Future<void> Function() onLogout;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<ChatGroup>> groupsFuture;

  bool get isAdmin => widget.session.user.isPlatformAdmin;

  @override
  void initState() {
    super.initState();
    groupsFuture = widget.api.fetchGroups();
  }

  Future<void> refresh() async {
    final nextGroupsFuture = widget.api.fetchGroups();
    setState(() {
      groupsFuture = nextGroupsFuture;
    });
    await nextGroupsFuture;
  }

  Future<void> createGroup() async {
    if (!isAdmin) {
      await openGroupRequests();
      return;
    }
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => CreateGroupSheet(api: widget.api),
    );
    if (group != null) {
      await refresh();
      if (!mounted) return;
      openGroup(group);
    }
  }

  Future<void> openGroupRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupCreationRequestsScreen(api: widget.api, user: widget.session.user)));
    await refresh();
  }

  Future<void> openAdminRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminGroupCreationRequestsScreen(api: widget.api)));
    await refresh();
  }

  Future<void> joinByCode() async {
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => JoinByCodeSheet(api: widget.api),
    );
    if (group != null) {
      await refresh();
      if (!mounted) return;
      openGroup(group);
    }
  }

  Future<void> openInvitations() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvitationsScreen(api: widget.api)));
    await refresh();
  }

  void openGroup(ChatGroup group) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicRequestsScreen(api: widget.api, user: widget.session.user, group: group)));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.session.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Admin requests',
              onPressed: openAdminRequests,
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: 'My group requests',
            onPressed: openGroupRequests,
            icon: const Icon(Icons.assignment_outlined),
          ),
          IconButton(
            tooltip: 'Invitations',
            onPressed: openInvitations,
            icon: const Icon(Icons.mark_email_unread_outlined),
          ),
          IconButton(
            tooltip: 'Join by code',
            onPressed: joinByCode,
            icon: const Icon(Icons.key_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'create') createGroup();
              if (value == 'requests') openGroupRequests();
              if (value == 'admin_requests') openAdminRequests();
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'requests', child: Text(isAdmin ? 'My requests' : 'Request group')),
              if (isAdmin) const PopupMenuItem(value: 'admin_requests', child: Text('Admin requests')),
              if (isAdmin) const PopupMenuItem(value: 'create', child: Text('Create group')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Log out (${user.role})')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createGroup,
        icon: Icon(isAdmin ? Icons.add_rounded : Icons.verified_user_outlined),
        label: Text(isAdmin ? 'New group' : 'Request group'),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<ChatGroup>>(
          future: groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(24), children: [ErrorBanner(message: snapshot.error.toString())]);
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.groups_2_outlined, size: 72, color: MobileChatTheme.primary),
                  const SizedBox(height: 16),
                  Text('No groups yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(isAdmin ? 'Create a group or approve user requests.' : 'Send a request to create an official group or join by invite code.', textAlign: TextAlign.center, style: const TextStyle(color: MobileChatTheme.textMuted)),
                  const SizedBox(height: 20),
                  Center(child: FilledButton(onPressed: createGroup, child: Text(isAdmin ? 'Create group' : 'Request group'))),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: groups.length,
              itemBuilder: (context, index) => GroupTile(group: groups[index], onTap: () => openGroup(groups[index])),
            );
          },
        ),
      ),
    );
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group, required this.onTap});

  final ChatGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(radius: 26, backgroundColor: group.isPublic ? MobileChatTheme.primary : MobileChatTheme.primaryDark, child: Text(avatarText(group.title), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(group.description.isEmpty ? 'No description yet' : group.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MobileChatTheme.textMuted)),
                    const SizedBox(height: 8),
                    Text('${group.isPublic ? 'Public' : 'Invite only'} · ${group.memberCount} members · ${group.myRole ?? 'member'}', style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w700, fontSize: 12)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key, required this.api});

  final ApiClient api;

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String visibility = 'public';
  bool loading = false;
  String? error;

  @override
  void dispose() { titleController.dispose(); descriptionController.dispose(); super.dispose(); }

  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      final group = await widget.api.createGroup(title: titleController.text.trim(), description: descriptionController.text.trim(), visibility: visibility);
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (e) { setState(() => error = e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Create group', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Group name')),
        const SizedBox(height: 12),
        TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'public', label: Text('Public')), ButtonSegment(value: 'private', label: Text('Invite only'))], selected: {visibility}, onSelectionChanged: (value) => setState(() => visibility = value.first)),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Creating...' : 'Create')),
      ]),
    );
  }
}

class JoinByCodeSheet extends StatefulWidget { const JoinByCodeSheet({super.key, required this.api}); final ApiClient api; @override State<JoinByCodeSheet> createState() => _JoinByCodeSheetState(); }

class _JoinByCodeSheetState extends State<JoinByCodeSheet> {
  final codeController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() { codeController.dispose(); super.dispose(); }

  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      final group = await widget.api.joinByInviteCode(codeController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } catch (e) { setState(() => error = e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Join by code', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Invite code')),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Joining...' : 'Join')),
      ]),
    );
  }
}
