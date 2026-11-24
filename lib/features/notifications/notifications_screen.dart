import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/group_invitation.dart';
import '../../data/models.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';
import '../invitations/invitations_screen.dart';
import 'notifications_controller.dart';

/// Notifications tab of the root shell.
///
/// Built only from endpoints that already exist: pending invitations (accepted
/// or declined inline) and the per-group unread post counter, shown as
/// `new posts in <group>` entries that open the group.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.api,
    required this.controller,
    required this.onOpenGroup,
  });

  final ApiClient api;
  final KoomNotificationsController controller;
  final Future<void> Function(ChatGroup group) onOpenGroup;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotificationsFilter { all, invitations }

class _NotificationsScreenState extends State<NotificationsScreen> {
  _NotificationsFilter _filter = _NotificationsFilter.all;
  final Set<String> _busyInvitations = <String>{};

  Future<void> _accept(GroupInvitation invitation) async {
    if (!_busyInvitations.add(invitation.id)) return;
    setState(() {});
    final accepted =
        await acceptGroupInvitation(context, widget.api, invitation);
    if (accepted) {
      widget.controller.removeInvitation(invitation.id);
      // Joining a group changes the group list behind the unread entries.
      await widget.controller.refresh();
    }
    if (!mounted) return;
    setState(() => _busyInvitations.remove(invitation.id));
  }

  Future<void> _decline(GroupInvitation invitation) async {
    if (!_busyInvitations.add(invitation.id)) return;
    setState(() {});
    final declined =
        await declineGroupInvitation(context, widget.api, invitation);
    if (declined) widget.controller.removeInvitation(invitation.id);
    if (!mounted) return;
    setState(() => _busyInvitations.remove(invitation.id));
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      key: const ValueKey('notifications_screen'),
      appBar: AppBar(
        title: Text(text.notifications),
        actions: const [AppSettingsButton(), SizedBox(width: KoomSpacing.md)],
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: widget.controller.refresh,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => _buildList(context, text),
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, AppText text) {
    final controller = widget.controller;
    final invitations = controller.invitations;
    final showUnread = _filter == _NotificationsFilter.all;
    final unreadGroups = showUnread ? controller.unreadGroups : const <ChatGroup>[];
    final error = controller.error;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          KoomSpacing.xs,
          KoomSpacing.sm,
          KoomSpacing.xs,
          KoomSpacing.lg,
        ),
        child: _FilterSelector(
          value: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
      ),
    ];

    if (controller.loading && invitations.isEmpty && unreadGroups.isEmpty) {
      children.add(const KoomSkeletonList(
        itemCount: 4,
        itemHeight: 104,
        radius: KoomRadii.lg,
      ));
    } else if (error != null && invitations.isEmpty) {
      children.add(ErrorBanner(
        message: localizedMessage(context, error.toString()),
      ));
    } else if (invitations.isEmpty && unreadGroups.isEmpty) {
      children.add(KoomCard(
        showShadow: false,
        child: KoomEmptyState(
          icon: _filter == _NotificationsFilter.invitations
              ? Icons.mark_email_unread_outlined
              : Icons.notifications_none_rounded,
          title: _filter == _NotificationsFilter.invitations
              ? text.noInvitationsTitle
              : text.noNotificationsTitle,
          message: _filter == _NotificationsFilter.invitations
              ? text.noInvitationsMessage
              : text.noNotificationsMessage,
        ),
      ));
    } else {
      if (invitations.isNotEmpty) {
        children
          ..add(Padding(
            padding: const EdgeInsets.fromLTRB(
              KoomSpacing.xs,
              0,
              KoomSpacing.xs,
              KoomSpacing.md,
            ),
            child: KoomSectionTitle(
              title: text.invitations,
              subtitle: text.invitationsCountLabel(invitations.length),
            ),
          ))
          ..addAll(invitations.map(
            (invitation) => InvitationCard(
              key: ValueKey('notification_invitation_${invitation.id}'),
              invitation: invitation,
              busy: _busyInvitations.contains(invitation.id),
              onAccept: () => _accept(invitation),
              onDecline: () => _decline(invitation),
            ),
          ));
      }
      if (unreadGroups.isNotEmpty) {
        children
          ..add(Padding(
            padding: EdgeInsets.fromLTRB(
              KoomSpacing.xs,
              invitations.isEmpty ? 0 : KoomSpacing.sm,
              KoomSpacing.xs,
              KoomSpacing.md,
            ),
            child: KoomSectionTitle(
              title: text.newPostsSectionTitle,
              subtitle: text.newPostsCount(controller.unreadPostCount),
            ),
          ))
          ..addAll(unreadGroups.map(
            (group) => _UnreadPostsCard(
              key: ValueKey('notification_unread_${group.id}'),
              group: group,
              onTap: () => widget.onOpenGroup(group),
            ),
          ));
      }
    }

    return ListView(
      key: const ValueKey('notifications_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        KoomSpacing.lg,
        KoomSpacing.sm,
        KoomSpacing.lg,
        KoomSpacing.xxl,
      ),
      children: children,
    );
  }
}

class _FilterSelector extends StatelessWidget {
  const _FilterSelector({required this.value, required this.onChanged});

  final _NotificationsFilter value;
  final ValueChanged<_NotificationsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_NotificationsFilter>(
        key: const ValueKey('notifications_filter'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment<_NotificationsFilter>(
            value: _NotificationsFilter.all,
            label: Text(
              text.allFilter,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ButtonSegment<_NotificationsFilter>(
            value: _NotificationsFilter.invitations,
            label: Text(
              text.invitations,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        selected: <_NotificationsFilter>{value},
        onSelectionChanged: (values) => onChanged(values.first),
      ),
    );
  }
}

class _UnreadPostsCard extends StatelessWidget {
  const _UnreadPostsCard({super.key, required this.group, required this.onTap});

  final ChatGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return KoomCard(
      margin: const EdgeInsets.only(bottom: KoomSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          KoomAvatar(
            label: group.title,
            radius: 23,
            icon: Icons.feed_rounded,
            imageBytes: group.avatarBytes,
          ),
          const SizedBox(width: KoomSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.newPostsInGroup(group.title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: KoomSpacing.xs),
                Text(
                  text.newPostsCount(group.unreadPublicRequestCount),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KoomSpacing.sm),
          Badge(label: Text('${group.unreadPublicRequestCount}')),
          Icon(Icons.chevron_right_rounded, color: colors.textMuted),
        ],
      ),
    );
  }
}
