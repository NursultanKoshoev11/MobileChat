import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
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
    final next = widget.api.fetchGroups();
    setState(() => groupsFuture = next);
    await next;
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
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreateGroupSheet(api: widget.api),
    );
    if (group != null) {
      await refresh();
      if (mounted) openGroup(group);
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
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => JoinByCodeSheet(api: widget.api),
    );
    if (group != null) {
      await refresh();
      if (mounted) openGroup(group);
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
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.groups),
        actions: [
          const AppSettingsButton(),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'join') joinByCode();
              if (value == 'invites') openInvitations();
              if (value == 'requests') openGroupRequests();
              if (value == 'admin') openAdminRequests();
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'join', child: Text(text.joinByCode)),
              PopupMenuItem(value: 'invites', child: Text(text.invitations)),
              PopupMenuItem(value: 'requests', child: Text(isAdmin ? text.myRequests : text.requestGroup)),
              if (isAdmin) PopupMenuItem(value: 'admin', child: Text(text.adminRequests)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text(text.logout)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createGroup,
        icon: Icon(isAdmin ? Icons.add_rounded : Icons.verified_user_outlined),
        label: Text(isAdmin ? text.newGroup : text.requestGroup),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<ChatGroup>>(
          future: groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(24), children: [ErrorBanner(message: snapshot.error.toString())]);
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty) return _EmptyGroups(isAdmin: isAdmin, onCreate: createGroup);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: groups.length,
              itemBuilder: (_, index) => GroupTile(group: groups[index], onTap: () => openGroup(groups[index])),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.isAdmin, required this.onCreate});
  final bool isAdmin;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 120),
      const Icon(Icons.groups_2_outlined, size: 72, color: MobileChatTheme.primary),
      const SizedBox(height: 16),
      Text(text.noGroupsYet, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(isAdmin ? text.createGroupOrApprove : text.sendGroupRequestOrJoin, textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textMuted)),
      const SizedBox(height: 20),
      Center(child: FilledButton(onPressed: onCreate, child: Text(isAdmin ? text.createGroup : text.requestGroup))),
    ]);
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile({super.key, required this.group, required this.onTap});
  final ChatGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final visibility = group.isPublic ? (text.isKy ? 'Ачык' : 'Открытая') : (text.isKy ? 'Чакыруу менен' : 'По приглашению');
    final role = roleLabel(group.myRole, text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: group.isPublic ? MobileChatTheme.primary : MobileChatTheme.primaryDark, child: Text(avatarText(group.title), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textStrong, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(group.description.isEmpty ? (text.isKy ? 'Сүрөттөмө жок' : 'Нет описания') : group.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.textMuted)),
                const SizedBox(height: 8),
                Text('$visibility · ${group.memberCount} ${text.isKy ? 'мүчө' : 'участников'} · $role', style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w700, fontSize: 12)),
              ])),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ]),
          ),
        ),
      ),
    );
  }

  String roleLabel(String? role, AppText text) {
    if (role == 'owner') return text.isKy ? 'ээси' : 'владелец';
    if (role == 'admin') return text.isKy ? 'админ' : 'админ';
    return text.isKy ? 'мүчө' : 'участник';
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
      if (mounted) Navigator.of(context).pop(group);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text.createGroup, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: titleController, decoration: InputDecoration(labelText: text.isKy ? 'Топтун аты' : 'Название группы')),
        const SizedBox(height: 12),
        TextField(controller: descriptionController, decoration: InputDecoration(labelText: text.description)),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: [ButtonSegment(value: 'public', label: Text(text.isKy ? 'Ачык' : 'Открытая')), ButtonSegment(value: 'private', label: Text(text.isKy ? 'Чакыруу менен' : 'По приглашению'))], selected: {visibility}, onSelectionChanged: (value) => setState(() => visibility = value.first)),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? (text.isKy ? 'Түзүлүп жатат...' : 'Создаётся...') : text.createGroup)),
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
      if (mounted) Navigator.of(context).pop(group);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text.joinByCode, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: codeController, decoration: InputDecoration(labelText: text.isKy ? 'Чакыруу коду' : 'Код приглашения')),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? (text.isKy ? 'Кирүүдө...' : 'Входим...') : text.joinByCode)),
      ]),
    );
  }
}
