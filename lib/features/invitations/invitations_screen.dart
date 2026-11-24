import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/group_invitation.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

/// Accepts [invitation] and reports the result through a snack.
/// Returns true when the server accepted it.
Future<bool> acceptGroupInvitation(
  BuildContext context,
  ApiClient api,
  GroupInvitation invitation,
) async {
  final text = AppLanguageScope.textOf(context);
  try {
    await api.acceptInvitation(invitation.id);
    if (context.mounted) showAppSnack(context, text.invitationAccepted);
    return true;
  } catch (error) {
    if (context.mounted) {
      showAppSnack(context, localizedMessage(context, error.toString()));
    }
    return false;
  }
}

/// Declines [invitation] and reports the result through a snack.
/// Returns true when the server declined it.
Future<bool> declineGroupInvitation(
  BuildContext context,
  ApiClient api,
  GroupInvitation invitation,
) async {
  final text = AppLanguageScope.textOf(context);
  try {
    await api.declineInvitation(invitation.id);
    if (context.mounted) showAppSnack(context, text.invitationDeclined);
    return true;
  } catch (error) {
    if (context.mounted) {
      showAppSnack(context, localizedMessage(context, error.toString()));
    }
    return false;
  }
}

/// A pending group invitation with inline accept / decline actions.
class InvitationCard extends StatelessWidget {
  const InvitationCard({
    super.key,
    required this.invitation,
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  final GroupInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return KoomCard(
      margin: const EdgeInsets.only(bottom: KoomSpacing.md),
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
              const SizedBox(width: KoomSpacing.md),
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
                    const SizedBox(height: KoomSpacing.xs),
                    Text(
                      '${text.invitedBy}: ${invitation.senderName}',
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
                label: text.invitationNew,
                icon: Icons.mail_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: KoomSpacing.lg),
          KoomResponsiveActions(
            children: [
              OutlinedButton(
                key: ValueKey('invitation_decline_${invitation.id}'),
                onPressed: busy ? null : onDecline,
                child: Text(
                  text.declineInvitation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                key: ValueKey('invitation_accept_${invitation.id}'),
                onPressed: busy ? null : onAccept,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  text.acceptInvitation,
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
