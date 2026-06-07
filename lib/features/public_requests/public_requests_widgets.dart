import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../shared/ui_helpers.dart';

class EmptyPostsView extends StatelessWidget {
  const EmptyPostsView({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 120),
      const Icon(Icons.feed_outlined, size: 72, color: MobileChatTheme.primary),
      const SizedBox(height: 16),
      Text(text.noPostsYet, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(text.postsDescription, textAlign: TextAlign.center, style: TextStyle(color: context.appColors.textMuted)),
      const SizedBox(height: 18),
      Center(child: FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: Text(text.newPost))),
    ]);
  }
}

class GroupAccessSheet extends StatelessWidget {
  const GroupAccessSheet({super.key, required this.groupTitle, required this.code});
  final String groupTitle;
  final String code;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: colors.border)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(groupTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))),
            IconButton.filledTonal(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 12),
          SelectableText(code, textAlign: TextAlign.center, style: TextStyle(color: colors.textStrong, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Center(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: QrImageView(data: code, version: QrVersions.auto, size: 210, backgroundColor: Colors.white))),
          const SizedBox(height: 12),
          Text(text.isKy ? 'Бул кодду же QR кодду башка колдонуучуга бериңиз.' : 'Передайте этот код или QR другому пользователю.', textAlign: TextAlign.center, style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class InviteByPhoneSheet extends StatefulWidget {
  const InviteByPhoneSheet({super.key, required this.api, required this.group});
  final ApiClient api;
  final ChatGroup group;

  @override
  State<InviteByPhoneSheet> createState() => _InviteByPhoneSheetState();
}

class _InviteByPhoneSheetState extends State<InviteByPhoneSheet> {
  final phoneController = TextEditingController(text: '+996');
  bool loading = false;
  String? error;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.inviteUserByPhone(groupId: widget.group.id, mobile: phoneController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack(context, AppLanguageScope.textOf(context).isKy ? 'Чакыруу жөнөтүлдү.' : 'Приглашение отправлено.');
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
        Text(text.isKy ? 'Телефон менен чакыруу' : 'Пригласить по телефону', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: text.mobileNumber, hintText: '+996700123456', prefixIcon: const Icon(Icons.phone_iphone_rounded))),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? text.pleaseWait : (text.isKy ? 'Чакыруу жөнөтүү' : 'Отправить приглашение'))),
      ]),
    );
  }
}

class PublicRequestCard extends StatelessWidget {
  const PublicRequestCard({super.key, required this.request, required this.onTap, required this.onVote, this.canModerate = false, this.onStatus});
  final PublicRequest request;
  final VoidCallback onTap;
  final ValueChanged<String> onVote;
  final bool canModerate;
  final ValueChanged<String>? onStatus;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: request.interactionMode == 'discussion' ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.title, style: TextStyle(color: colors.textStrong, fontSize: 17, fontWeight: FontWeight.w800)),
              if (request.displayBody.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(request.displayBody, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 10),
              Text('${text.isKy ? 'Автор' : 'Автор'}: ${request.authorName}', style: TextStyle(color: colors.textMuted, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (request.interactionMode == 'discussion') FilledButton.tonal(onPressed: onTap, child: Text(text.read)),
                if (canModerate && onStatus != null) _StatusButton(onChanged: onStatus!),
                if (request.interactionMode != 'read_only') OutlinedButton.icon(onPressed: () => onVote('support'), icon: Icon(request.supportedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined), label: Text('${request.supportCount}')),
                if (request.interactionMode != 'read_only') OutlinedButton.icon(onPressed: () => onVote('oppose'), icon: Icon(request.opposedByMe ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined), label: Text('${request.opposeCount}')),
                Text('${request.commentCount} ${text.comments}', style: TextStyle(color: colors.textMuted)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'under_review', child: Text(text.statusUnderReview)),
        PopupMenuItem(value: 'resolved', child: Text(text.statusResolved)),
        PopupMenuItem(value: 'new', child: Text(text.statusNew)),
        PopupMenuItem(value: 'rejected', child: Text(text.statusRejected)),
      ],
      child: OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.sync_alt_rounded), label: Text(text.adminStatus)),
    );
  }
}

class CreatePublicRequestSheet extends StatefulWidget {
  const CreatePublicRequestSheet({super.key, required this.api, required this.group});
  final PublicRequestsApi api;
  final ChatGroup group;

  @override
  State<CreatePublicRequestSheet> createState() => _CreatePublicRequestSheetState();
}

class _CreatePublicRequestSheetState extends State<CreatePublicRequestSheet> {
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  String type = 'announcement';
  String interactionMode = 'read_only';
  bool loading = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.createRequest(groupId: widget.group.id, type: type, interactionMode: interactionMode, title: titleController.text.trim(), body: bodyController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
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
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(text.newPost, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(value: type, decoration: InputDecoration(labelText: text.postType), items: [DropdownMenuItem(value: 'announcement', child: Text(text.announcement)), DropdownMenuItem(value: 'suggestion', child: Text(text.suggestion)), DropdownMenuItem(value: 'complaint', child: Text(text.complaint)), DropdownMenuItem(value: 'requirement', child: Text(text.requirement)), DropdownMenuItem(value: 'problem', child: Text(text.problem)), DropdownMenuItem(value: 'idea', child: Text(text.idea))], onChanged: loading ? null : (value) => setState(() => type = value ?? 'announcement')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: interactionMode, decoration: InputDecoration(labelText: text.interactionMode), items: [DropdownMenuItem(value: 'read_only', child: Text(text.textOnly)), DropdownMenuItem(value: 'vote_only', child: Text(text.votingOnly)), DropdownMenuItem(value: 'discussion', child: Text(text.discussionWithComments))], onChanged: loading ? null : (value) => setState(() => interactionMode = value ?? 'read_only')),
          const SizedBox(height: 12),
          TextField(controller: titleController, decoration: InputDecoration(labelText: text.title)),
          const SizedBox(height: 12),
          TextField(controller: bodyController, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: text.description)),
          if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
          const SizedBox(height: 16),
          FilledButton(onPressed: loading ? null : submit, child: Text(loading ? text.publishing : text.publish)),
        ]),
      ),
    );
  }
}

class PublicRequestDetailsScreen extends StatelessWidget {
  const PublicRequestDetailsScreen({super.key, required this.api, required this.request, required this.canModerate, required this.currentUserId, this.onStatusChanged});
  final PublicRequestsApi api;
  final PublicRequest request;
  final bool canModerate;
  final String currentUserId;
  final ValueChanged<String>? onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.readPost), actions: const [AppSettingsButton()]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PublicRequestCard(request: request, onTap: () {}, onVote: (_) {}, canModerate: canModerate, onStatus: onStatusChanged),
        const SizedBox(height: 12),
        Text(request.displayBody.isEmpty ? request.title : request.displayBody),
      ]),
    );
  }
}
