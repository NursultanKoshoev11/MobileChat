import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/group_invitation.dart';
import '../../shared/ui_helpers.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  late Future<List<GroupInvitation>> invitationsFuture;

  @override
  void initState() {
    super.initState();
    invitationsFuture = widget.api.fetchInvitations();
  }

  Future<void> refresh() async {
    final nextFuture = widget.api.fetchInvitations();
    setState(() {
      invitationsFuture = nextFuture;
    });
    await nextFuture;
  }

  Future<void> accept(GroupInvitation invitation) async {
    final text = AppLanguageScope.textOf(context);
    try {
      await widget.api.acceptInvitation(invitation.id);
      await refresh();
      if (!mounted) return;
      showAppSnack(context, text.isKy ? 'Чакыруу кабыл алынды.' : 'Приглашение принято.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  Future<void> decline(GroupInvitation invitation) async {
    final text = AppLanguageScope.textOf(context);
    try {
      await widget.api.declineInvitation(invitation.id);
      await refresh();
      if (!mounted) return;
      showAppSnack(context, text.isKy ? 'Чакыруу четке кагылды.' : 'Приглашение отклонено.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.invitations), actions: const [LanguageMenuButton()]),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<GroupInvitation>>(
          future: invitationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [ErrorBanner(message: snapshot.error.toString())],
              );
            }
            final invitations = snapshot.data ?? const [];
            if (invitations.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  const Icon(Icons.mark_email_unread_outlined, size: 72, color: MobileChatTheme.primary),
                  const SizedBox(height: 16),
                  Text(text.isKy ? 'Чакыруулар жок' : 'Приглашений нет', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 8),
                  Text(text.isKy ? 'Топко чакыруулар ушул жерде чыгат.' : 'Ожидающие приглашения в группы будут здесь.', textAlign: TextAlign.center, style: const TextStyle(color: MobileChatTheme.textMuted)),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: invitations.length,
              itemBuilder: (context, index) {
                final invitation = invitations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: MobileChatTheme.primary,
                                child: Text(avatarText(invitation.groupTitle), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(invitation.groupTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    Text('${text.isKy ? 'Чакырган' : 'Пригласил'}: ${invitation.senderName}', style: const TextStyle(color: MobileChatTheme.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => decline(invitation),
                                  child: Text(text.isKy ? 'Баш тартуу' : 'Отклонить'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => accept(invitation),
                                  child: Text(text.isKy ? 'Кабыл алуу' : 'Принять'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
