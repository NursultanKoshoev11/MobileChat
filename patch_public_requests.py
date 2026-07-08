from pathlib import Path

# 1) PublicRequest.copyWith must be able to set myVote to null.
p = Path('lib/data/public_request.dart')
s = p.read_text(encoding='utf-8')
if 'const Object _publicRequestUnset = Object();' not in s:
    s = s.replace("import 'dart:convert';\n", "import 'dart:convert';\n\nconst Object _publicRequestUnset = Object();\n")
s = s.replace('''  PublicRequest copyWith({
    String? id,
    String? groupId,
    String? authorId,
    String? authorName,
    String? requestType,
    String? interactionMode,
    String? title,
    String? body,
    String? status,
    int? supportCount,
    int? opposeCount,
    int? commentCount,
    String? myVote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PublicRequest(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      requestType: requestType ?? this.requestType,
      interactionMode: interactionMode ?? this.interactionMode,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      supportCount: supportCount ?? this.supportCount,
      opposeCount: opposeCount ?? this.opposeCount,
      commentCount: commentCount ?? this.commentCount,
      myVote: myVote ?? this.myVote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
''', '''  PublicRequest copyWith({
    String? id,
    String? groupId,
    String? authorId,
    String? authorName,
    String? requestType,
    String? interactionMode,
    String? title,
    String? body,
    String? status,
    int? supportCount,
    int? opposeCount,
    int? commentCount,
    Object? myVote = _publicRequestUnset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PublicRequest(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      requestType: requestType ?? this.requestType,
      interactionMode: interactionMode ?? this.interactionMode,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      supportCount: supportCount ?? this.supportCount,
      opposeCount: opposeCount ?? this.opposeCount,
      commentCount: commentCount ?? this.commentCount,
      myVote: identical(myVote, _publicRequestUnset) ? this.myVote : myVote as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
''')
helper = '''
PublicRequest optimisticPublicRequestVote(PublicRequest request, String voteType) {
  final current = request.myVote;
  var support = request.supportCount;
  var oppose = request.opposeCount;
  String? nextVote;

  if (current == voteType) {
    if (voteType == 'support') support -= 1;
    if (voteType == 'oppose') oppose -= 1;
    nextVote = null;
  } else if (voteType == 'support') {
    support += 1;
    if (current == 'oppose') oppose -= 1;
    nextVote = 'support';
  } else {
    oppose += 1;
    if (current == 'support') support -= 1;
    nextVote = 'oppose';
  }

  if (support < 0) support = 0;
  if (oppose < 0) oppose = 0;
  return request.copyWith(
    supportCount: support,
    opposeCount: oppose,
    myVote: nextVote,
    updatedAt: DateTime.now(),
  );
}
'''
if 'optimisticPublicRequestVote(' not in s:
    s = s.replace('\n}\n\nclass PublicRequestContent {', '\n}\n' + helper + '\nclass PublicRequestContent {')
p.write_text(s, encoding='utf-8')

# 2) Public requests list: optimistic vote/status and no full refresh after returning from details.
p = Path('lib/features/public_requests/public_requests_screen.dart')
s = p.read_text(encoding='utf-8')
insert = '''
  PublicRequest currentRequest(PublicRequest fallback) {
    for (final request in cachedRequests) {
      if (request.id == fallback.id) return request;
    }
    return fallback;
  }

  void replaceRequest(PublicRequest next) {
    setRequests(cachedRequests
        .map((request) => request.id == next.id ? next : request)
        .toList());
  }
'''
if 'PublicRequest currentRequest(PublicRequest fallback)' not in s:
    s = s.replace('''  void setRequests(List<PublicRequest> requests) {
    if (!mounted) return;
    cachedRequests = requests;
    setState(() => requestsFuture = Future.value(requests));
  }
''', '''  void setRequests(List<PublicRequest> requests) {
    if (!mounted) return;
    cachedRequests = requests;
    setState(() => requestsFuture = Future.value(requests));
  }
''' + insert)
s = s.replace('''  Future<void> vote(PublicRequest request, String voteType) async {
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
    } catch (error) {
      if (mounted) showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }
''', '''  Future<void> vote(PublicRequest request, String voteType) async {
    final current = currentRequest(request);
    if (current.interactionMode == 'read_only') return;
    final previous = cachedRequests;
    final next = optimisticPublicRequestVote(current, voteType);
    replaceRequest(next);
    try {
      if (current.myVote == voteType) {
        await requestsApi.clearVote(current.id);
      } else if (voteType == 'support') {
        await requestsApi.support(current.id);
      } else {
        await requestsApi.oppose(current.id);
      }
      unawaited(refresh(silent: true).catchError((_) {}));
    } catch (error) {
      setRequests(previous);
      if (mounted) showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }
''')
s = s.replace('''  Future<void> updateStatus(PublicRequest request, String status) async {
    if (!canModerate) return;
    try {
      await requestsApi.updateStatus(requestId: request.id, status: status);
      await refresh();
      if (mounted) {
        final text = AppLanguageScope.textOf(context);
        showAppSnack(context, text.isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.');
      }
    } catch (error) {
      if (mounted) showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }
''', '''  Future<void> updateStatus(PublicRequest request, String status) async {
    if (!canModerate) return;
    final current = currentRequest(request);
    if (current.status == status) return;
    final previous = cachedRequests;
    final next = current.copyWith(status: status, updatedAt: DateTime.now());
    replaceRequest(next);
    try {
      await requestsApi.updateStatus(requestId: current.id, status: status);
      unawaited(refresh(silent: true).catchError((_) {}));
      if (mounted) {
        final text = AppLanguageScope.textOf(context);
        showAppSnack(context, text.isKy ? 'Статус жаңыртылды.' : 'Статус обновлён.');
      }
    } catch (error) {
      setRequests(previous);
      if (mounted) showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }
''')
s = s.replace('''          onStatusChanged:
              canModerate ? (status) => updateStatus(request, status) : null,
        ),
      ),
    );
    await refresh();
  }
''', '''          onStatusChanged:
              canModerate ? (status) => updateStatus(request, status) : null,
          onRequestChanged: replaceRequest,
        ),
      ),
    );
    unawaited(refresh(silent: true).catchError((_) {}));
  }
''')
p.write_text(s, encoding='utf-8')

