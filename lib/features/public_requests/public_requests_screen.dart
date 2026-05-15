import 'package:flutter/material.dart';

import '../../app/localization.dart';
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

  Future<List<PublicRequest>> loadRequests({String? selectedFilter}) async {
    final activeFilter = selectedFilter ?? filter;
    final requests = await requestsApi.listRequests(widget.group.id, mineOnly: activeFilter == 'mine');
    final filtered = List<PublicRequest>.from(requests);
    if (activeFilter == 'popular') {
      filtered.sort((a, b) => (b.supportCount - b.opposeCount).compareTo(a.supportCount - a.opposeCount));
    } else if (activeFilter == 'resolved') {
      filtered
        ..retainWhere((request) => request.status == 'resolved' || request.status == 'accepted')
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  Future<void> refresh() async {
    final nextRequestsFuture = loadRequests();
    setState(() {
      requestsFuture = nextRequestsFuture;
    });
    await nextRequestsFuture;
  }

  void changeFilter(String value) {
    if (filter == value) return;
    final nextRequestsFuture = loadRequests(selectedFilter: value);
    setState(() {
      filter = value;
      requestsFuture = nextRequestsFuture;
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
    if (created == true) {
      await refresh();
      if (!mounted) return;
      showAppSnack(context, AppLanguageScope.textOf(context).postPublished);
    }
  }

  Future<void> vote(PublicRequest request, String voteType) async {
    if (request.interactionMode == 'read_only') return;
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
    if (request.interactionMode != 'discussion') return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicRequestDetailsScreen(api: requestsApi, request: request, canModerate: canModerate, currentUserId: widget.user.id),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.title), actions: const [LanguageMenuButton()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createRequest,
        icon: const Icon(Icons.add_rounded),
        label: Text(text.newPost),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'newest', label: Text(text.newest)),
                ButtonSegment(value: 'popular', label: Text(text.popular)),
                ButtonSegment(value: 'resolved', label: Text(text.resolved)),
                ButtonSegment(value: 'mine', label: Text(text.mine)),
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
                  if (snapshot.hasError) return ListView(padding: const EdgeInsets.all(16), children: [ErrorBanner(message: snapshot.error.toString())]);
                  final requests = snapshot.data ?? const [];
                  if (requests.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 120),
                        const Icon(Icons.feed_outlined, size: 72, color: MobileChatTheme.primary),
                        const SizedBox(height: 16),
                        Text(emptyTitleForFilter(filter, text), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(text.postsDescription, textAlign: TextAlign.center, style: const TextStyle(color: MobileChatTheme.textMuted)),
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
                        onRead: () => openDetails(request),
                        onSupport: request.interactionMode == 'read_only' ? null : () => vote(request, 'support'),
                        onOppose: request.interactionMode == 'read_only' ? null : () => vote(request, 'oppose'),
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

  String emptyTitleForFilter(String value, AppText text) {
    if (value == 'popular') return text.noPopularPosts;
    if (value == 'resolved') return text.noResolvedPosts;
    if (value == 'mine') return text.noMyPosts;
    return text.noPostsYet;
  }
}

class PublicRequestCard extends StatelessWidget {
  const PublicRequestCard({super.key, required this.request, required this.onRead, this.onSupport, this.onOppose, this.showReadAction = true});

  final PublicRequest request;
  final VoidCallback onRead;
  final VoidCallback? onSupport;
  final VoidCallback? onOppose;
  final bool showReadAction;

  bool get canVote => request.interactionMode != 'read_only';
  bool get canOpenDetails => showReadAction && request.interactionMode == 'discussion';

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: canOpenDetails ? onRead : null,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ChipLabel(text: translatedRequestType(request.requestType, text)),
                    const SizedBox(width: 8),
                    _ChipLabel(text: modeLabel(request.interactionMode, text)),
                    const Spacer(),
                    Text(translatedStatus(request.status, text), style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(request.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(request.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: MobileChatTheme.textStrong)),
                const SizedBox(height: 10),
                Text('${text.isKy ? 'Автор' : 'Автор'}: ${request.authorName}', style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (canOpenDetails) ...[
                      FilledButton.tonal(onPressed: onRead, child: Text(text.read)),
                      const SizedBox(width: 8),
                    ],
                    if (canVote) ...[
                      OutlinedButton.icon(onPressed: onSupport, icon: Icon(request.supportedByMe ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined), label: Text('${request.supportCount}')),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(onPressed: onOppose, icon: Icon(request.opposedByMe ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined), label: Text('${request.opposeCount}')),
                    ],
                    const Spacer(),
                    if (request.interactionMode == 'discussion') Text('${request.commentCount} ${text.comments}', style: const TextStyle(color: MobileChatTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String translatedRequestType(String value, AppText text) {
    if (value == 'announcement') return text.announcement;
    if (value == 'suggestion') return text.suggestion;
    if (value == 'complaint') return text.complaint;
    if (value == 'requirement') return text.requirement;
    if (value == 'problem') return text.problem;
    if (value == 'idea') return text.idea;
    return value;
  }

  String translatedStatus(String value, AppText text) {
    if (value == 'new') return text.statusNew;
    if (value == 'under_review') return text.statusUnderReview;
    if (value == 'accepted') return text.statusAccepted;
    if (value == 'rejected') return text.statusRejected;
    if (value == 'resolved') return text.statusResolved;
    return value;
  }

  String modeLabel(String value, AppText text) {
    if (value == 'read_only') return text.textOnly;
    if (value == 'vote_only') return text.votingOnly;
    return text.discussionWithComments;
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)),
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
      await widget.api.createRequest(
        groupId: widget.group.id,
        type: type,
        interactionMode: interactionMode,
        title: titleController.text.trim(),
        body: bodyController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(text.newPost, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: type,
              decoration: InputDecoration(labelText: text.postType),
              items: [
                DropdownMenuItem(value: 'announcement', child: Text(text.announcement)),
                DropdownMenuItem(value: 'suggestion', child: Text(text.suggestion)),
                DropdownMenuItem(value: 'complaint', child: Text(text.complaint)),
                DropdownMenuItem(value: 'requirement', child: Text(text.requirement)),
                DropdownMenuItem(value: 'problem', child: Text(text.problem)),
                DropdownMenuItem(value: 'idea', child: Text(text.idea)),
              ],
              onChanged: loading ? null : (value) => setState(() => type = value ?? 'announcement'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: interactionMode,
              decoration: InputDecoration(labelText: text.interactionMode),
              items: [
                DropdownMenuItem(value: 'read_only', child: Text(text.textOnly)),
                DropdownMenuItem(value: 'vote_only', child: Text(text.votingOnly)),
                DropdownMenuItem(value: 'discussion', child: Text(text.discussionWithComments)),
              ],
              onChanged: loading ? null : (value) => setState(() => interactionMode = value ?? 'read_only'),
            ),
            const SizedBox(height: 12),
            TextField(controller: titleController, decoration: InputDecoration(labelText: text.title)),
            const SizedBox(height: 12),
            TextField(controller: bodyController, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: text.description)),
            if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
            const SizedBox(height: 16),
            FilledButton(onPressed: loading ? null : submit, child: Text(loading ? text.publishing : text.publish)),
          ],
        ),
      ),
    );
  }
}

class PublicRequestDetailsScreen extends StatefulWidget {
  const PublicRequestDetailsScreen({super.key, required this.api, required this.request, required this.canModerate, required this.currentUserId});

  final PublicRequestsApi api;
  final PublicRequest request;
  final bool canModerate;
  final String currentUserId;

  @override
  State<PublicRequestDetailsScreen> createState() => _PublicRequestDetailsScreenState();
}

class _PublicRequestDetailsScreenState extends State<PublicRequestDetailsScreen> {
  final commentController = TextEditingController();
  late Future<List<PublicRequestComment>> commentsFuture;
  late String status;
  late int supportCount;
  late int opposeCount;
  String? myVote;
  bool sending = false;
  bool updatingStatus = false;

  bool get canComment => widget.request.interactionMode == 'discussion';
  bool get canVote => widget.request.interactionMode != 'read_only';

  @override
  void initState() {
    super.initState();
    status = widget.request.status;
    supportCount = widget.request.supportCount;
    opposeCount = widget.request.opposeCount;
    myVote = widget.request.myVote;
    commentsFuture = canComment ? widget.api.listComments(widget.request.id) : Future.value(const []);
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    if (!canComment) return;
    final nextCommentsFuture = widget.api.listComments(widget.request.id);
    setState(() {
      commentsFuture = nextCommentsFuture;
    });
    await nextCommentsFuture;
  }

  Future<void> vote(String value) async {
    if (!canVote) return;
    try {
      final previousVote = myVote;
      if (previousVote == value) {
        await widget.api.clearVote(widget.request.id);
        setState(() {
          if (value == 'support') supportCount--;
          if (value == 'oppose') opposeCount--;
          myVote = null;
        });
      } else {
        if (value == 'support') {
          await widget.api.support(widget.request.id);
        } else {
          await widget.api.oppose(widget.request.id);
        }
        setState(() {
          if (previousVote == 'support') supportCount--;
          if (previousVote == 'oppose') opposeCount--;
          if (value == 'support') supportCount++;
          if (value == 'oppose') opposeCount++;
          myVote = value;
        });
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString());
    }
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
    if (body.isEmpty || sending || !canComment) return;
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
    final text = AppLanguageScope.textOf(context);
    final requestWithLocalState = PublicRequest(
      id: widget.request.id,
      groupId: widget.request.groupId,
      authorId: widget.request.authorId,
      authorName: widget.request.authorName,
      requestType: widget.request.requestType,
      interactionMode: widget.request.interactionMode,
      title: widget.request.title,
      body: widget.request.body,
      status: status,
      supportCount: supportCount < 0 ? 0 : supportCount,
      opposeCount: opposeCount < 0 ? 0 : opposeCount,
      commentCount: widget.request.commentCount,
      myVote: myVote,
      createdAt: widget.request.createdAt,
      updatedAt: widget.request.updatedAt,
    );

    return Scaffold(
      appBar: AppBar(title: Text(text.readPost), actions: const [LanguageMenuButton()]),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PublicRequestCard(
                    request: requestWithLocalState,
                    onRead: () {},
                    onSupport: canVote ? () => vote('support') : null,
                    onOppose: canVote ? () => vote('oppose') : null,
                    showReadAction: false,
                  ),
                  if (widget.canModerate) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(labelText: text.adminStatus),
                      items: [
                        DropdownMenuItem(value: 'new', child: Text(text.statusNew)),
                        DropdownMenuItem(value: 'under_review', child: Text(text.statusUnderReview)),
                        DropdownMenuItem(value: 'accepted', child: Text(text.statusAccepted)),
                        DropdownMenuItem(value: 'rejected', child: Text(text.statusRejected)),
                        DropdownMenuItem(value: 'resolved', child: Text(text.statusResolved)),
                      ],
                      onChanged: updatingStatus ? null : (value) {
                        if (value != null && value != status) changeStatus(value);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (widget.request.interactionMode == 'read_only')
                    Text(text.readOnlyPost, style: const TextStyle(color: MobileChatTheme.textMuted))
                  else if (widget.request.interactionMode == 'vote_only')
                    Text(text.voteOnlyPost, style: const TextStyle(color: MobileChatTheme.textMuted))
                  else ...[
                    Text(text.comments, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    FutureBuilder<List<PublicRequestComment>>(
                      future: commentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError) return ErrorBanner(message: snapshot.error.toString());
                        final comments = snapshot.data ?? const [];
                        if (comments.isEmpty) return Text(text.noCommentsYet, style: const TextStyle(color: MobileChatTheme.textMuted));
                        return Column(
                          children: comments
                              .map((comment) => CommentBubble(
                                    comment: comment,
                                    mine: comment.authorId == widget.currentUserId,
                                    canDelete: widget.canModerate,
                                    onDelete: () => deleteComment(comment),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (canComment)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: commentController, decoration: InputDecoration(hintText: text.addComment))),
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

class CommentBubble extends StatelessWidget {
  const CommentBubble({super.key, required this.comment, required this.mine, required this.canDelete, required this.onDelete});

  final PublicRequestComment comment;
  final bool mine;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDDF3FF) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
          boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(comment.authorName, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: Text(comment.body, style: const TextStyle(color: MobileChatTheme.textStrong))),
                if (canDelete) ...[
                  const SizedBox(width: 4),
                  InkWell(onTap: onDelete, child: const Icon(Icons.delete_outline_rounded, size: 18, color: MobileChatTheme.textMuted)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(compactCommentTime(comment.createdAt.toLocal()), style: const TextStyle(color: MobileChatTheme.textMuted, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  String compactCommentTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
