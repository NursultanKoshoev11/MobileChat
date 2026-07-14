import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/group_invitation.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  late Future<List<GroupInvitation>> invitationsFuture;
  List<GroupInvitation> cachedInvitations = const <GroupInvitation>[];
  bool invitationsLoaded = false;

  @override
  void initState() {
    super.initState();
    invitationsFuture = loadInvitations();
  }

  Future<List<GroupInvitation>> loadInvitations() async {
    final invitations = await widget.api.fetchInvitations();
    cachedInvitations = invitations;
    invitationsLoaded = true;
    return invitations;
  }

  void removeInvitation(String invitationId) {
    cachedInvitations = cachedInvitations.where((invitation) => invitation.id != invitationId).toList();
    invitationsLoaded = true;
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    final nextFuture = loadInvitations();
    setState(() => invitationsFuture = nextFuture);
    await nextFuture;
  }

  Future<void> accept(GroupInvitation invitation) async {
    final text = AppLanguageScope.textOf(context);
    try {
      await widget.api.acceptInvitation(invitation.id);
      removeInvitation(invitation.id);
      if (!mounted) return;
      showAppSnack(
        context,
        text.isKy ? 'Чакыруу кабыл алынды.' : 'Приглашение принято.',
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  Future<void> decline(GroupInvitation invitation) async {
    final text = AppLanguageScope.textOf(context);
    try {
      await widget.api.declineInvitation(invitation.id);
      removeInvitation(invitation.id);
      if (!mounted) return;
      showAppSnack(
        context,
        text.isKy ? 'Чакыруу четке кагылды.' : 'Приглашение отклонено.',
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.invitations),
        actions: const [LanguageMenuButton(), SizedBox(width: 8)],
      ),
      body: KoomPageBackground(
        child: RefreshIndicator(
          onRefresh: refresh,
          child: FutureBuilder<List<GroupInvitation>>(
            future: invitationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !invitationsLoaded) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 210),
                    Center(child: CircularProgressIndicator()),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [ErrorBanner(message: snapshot.error.toString())],
                );
              }
              final invitations = invitationsLoaded
                  ? cachedInvitations
                  : snapshot.data ?? const <GroupInvitation>[];
              if (invitations.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    KoomCard(
                      showShadow: false,
                      child: KoomEmptyState(
                        icon: Icons.mark_email_unread_outlined,
                        title: text.isKy ? 'Чакыруулар жок' : 'Приглашений нет',
                        message: text.isKy
                            ? 'Топко чакыруулар ушул жерде чыгат.'
                            : 'Ожидающие приглашения в группы появятся здесь.',
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: invitations.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 14),
                      child: KoomSectionTitle(
                        title: text.invitations,
                        subtitle: text.isKy
                            ? '${invitations.length} жаңы чакыруу'
                            : '${invitations.length} новых приглашений',
                      ),
                    );
                  }
                  final invitation = invitations[index - 1];
                  return _InvitationCard(
                    invitation: invitation,
                    onAccept: () => accept(invitation),
                    onDecline: () => decline(invitation),
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

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
  });

  final GroupInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return KoomCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KoomAvatar(
                label: invitation.groupTitle,
                radius: 25,
                icon: Icons.groups_2_rounded,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.groupTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${text.isKy ? 'Чакырган' : 'Пригласил'}: ${invitation.senderName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              KoomStatusPill(
                label: text.isKy ? 'Жаңы' : 'Новое',
                icon: Icons.mail_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 17),
          KoomResponsiveActions(
            children: [
              OutlinedButton(
                onPressed: onDecline,
                child: Text(
                  text.isKy ? 'Баш тартуу' : 'Отклонить',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  text.isKy ? 'Кабыл алуу' : 'Принять',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
