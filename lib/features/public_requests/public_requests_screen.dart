import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../shared/ui_helpers.dart';

class PublicRequestsScreen extends StatefulWidget {
  const PublicRequestsScreen({super.key, required this.api, required this.user, required this.group});

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<PublicRequestsScreen> createState() => _PublicRequestsScreenState();
}

class _PublicRequestsScreenState extends State<PublicRequestsScreen> {
  late final PublicRequestsApi requestsApi;
  late Future<List<PublicRequest>> requestsFuture;
  String filter = 'newest';

  bool get canModerate => widget.group.myRole == 'owner' || widget.group.myRole == 'admin';

  @override
  void initState() {
    super.initState();
    requestsApi = PublicRequestsApi(baseUrl: widget.api.baseUrl, sessionStore: widget.api.sessionStore);
    requestsFuture = loadRequests();
  }

  Future<List<PublicRequest>> loadRequests() async {
    final requests = await requestsApi.listRequests(widget.group.id, mineOnly: filter == 'mine');
    final filtered = List<PublicRequest>.from(requests);
    if (filter == 'popular') {
      filtered.sort((a, b) => (b.supportCount - b.opposeCount).compareTo(a.supportCount - a.opposeCount));
    } else if (filter == 'resolved') {
      filtered
        ..retainWhere((request) => request.status == 'resolved' || request.status == 'accepted')
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  Future<void> refresh() async {
    setState(() => requestsFuture = loadRequests());
    await requestsFuture;
  }

  void changeFilter(String value) {
    if (filter == value) return;
    setState(() {
      filter = value;
      requestsFuture = loadRequests();
    });
  }

  Future<void> createRequest() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => CreatePublicRequestSheet(api: requestsApi, group: widget.group),
    );
    if (created == true) await refresh();
  }

