import 'package:flutter/material.dart';

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
    setState(() => invitationsFuture = widget.api.fetchInvitations());
    await invitationsFuture;
  }

  Future<void> accept(GroupInvitation invitation) async {
    try {
      await widget.api.acceptInvitation(invitation.id);
      await refresh();
      if (!mounted) return;
      showAppSnack(context, 'Invitation accepted.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  Future<void> decline(GroupInvitation invitation) async {
    try {
      await widget.api.declineInvitation(invitation.id);
      await refresh();
      if (!mounted) return;
      showAppSnack(context, 'Invitation declined.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
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
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.mark_email_unread_outlined, size: 72, color: MobileChatTheme.primary),
                  SizedBox(height: 16),
                  Text('No invitations', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  SizedBox(height: 8),
                  Text('Pending group invitations will appear here.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),
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
                                    Text('Invited by ${invitation.senderName}', style: const TextStyle(color: MobileChatTheme.textMuted)),
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
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => accept(invitation),
                                  child: const Text('Accept'),
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
