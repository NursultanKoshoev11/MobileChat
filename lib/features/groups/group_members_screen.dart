import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../data/models.dart';
import '../../data/public_requests_api.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

/// Group members list. The owner and admins can remove the members the
/// server allows them to remove (see [canRemoveGroupMember]).
class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({
    super.key,
    required this.api,
    required this.group,
    required this.currentUserId,
  });

  final PublicRequestsApi api;
  final ChatGroup group;
  final String currentUserId;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  late Future<List<GroupMember>> membersFuture;
  final Set<String> _removing = <String>{};

  String? get _myRole {
    if (widget.group.ownerId.isNotEmpty &&
        widget.group.ownerId == widget.currentUserId) {
      return 'owner';
    }
    return widget.group.myRole;
  }

  @override
  void initState() {
    super.initState();
    membersFuture = widget.api.listGroupMembers(widget.group.id);
  }

  Future<void> _reload() async {
    final future = widget.api.listGroupMembers(widget.group.id);
    setState(() => membersFuture = future);
    try {
      await future;
    } catch (_) {}
  }

  String _roleLabel(AppText text, String role) => switch (role) {
        'owner' => text.isKy ? 'Ээси' : 'Владелец',
        'admin' => text.isKy ? 'Админ' : 'Администратор',
        _ => text.isKy ? 'Катышуучу' : 'Участник',
      };

  Future<void> _remove(GroupMember member) async {
    final text = AppLanguageScope.textOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.removeFromGroupConfirmTitle),
        content: Text(text.removeFromGroupConfirmBody(member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm_remove_member'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(text.removeFromGroup),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing.add(member.userId));
    try {
      await widget.api.removeGroupMember(
        groupId: widget.group.id,
        userId: member.userId,
      );
      if (!mounted) return;
      showAppSnack(context, text.memberRemoved);
      await _reload();
    } catch (error) {
      if (mounted) {
        showAppSnack(context, localizedMessage(context, error.toString()));
      }
    } finally {
      if (mounted) setState(() => _removing.remove(member.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.groupMembers)),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<GroupMember>>(
            future: membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16),
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
              final members = snapshot.data ?? const <GroupMember>[];
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: members.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final removable = canRemoveGroupMember(
                    myRole: _myRole,
                    myUserId: widget.currentUserId,
                    member: member,
                  );
                  final busy = _removing.contains(member.userId);
                  return ListTile(
                    key: ValueKey('group_member_${member.userId}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: KoomAvatar(label: member.displayName, radius: 20),
                    title: Text(
                      member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_roleLabel(text, member.role)),
                    trailing: !removable
                        ? null
                        : busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : PopupMenuButton<String>(
                                key: ValueKey(
                                  'member_actions_${member.userId}',
                                ),
                                tooltip: text.isKy ? 'Аракеттер' : 'Действия',
                                onSelected: (_) => _remove(member),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_remove_outlined,
                                          size: 19,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            text.removeFromGroup,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
