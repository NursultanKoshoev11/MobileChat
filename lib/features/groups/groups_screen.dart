import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_requests_api.dart';
import '../../services/user_realtime_service.dart';
import '../../shared/ui_helpers.dart';
import '../group_creation/admin_group_creation_requests_screen.dart';
import '../group_creation/group_creation_requests_screen.dart';
import '../invitations/invitations_screen.dart';
import '../profile/profile_screen.dart';
import '../public_requests/public_requests_screen.dart';
import 'group_qr_scan_screen.dart';

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
  late Future<int> adminRequestsCountFuture;
  late Future<int> invitationsCountFuture;
  late final UserRealtimeService userRealtime;
  Timer? _realtimeRefreshDebounce;
  bool get isAdmin => widget.session.user.isPlatformAdmin;

  @override
  void initState() {
    super.initState();
    groupsFuture = widget.api.fetchGroups();
    adminRequestsCountFuture = loadAdminRequestsCount();
    invitationsCountFuture = loadInvitationsCount();
    userRealtime = UserRealtimeService(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore);
    userRealtime.connect(onEvent: _handleUserRealtimeEvent);
  }

  @override
  void dispose() {
    _realtimeRefreshDebounce?.cancel();
    userRealtime.close();
    super.dispose();
  }

  void _handleUserRealtimeEvent(UserRealtimeEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'invite.created':
      case 'invite.reviewed':
      case 'group_creation_request.created':
      case 'group_creation_request.reviewed':
        _scheduleRealtimeRefresh();
        break;
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) refresh();
    });
  }

  Future<int> loadAdminRequestsCount() async {
    if (!isAdmin) return 0;
    try { return (await widget.api.fetchAdminGroupCreationRequests(status: 'pending')).length; } catch (_) { return 0; }
  }

  Future<int> loadInvitationsCount() async {
    try { return (await widget.api.fetchInvitations()).length; } catch (_) { return 0; }
  }

  Future<void> refresh() async {
    final nextGroups = widget.api.fetchGroups();
    final nextAdminCount = loadAdminRequestsCount();
    final nextInvitationsCount = loadInvitationsCount();
    setState(() {
      groupsFuture = nextGroups;
      adminRequestsCountFuture = nextAdminCount;
      invitationsCountFuture = nextInvitationsCount;
    });
    await Future.wait([nextGroups, nextAdminCount, nextInvitationsCount]);
  }

  Future<void> createGroup() async {
    if (!isAdmin) { await openGroupRequests(); return; }
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreateGroupSheet(api: widget.api),
    );
    if (group != null) { await refresh(); if (mounted) await openGroup(group); }
  }

  Future<void> openGroupRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupCreationRequestsScreen(api: widget.api, user: widget.session.user)));
    await refresh();
  }

  Future<void> openAdminRequests() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminGroupCreationRequestsScreen(api: widget.api)));
    await refresh();
  }

  Future<void> openProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(user: widget.session.user)));
  }

  Future<void> joinByCode() async {
    final group = await showModalBottomSheet<ChatGroup>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => JoinByCodeSheet(api: widget.api),
    );
    if (group != null) { await refresh(); if (mounted) await openGroup(group); }
  }

  Future<void> scanGroupQr() async {
    final inviteCode = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const GroupQrScanScreen()));
    if (inviteCode == null || inviteCode.trim().isEmpty) return;
    try {
      final group = await widget.api.joinByInviteCode(formatGroupInviteCode(inviteCode));
      await refresh();
      if (mounted) await openGroup(group);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> openInvitations() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvitationsScreen(api: widget.api)));
    await refresh();
  }

  Future<void> openGroup(ChatGroup group) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicRequestsScreen(api: widget.api, user: widget.session.user, group: group)));
    if (mounted) await refresh();
  }

  Future<void> leaveGroup(ChatGroup group) async {
    final text = AppLanguageScope.textOf(context);
    if (group.myRole == 'owner') {
      showAppSnack(context, text.isKy ? 'Ээси топтон чыга албайт.' : 'Владелец группы не может выйти из группы.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.isKy ? 'Топтон чыгуу' : 'Выйти из группы'),
        content: Text(text.isKy ? 'Бул топтон чыгууну каалайсызбы?' : 'Вы действительно хотите выйти из этой группы?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(text.isKy ? 'Жок' : 'Отмена')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: Text(text.isKy ? 'Чыгуу' : 'Выйти')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PublicRequestsApi(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore).leaveGroup(group.id);
      await refresh();
      if (mounted) showAppSnack(context, text.isKy ? 'Сиз топтон чыктыңыз.' : 'Вы вышли из группы.');
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    }
  }

  Future<void> showMainMenu() async {
    final counts = await Future.wait([adminRequestsCountFuture, invitationsCountFuture]);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => MainGroupsMenuSheet(
        isAdmin: isAdmin,
        adminRequestsCount: counts[0],
        invitationsCount: counts[1],
        onProfile: openProfile,
        onJoinByCode: joinByCode,
        onScanQr: scanGroupQr,
        onInvitations: openInvitations,
        onMyRequests: openGroupRequests,
        onAdminRequests: openAdminRequests,
        onLogout: widget.onLogout,
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.groups),
        actions: [
          const AppSettingsButton(),
          IconButton(onPressed: showMainMenu, icon: const Icon(Icons.more_vert_rounded), tooltip: text.isKy ? 'Меню' : 'Меню'),
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
              itemBuilder: (_, index) => GroupTile(group: groups[index], onTap: () => openGroup(groups[index]), onLeave: () => leaveGroup(groups[index])),
            );
          },
        ),
      ),
    );
  }
}