  Future<void> vote(PublicRequest request, String voteType) async {
    try {
      if (request.myVote == voteType) {
        await requestsApi.clearVote(request.id);
      } else if (voteType == 'support') {
        await requestsApi.support(request.id);
      } else {
        await requestsApi.oppose(request.id);
      }
      await refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  Future<void> openDetails(PublicRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicRequestDetailsScreen(api: requestsApi, request: request, canModerate: canModerate),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createRequest,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New request'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'newest', label: Text('Newest')),
                ButtonSegment(value: 'popular', label: Text('Popular')),
                ButtonSegment(value: 'resolved', label: Text('Resolved')),
                ButtonSegment(value: 'mine', label: Text('Mine')),
              ],
              selected: {filter},
              onSelectionChanged: (value) => changeFilter(value.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: FutureBuilder<List<PublicRequest>>(
                future: requestsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) {
                    return ListView(padding: const EdgeInsets.all(16), children: [ErrorBanner(message: snapshot.error.toString())]);
                  }
                  final requests = snapshot.data ?? const [];
                  if (requests.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 120),
                        const Icon(Icons.campaign_outlined, size: 72, color: MobileChatTheme.primary),
                        const SizedBox(height: 16),
                        Text(emptyTitleForFilter(filter), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('People can publish ideas, complaints, problems, or requirements here.', textAlign: TextAlign.center, style: TextStyle(color: MobileChatTheme.textMuted)),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return PublicRequestCard(
                        request: request,
                        onTap: () => openDetails(request),
                        onSupport: () => vote(request, 'support'),
                        onOppose: () => vote(request, 'oppose'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String emptyTitleForFilter(String value) {
    if (value == 'popular') return 'No popular requests yet';
    if (value == 'resolved') return 'No resolved requests yet';
    if (value == 'mine') return 'You have not created requests yet';
    return 'No public requests yet';
  }
}

class PublicRequestCard extends StatelessWidget {
  const PublicRequestCard({super.key, required this.request, required this.onTap, required this.onSupport, required this.onOppose});

  final PublicRequest request;
  final VoidCallback onTap;
  final VoidCallback onSupport;
  final VoidCallback onOppose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
                      child: Text(request.requestType, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const Spacer(),
                    Text(request.status, style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(request.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(request.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MobileChatTheme.textStrong)),
                const SizedBox(height: 10),
                Text('By ${request.authorName}', style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onSupport,
                      icon: Icon(request.supportedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined),
                      label: Text('${request.supportCount}'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onOppose,
                      icon: Icon(request.opposedByMe ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined),
                      label: Text('${request.opposeCount}'),
                    ),
                    const Spacer(),
                    Text('${request.commentCount} comments', style: const TextStyle(color: MobileChatTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
  String type = 'suggestion';
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
      await widget.api.createRequest(groupId: widget.group.id, type: type, title: titleController.text.trim(), body: bodyController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New public request', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
              DropdownMenuItem(value: 'complaint', child: Text('Complaint')),
              DropdownMenuItem(value: 'requirement', child: Text('Requirement')),
              DropdownMenuItem(value: 'problem', child: Text('Problem')),
              DropdownMenuItem(value: 'idea', child: Text('Idea')),
            ],
            onChanged: loading ? null : (value) => setState(() => type = value ?? 'suggestion'),
          ),
          const SizedBox(height: 12),
          TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: bodyController, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Description')),
          if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
          const SizedBox(height: 16),
          FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Publishing...' : 'Publish request')),
        ],
      ),
    );
  }
}

class PublicRequestDetailsScreen extends StatefulWidget {
  const PublicRequestDetailsScreen({super.key, required this.api, required this.request, required this.canModerate});

  final PublicRequestsApi api;
  final PublicRequest request;
  final bool canModerate;

  @override
  State<PublicRequestDetailsScreen> createState() => _PublicRequestDetailsScreenState();
}

class _PublicRequestDetailsScreenState extends State<PublicRequestDetailsScreen> {
  final commentController = TextEditingController();
  late Future<List<PublicRequestComment>> commentsFuture;
  late String status;
  bool sending = false;
  bool updatingStatus = false;

  @override
  void initState() {
    super.initState();
    status = widget.request.status;
    commentsFuture = widget.api.listComments(widget.request.id);
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => commentsFuture = widget.api.listComments(widget.request.id));
    await commentsFuture;
  }

  Future<void> changeStatus(String value) async {
    setState(() => updatingStatus = true);
    try {
      await widget.api.updateStatus(requestId: widget.request.id, status: value);
      if (!mounted) return;
      setState(() => status = value);
      showAppSnack(context, 'Status updated.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => updatingStatus = false);
    }
  }

  Future<void> deleteComment(PublicRequestComment comment) async {
    try {
      await widget.api.deleteComment(comment.id);
      await refresh();
      if (!mounted) return;
      showAppSnack(context, 'Comment deleted.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
  }

  Future<void> sendComment() async {
    final body = commentController.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.api.addComment(requestId: widget.request.id, body: body);
      commentController.clear();
      await refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestWithLocalStatus = PublicRequest(
      id: widget.request.id,
      groupId: widget.request.groupId,
      authorId: widget.request.authorId,
      authorName: widget.request.authorName,
      requestType: widget.request.requestType,
      title: widget.request.title,
      body: widget.request.body,
      status: status,
      supportCount: widget.request.supportCount,
      opposeCount: widget.request.opposeCount,
      commentCount: widget.request.commentCount,
      myVote: widget.request.myVote,
      createdAt: widget.request.createdAt,
      updatedAt: widget.request.updatedAt,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PublicRequestCard(request: requestWithLocalStatus, onTap: () {}, onSupport: () {}, onOppose: () {}),
                  if (widget.canModerate) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Admin status'),
                      items: const [
                        DropdownMenuItem(value: 'new', child: Text('New')),
                        DropdownMenuItem(value: 'under_review', child: Text('Under review')),
                        DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                      ],
                      onChanged: updatingStatus ? null : (value) {
                        if (value != null && value != status) changeStatus(value);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Comments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  FutureBuilder<List<PublicRequestComment>>(
                    future: commentsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (snapshot.hasError) return ErrorBanner(message: snapshot.error.toString());
                      final comments = snapshot.data ?? const [];
                      if (comments.isEmpty) return const Text('No comments yet.', style: TextStyle(color: MobileChatTheme.textMuted));
                      return Column(
                        children: comments
                            .map((comment) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text(comment.body),
                                  trailing: widget.canModerate
                                      ? IconButton(
                                          tooltip: 'Delete comment',
                                          onPressed: () => deleteComment(comment),
                                          icon: const Icon(Icons.delete_outline_rounded),
                                        )
                                      : null,
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(child: TextField(controller: commentController, decoration: const InputDecoration(hintText: 'Add comment'))),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: sending ? null : sendComment, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