# 3) Details screen: local request state, voting, non-jumpy comments, optimistic comment delete/add.
p = Path('lib/features/public_requests/public_requests_widgets.dart')
s = p.read_text(encoding='utf-8')
s = s.replace('''      required this.currentUserId,
      this.onStatusChanged});
''', '''      required this.currentUserId,
      this.onStatusChanged,
      this.onRequestChanged});
''')
s = s.replace('''  final ValueChanged<String>? onStatusChanged;
''', '''  final ValueChanged<String>? onStatusChanged;
  final ValueChanged<PublicRequest>? onRequestChanged;
''')
s = s.replace('''  final commentController = TextEditingController();
  late Future<List<PublicRequestComment>> commentsFuture;
''', '''  final commentController = TextEditingController();
  late PublicRequest request;
  late Future<List<PublicRequestComment>> commentsFuture;
''')
s = s.replace('''  void initState() {
    super.initState();
    commentsFuture = loadComments();
''', '''  void initState() {
    super.initState();
    request = widget.request;
    commentsFuture = loadComments();
''')
s = s.replace('widget.request.groupId', 'request.groupId')
s = s.replace('widget.request.id', 'request.id')
s = s.replace('widget.request.interactionMode', 'request.interactionMode')
if 'void setRequest(PublicRequest next)' not in s:
    s = s.replace('''  void setComments(List<PublicRequestComment> comments) {
    if (!mounted) return;
    cachedComments = comments;
    setState(() => commentsFuture = Future.value(comments));
  }
''', '''  void setComments(List<PublicRequestComment> comments) {
    if (!mounted) return;
    cachedComments = comments;
    setState(() => commentsFuture = Future.value(comments));
  }

  void setRequest(PublicRequest next) {
    if (!mounted) return;
    setState(() => request = next);
    widget.onRequestChanged?.call(next);
  }

  Future<void> vote(String voteType) async {
    if (request.interactionMode == 'read_only') return;
    final previous = request;
    final next = optimisticPublicRequestVote(request, voteType);
    setRequest(next);
    try {
      if (previous.myVote == voteType) {
        await widget.api.clearVote(previous.id);
      } else if (voteType == 'support') {
        await widget.api.support(previous.id);
      } else {
        await widget.api.oppose(previous.id);
      }
    } catch (e) {
      setRequest(previous);
      if (mounted) showAppSnack(context, localizedMessage(context, e.toString()));
    }
  }
''')
s = s.replace('''      await widget.api.addComment(requestId: request.id, body: body);
      commentController.clear();
      await refreshComments();
''', '''      final comment = await widget.api.addComment(requestId: request.id, body: body);
      commentController.clear();
      addRealtimeComment(comment);
      setRequest(request.copyWith(commentCount: request.commentCount + 1, updatedAt: DateTime.now()));
''')
s = s.replace('''      await refreshComments();
''', '''      unawaited(refreshComments(silent: true).catchError((_) {}));
''', 1)
s = s.replace('''  Future<void> deleteComment(PublicRequestComment comment) async {
    if (!widget.canModerate && comment.authorId != widget.currentUserId) return;
    try {
      await widget.api.deleteComment(comment.id);
      await refreshComments();
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString());
    }
  }
''', '''  Future<void> deleteComment(PublicRequestComment comment) async {
    if (!widget.canModerate && comment.authorId != widget.currentUserId) return;
    final previousComments = cachedComments;
    final previousRequest = request;
    removeRealtimeComment(comment.id);
    setRequest(request.copyWith(
      commentCount: request.commentCount - 1 < 0 ? 0 : request.commentCount - 1,
      updatedAt: DateTime.now(),
    ));
    try {
      await widget.api.deleteComment(comment.id);
    } catch (e) {
      setComments(previousComments);
      setRequest(previousRequest);
      if (mounted) showAppSnack(context, localizedMessage(context, e.toString()));
    }
  }
''')
s = s.replace('''                PublicRequestCard(
                  request: widget.request,
                  onTap: () {},
                  onVote: (_) {},
''', '''                PublicRequestCard(
                  request: request,
                  onTap: () {},
                  onVote: vote,
''')
# Use cached comments when available to avoid blank/flicker during background refresh.
s = s.replace('''            final comments = snapshot.data ?? const <PublicRequestComment>[];
''', '''            final comments = cachedComments.isNotEmpty
                ? cachedComments
                : snapshot.data ?? const <PublicRequestComment>[];
''')
p.write_text(s, encoding='utf-8')

# 4) Media create sheet: return local payload so new photo appears instantly even if backend normalizes later.
p = Path('lib/features/public_requests/public_request_media_widgets.dart')
s = p.read_text(encoding='utf-8')
s = s.replace('''      final request = await widget.api.createRequest(groupId: widget.groupId, type: type, interactionMode: interactionMode, title: titleController.text.trim(), body: payload);
      if (mounted) Navigator.of(context).pop(request);
''', '''      final request = await widget.api.createRequest(groupId: widget.groupId, type: type, interactionMode: interactionMode, title: titleController.text.trim(), body: payload);
      if (mounted) Navigator.of(context).pop(request.copyWith(body: payload));
''')
p.write_text(s, encoding='utf-8')

print('patched')