class MainGroupsMenuSheet extends StatelessWidget {
  const MainGroupsMenuSheet({super.key, required this.isAdmin, required this.adminRequestsCount, required this.invitationsCount, required this.onProfile, required this.onJoinByCode, required this.onScanQr, required this.onInvitations, required this.onMyRequests, required this.onAdminRequests, required this.onLogout});
  final bool isAdmin;
  final int adminRequestsCount;
  final int invitationsCount;
  final VoidCallback onProfile;
  final VoidCallback onJoinByCode;
  final VoidCallback onScanQr;
  final VoidCallback onInvitations;
  final VoidCallback onMyRequests;
  final VoidCallback onAdminRequests;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text.isKy ? 'Меню' : 'Меню', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        _MenuTile(icon: Icons.account_circle_outlined, title: text.isKy ? 'Профиль' : 'Профиль', onTap: () => _closeAndRun(context, onProfile)),
        _MenuTile(icon: Icons.key_rounded, title: text.joinByCode, onTap: () => _closeAndRun(context, onJoinByCode)),
        _MenuTile(icon: Icons.qr_code_scanner_rounded, title: text.isKy ? 'QR код сканерлөө' : 'Сканировать QR код', onTap: () => _closeAndRun(context, onScanQr)),
        _MenuTile(icon: Icons.mark_email_unread_outlined, title: text.invitations, badge: invitationsCount, onTap: () => _closeAndRun(context, onInvitations)),
        _MenuTile(icon: Icons.assignment_outlined, title: isAdmin ? text.myRequests : text.requestGroup, onTap: () => _closeAndRun(context, onMyRequests)),
        if (isAdmin) _MenuTile(icon: Icons.admin_panel_settings_outlined, title: text.adminRequests, badge: adminRequestsCount, onTap: () => _closeAndRun(context, onAdminRequests)),
        const SizedBox(height: 8),
        Divider(color: context.appColors.border),
        _MenuTile(icon: Icons.logout_rounded, title: text.logout, danger: true, onTap: () async { Navigator.pop(context); await onLogout(); }),
      ]),
    );
  }

  void _closeAndRun(BuildContext context, VoidCallback action) { Navigator.pop(context); action(); }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap, this.badge = 0, this.danger = false});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int badge;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = danger ? Colors.redAccent : MobileChatTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: colors.surfaceSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.border)),
          child: Row(children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: danger ? accent : colors.textStrong, fontWeight: FontWeight.w800))),
            if (badge > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: MobileChatTheme.primary, borderRadius: BorderRadius.circular(999)), child: Text('$badge', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ]),
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
  const GroupTile({super.key, required this.group, required this.onTap, required this.onLeave});
  final ChatGroup group;
  final VoidCallback onTap;
  final VoidCallback onLeave;
  bool get canLeave => group.myRole != 'owner';

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
              if (canLeave)
                PopupMenuButton<String>(
                  tooltip: text.isKy ? 'Топ менюсу' : 'Меню группы',
                  onSelected: (value) { if (value == 'leave') onLeave(); },
                  itemBuilder: (_) => [PopupMenuItem(value: 'leave', child: Row(children: [const Icon(Icons.logout_rounded, color: Colors.redAccent), const SizedBox(width: 10), Text(text.isKy ? 'Топтон чыгуу' : 'Выйти из группы', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))]))],
                )
              else
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

class CreateGroupSheet extends StatefulWidget { const CreateGroupSheet({super.key, required this.api}); final ApiClient api; @override State<CreateGroupSheet> createState() => _CreateGroupSheetState(); }

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
    } catch (e) { if (mounted) setState(() => error = e.toString()); } finally { if (mounted) setState(() => loading = false); }
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
      final group = await widget.api.joinByInviteCode(formatGroupInviteCode(codeController.text));
      if (mounted) Navigator.of(context).pop(group);
    } catch (e) { if (mounted) setState(() => error = e.toString()); } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text.joinByCode, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: codeController, textCapitalization: TextCapitalization.characters, inputFormatters: [GroupInviteCodeFormatter()], decoration: InputDecoration(labelText: text.isKy ? 'Чакыруу коду' : 'Код приглашения', hintText: 'AAA-666')),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? (text.isKy ? 'Кирүүдө...' : 'Входим...') : text.joinByCode)),
      ]),
    );
  }
}

String formatGroupInviteCode(String input) {
  final compact = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final shortened = compact.length > 6 ? compact.substring(0, 6) : compact;
  if (shortened.length > 3) return '${shortened.substring(0, 3)}-${shortened.substring(3)}';
  return shortened;
}

class GroupInviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatGroupInviteCode(newValue.text);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
