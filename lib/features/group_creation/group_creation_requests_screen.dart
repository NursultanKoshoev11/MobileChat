import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';

class GroupCreationRequestsScreen extends StatefulWidget {
  const GroupCreationRequestsScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final UserProfile user;

  @override
  State<GroupCreationRequestsScreen> createState() => _GroupCreationRequestsScreenState();
}

class _GroupCreationRequestsScreenState extends State<GroupCreationRequestsScreen> {
  late Future<List<GroupCreationRequest>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.fetchMyGroupCreationRequests();
  }

  Future<void> refresh() async {
    setState(() => future = widget.api.fetchMyGroupCreationRequests());
    await future;
  }

  Future<void> createRequest() async {
    final created = await showModalBottomSheet<GroupCreationRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => CreateGroupRequestSheet(api: widget.api, user: widget.user),
    );
    if (created != null) {
      await refresh();
      if (mounted) showAppSnack(context, 'Request sent to platform admins.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Group requests')),
      floatingActionButton: FloatingActionButton.extended(onPressed: createRequest, icon: const Icon(Icons.verified_user_outlined), label: const Text('Request group')),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<GroupCreationRequest>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(24), children: [ErrorBanner(message: snapshot.error.toString())]);
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return ListView(padding: const EdgeInsets.all(24), children: [
                const SizedBox(height: 120),
                const Icon(Icons.assignment_outlined, size: 72, color: MobileChatTheme.primary),
                const SizedBox(height: 16),
                Text('No requests yet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Send a request if you represent an organization and need an official group.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),
                const SizedBox(height: 20),
                Center(child: FilledButton(onPressed: createRequest, child: const Text('Request group'))),
              ]);
            }
            return ListView.builder(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), itemCount: requests.length, itemBuilder: (context, index) => GroupCreationRequestCard(request: requests[index]));
          },
        ),
      ),
    );
  }
}

class GroupCreationRequestCard extends StatelessWidget {
  const GroupCreationRequestCard({super.key, required this.request, this.actions});

  final GroupCreationRequest request;
  final Widget? actions;

  Color get statusColor {
    switch (request.status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.redAccent;
      case 'needs_more_info': return Colors.orange;
      default: return MobileChatTheme.primary;
    }
  }

  String get statusText {
    switch (request.status) {
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'needs_more_info': return 'Need more info';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)), child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12))),
              const Spacer(),
              Text(request.createdAt?.toLocal().toString().split('.').first ?? '', style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Text(request.groupTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text(request.organizationName, style: const TextStyle(color: MobileChatTheme.textMuted)),
            const SizedBox(height: 8),
            Text('${request.applicantName} · ${request.position}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (request.adminComment.isNotEmpty) ...[const SizedBox(height: 8), Text('Admin comment: ${request.adminComment}', style: const TextStyle(color: MobileChatTheme.textMuted))],
            if (actions != null) ...[const SizedBox(height: 12), actions!],
          ]),
        ),
      ),
    );
  }
}

class CreateGroupRequestSheet extends StatefulWidget {
  const CreateGroupRequestSheet({super.key, required this.api, required this.user});

  final ApiClient api;
  final UserProfile user;

  @override
  State<CreateGroupRequestSheet> createState() => _CreateGroupRequestSheetState();
}

class _CreateGroupRequestSheetState extends State<CreateGroupRequestSheet> {
  final applicant = TextEditingController();
  final position = TextEditingController();
  final organization = TextEditingController();
  final organizationType = TextEditingController(text: 'Government organization');
  final region = TextEditingController();
  final officialPhone = TextEditingController();
  final officialEmail = TextEditingController();
  final website = TextEditingController();
  final title = TextEditingController();
  final description = TextEditingController();
  final reason = TextEditingController();
  final documents = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    applicant.text = widget.user.displayName;
    officialPhone.text = widget.user.mobile ?? '';
  }

  @override
  void dispose() {
    applicant.dispose(); position.dispose(); organization.dispose(); organizationType.dispose(); region.dispose(); officialPhone.dispose(); officialEmail.dispose(); website.dispose(); title.dispose(); description.dispose(); reason.dispose(); documents.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      final created = await widget.api.createGroupCreationRequest(applicantName: applicant.text.trim(), position: position.text.trim(), organizationName: organization.text.trim(), organizationType: organizationType.text.trim(), region: region.text.trim(), officialPhone: officialPhone.text.trim(), officialEmail: officialEmail.text.trim(), website: website.text.trim(), groupTitle: title.text.trim(), groupDescription: description.text.trim(), reason: reason.text.trim(), documents: documents.text.trim());
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Request official group', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _field(applicant, 'Full name'), _field(position, 'Position'), _field(organization, 'Organization name'), _field(organizationType, 'Organization type'), _field(region, 'City / region'), _field(officialPhone, 'Official phone'), _field(officialEmail, 'Official email'), _field(website, 'Website'), _field(title, 'Group title'), _field(description, 'Group description', lines: 2), _field(reason, 'Reason', lines: 3), _field(documents, 'Documents / proof', lines: 3),
          if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
          const SizedBox(height: 16),
          FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Sending...' : 'Send request')),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {int lines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: controller, minLines: lines, maxLines: lines, decoration: InputDecoration(labelText: label)));
  }
}
