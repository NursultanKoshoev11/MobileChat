import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';
import 'group_creation_requests_screen.dart';

class AdminGroupCreationRequestsScreen extends StatefulWidget {
  const AdminGroupCreationRequestsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AdminGroupCreationRequestsScreen> createState() => _AdminGroupCreationRequestsScreenState();
}

class _AdminGroupCreationRequestsScreenState extends State<AdminGroupCreationRequestsScreen> {
  late Future<List<GroupCreationRequest>> future;
  String status = 'pending';

  @override
  void initState() {
    super.initState();
    future = widget.api.fetchAdminGroupCreationRequests(status: status);
  }

  Future<void> refresh() async {
    final nextFuture = widget.api.fetchAdminGroupCreationRequests(status: status);
    setState(() {
      future = nextFuture;
    });
    await nextFuture;
  }

  Future<void> changeStatus(String value) async {
    final nextFuture = widget.api.fetchAdminGroupCreationRequests(status: value);
    setState(() {
      status = value;
      future = nextFuture;
    });
    await nextFuture;
  }

  Future<void> review(GroupCreationRequest request, String action) async {
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => _AdminCommentDialog(action: action),
    );
    if (comment == null) return;
    try {
      if (action == 'approve') {
        await widget.api.approveGroupCreationRequest(request.id, adminComment: comment);
      } else if (action == 'reject') {
        await widget.api.rejectGroupCreationRequest(request.id, adminComment: comment);
      } else {
        await widget.api.needMoreInfoForGroupCreationRequest(request.id, adminComment: comment);
      }
      await refresh();
      if (mounted) showAppSnack(context, 'Request updated.');
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin requests')),
      body: Column(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'needs_more_info', label: Text('Need info')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ButtonSegment(value: '', label: Text('All')),
            ],
            selected: {status},
            onSelectionChanged: (value) {
              changeStatus(value.first);
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: refresh,
            child: FutureBuilder<List<GroupCreationRequest>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(24), children: [ErrorBanner(message: snapshot.error.toString())]);
                final requests = snapshot.data ?? const [];
                if (requests.isEmpty) {
                  return ListView(padding: const EdgeInsets.all(24), children: const [
                    SizedBox(height: 120),
                    Icon(Icons.admin_panel_settings_outlined, size: 72, color: MobileChatTheme.primary),
                    SizedBox(height: 16),
                    Text('No requests found', textAlign: TextAlign.center),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final canReview = request.status == 'pending' || request.status == 'needs_more_info';
                    return GroupCreationRequestCard(
                      request: request,
                      actions: canReview
                          ? Wrap(spacing: 8, runSpacing: 8, children: [
                              FilledButton.icon(onPressed: () => review(request, 'approve'), icon: const Icon(Icons.check_rounded), label: const Text('Approve')),
                              OutlinedButton.icon(onPressed: () => review(request, 'need_info'), icon: const Icon(Icons.info_outline_rounded), label: const Text('Need info')),
                              OutlinedButton.icon(onPressed: () => review(request, 'reject'), icon: const Icon(Icons.close_rounded), label: const Text('Reject')),
                            ])
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _AdminCommentDialog extends StatefulWidget {
  const _AdminCommentDialog({required this.action});

  final String action;

  @override
  State<_AdminCommentDialog> createState() => _AdminCommentDialogState();
}

class _AdminCommentDialogState extends State<_AdminCommentDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get title {
    switch (widget.action) {
      case 'approve': return 'Approve request';
      case 'reject': return 'Reject request';
      default: return 'Request more info';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Admin comment')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
      ],
    );
  }
}
