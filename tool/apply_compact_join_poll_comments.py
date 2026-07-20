from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


root = Path(__file__).resolve().parents[1]

group_sheets = root / "lib/features/groups/group_sheets.dart"
replace_once(
    group_sheets,
    r'''    return KoomSheetFrame(
      title: text.joinByCode,
      subtitle: text.isKy
          ? 'Коомчулуктун чакыруу кодун жазыңыз'
          : 'Введите код приглашения сообщества',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
            inputFormatters: [GroupInviteCodeFormatter()],
            decoration: InputDecoration(
              labelText: text.isKy ? 'Чакыруу коду' : 'Код приглашения',
              hintText: 'AAA-666',
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: error!),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: loading ? null : submit,
            icon: const Icon(Icons.login_rounded),
            label: Text(
              loading
                  ? (text.isKy ? 'Кирүүдө...' : 'Входим...')
                  : text.joinByCode,
            ),
          ),
        ],
      ),
    );''',
    r'''    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Material(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.key_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.joinByCode,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            text.isKy
                                ? 'Чакыруу кодун жазыңыз'
                                : 'Введите код приглашения',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!loading) submit();
                  },
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                  inputFormatters: [GroupInviteCodeFormatter()],
                  decoration: InputDecoration(
                    labelText: text.isKy ? 'Чакыруу коду' : 'Код приглашения',
                    hintText: 'AAA-666',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: error!),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: loading ? null : submit,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    loading
                        ? (text.isKy ? 'Кирүүдө...' : 'Входим...')
                        : text.joinByCode,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );''',
    "compact join sheet",
)

media_screens = root / "lib/features/public_requests/public_request_media_screens.dart"
replace_once(
    media_screens,
    r'''            const SizedBox(height: 13),
            Divider(color: colors.border),
            const SizedBox(height: 5),
            Row(
              children: [
                if (request.interactionMode != 'read_only')
                  Expanded(
                    child: _RequestActionButton(
                      key: ValueKey(
                        'public_request_support_${request.id}',
                      ),
                      icon: request.supportedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '${request.supportCount}',
                      selected: request.supportedByMe,
                      onTap: () => onVote('support'),
                    ),
                  ),
                if (request.interactionMode != 'read_only')
                  Expanded(
                    child: _RequestActionButton(
                      key: ValueKey(
                        'public_request_oppose_${request.id}',
                      ),
                      icon: request.opposedByMe
                          ? Icons.thumb_down_alt_rounded
                          : Icons.thumb_down_alt_outlined,
                      label: '${request.opposeCount}',
                      selected: request.opposedByMe,
                      onTap: () => onVote('oppose'),
                    ),
                  ),
                if (request.interactionMode == 'discussion' && showOpenAction)
                  Expanded(
                    child: _RequestActionButton(
                      key: ValueKey('public_request_read_${request.id}'),
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '${request.commentCount}',
                      onTap: onTap,
                    ),
                  ),
                if (request.interactionMode == 'read_only') ...[
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _interactionModeLabel(text, request.interactionMode),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                ],
                Icon(
                  Icons.ios_share_rounded,
                  size: 19,
                  color: colors.textMuted,
                ),
              ],
            ),''',
    r'''            if (request.interactionMode != 'read_only') ...[
              const SizedBox(height: 14),
              _TelegramPoll(
                request: request,
                onVote: onVote,
              ),
            ] else ...[
              const SizedBox(height: 13),
              Divider(color: colors.border),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _interactionModeLabel(text, request.interactionMode),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            if (request.interactionMode == 'discussion' && showOpenAction) ...[
              const SizedBox(height: 10),
              Material(
                color: colors.page,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  key: ValueKey('public_request_read_${request.id}'),
                  borderRadius: BorderRadius.circular(15),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 19,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            text.comments,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${request.commentCount}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],''',
    "telegram poll placement",
)

replace_once(
    media_screens,
    r'''class _RequestActionButton extends StatelessWidget {
  const _RequestActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground =
        selected ? Theme.of(context).colorScheme.primary : colors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}''',
    r'''class _TelegramPoll extends StatelessWidget {
  const _TelegramPoll({required this.request, required this.onVote});

  final PublicRequest request;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final totalVotes = request.supportCount + request.opposeCount;
    final supportPercent = totalVotes == 0
        ? 0
        : ((request.supportCount / totalVotes) * 100).round();
    final opposePercent = totalVotes == 0 ? 0 : 100 - supportPercent;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: colors.page,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.poll_outlined,
                size: 19,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text.isKy ? 'Добуш берүү' : 'Голосование',
                  style: TextStyle(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                text.isKy
                    ? '$totalVotes добуш'
                    : '$totalVotes голосов',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TelegramPollOption(
            key: ValueKey('public_request_support_${request.id}'),
            label: text.isKy ? 'Колдойм' : 'Поддерживаю',
            votes: request.supportCount,
            percentage: supportPercent,
            selected: request.supportedByMe,
            onTap: () => onVote('support'),
          ),
          const SizedBox(height: 8),
          _TelegramPollOption(
            key: ValueKey('public_request_oppose_${request.id}'),
            label: text.isKy ? 'Колдобойм' : 'Не поддерживаю',
            votes: request.opposeCount,
            percentage: opposePercent,
            selected: request.opposedByMe,
            onTap: () => onVote('oppose'),
          ),
          if (request.myVote != null) ...[
            const SizedBox(height: 8),
            Text(
              text.isKy
                  ? 'Тандалган вариантты кайра бассаңыз, добуш өчүрүлөт.'
                  : 'Нажмите выбранный вариант ещё раз, чтобы убрать голос.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TelegramPollOption extends StatelessWidget {
  const _TelegramPollOption({
    super.key,
    required this.label,
    required this.votes,
    required this.percentage,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int votes;
  final int percentage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final progress = (percentage / 100).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $percentage%, $votes',
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.09)
            : colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 21,
                      color: selected ? scheme.primary : colors.textMuted,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        color: selected ? scheme.primary : colors.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 5,
                          color: colors.border,
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: constraints.maxWidth * progress,
                          height: 5,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}''',
    "telegram poll widgets",
)

comments = root / "lib/features/public_requests/public_requests_widgets.dart"
replace_once(
    comments,
    r'''  void initState() {
    super.initState();
    request = widget.request;''',
    r'''  void initState() {
    super.initState();
    commentController.addListener(_handleCommentTextChanged);
    request = widget.request;''',
    "comment input listener init",
)
replace_once(
    comments,
    r'''  void dispose() {
    realtime.close();
    commentController.dispose();''',
    r'''  void dispose() {
    realtime.close();
    commentController.removeListener(_handleCommentTextChanged);
    commentController.dispose();''',
    "comment input listener dispose",
)
replace_once(
    comments,
    r'''  Future<List<PublicRequestComment>> loadComments() async {''',
    r'''  void _handleCommentTextChanged() {
    if (mounted) setState(() {});
  }

  bool get canSubmitComment =>
      !sending && commentController.text.trim().isNotEmpty;

  Future<List<PublicRequestComment>> loadComments() async {''',
    "comment input state",
)
replace_once(
    comments,
    r'''  void addRealtimeComment(PublicRequestComment comment) {
    if (cachedComments.any((item) => item.id == comment.id)) return;
    final updated = [...cachedComments, comment]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setComments(updated);
  }

  void removeRealtimeComment(String commentId) {
    if (commentId.isEmpty) return;
    final updated = cachedComments
        .where((comment) => comment.id != commentId)
        .toList();
    setComments(updated);
  }''',
    r'''  void addRealtimeComment(
    PublicRequestComment comment, {
    bool updateRequestCount = true,
  }) {
    if (cachedComments.any((item) => item.id == comment.id)) return;
    final updated = [...cachedComments, comment]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    setComments(updated);
    if (updateRequestCount) {
      setRequest(
        request.copyWith(
          commentCount: request.commentCount + 1,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  void removeRealtimeComment(
    String commentId, {
    bool updateRequestCount = true,
  }) {
    if (commentId.isEmpty ||
        !cachedComments.any((comment) => comment.id == commentId)) {
      return;
    }
    final updated = cachedComments
        .where((comment) => comment.id != commentId)
        .toList();
    setComments(updated);
    if (updateRequestCount) {
      setRequest(
        request.copyWith(
          commentCount: request.commentCount > 0
              ? request.commentCount - 1
              : 0,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }''',
    "realtime comment counters",
)
replace_once(
    comments,
    "      addRealtimeComment(comment);",
    "      addRealtimeComment(comment, updateRequestCount: false);",
    "local comment add count",
)
replace_once(
    comments,
    "    removeRealtimeComment(comment.id);",
    "    removeRealtimeComment(comment.id, updateRequestCount: false);",
    "local comment delete count",
)
replace_once(
    comments,
    r'''                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),''',
    r'''                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),''',
    "comment list keyboard dismissal",
)
replace_once(
    comments,
    r'''                  const SizedBox(height: 18),
                  Text(
                    text.comments,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),''',
    r'''                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.forum_outlined,
                          size: 19,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text.comments,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.page,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          '${comments.length}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),''',
    "comment section header",
)
replace_once(
    comments,
    r'''                  else if (comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Text(
                        text.isKy
                            ? 'Комментарий азырынча жок.'
                            : 'Комментариев пока нет.',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    )''',
    r'''                  else if (comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 28,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 30,
                            color: colors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            text.isKy
                                ? 'Комментарий азырынча жок.'
                                : 'Комментариев пока нет.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text.isKy
                                ? 'Биринчи болуп пикириңизди жазыңыз.'
                                : 'Напишите первый комментарий.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textMuted),
                          ),
                        ],
                      ),
                    )''',
    "empty comments state",
)
replace_once(
    comments,
    r'''      bottomNavigationBar: request.interactionMode == 'discussion'
          ? SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('comment_field'),
                        controller: commentController,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => submitComment(),
                        decoration: InputDecoration(
                          hintText: text.isKy
                              ? 'Комментарий кошуу'
                              : 'Добавить комментарий',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: sending ? null : submitComment,
                      icon: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            )
          : null,''',
    r'''      bottomNavigationBar: request.interactionMode == 'discussion'
          ? AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                top: false,
                child: Material(
                  color: colors.surface,
                  elevation: 12,
                  shadowColor: colors.shadow,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('comment_field'),
                            controller: commentController,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              if (canSubmitComment) submitComment();
                            },
                            decoration: InputDecoration(
                              hintText: text.isKy
                                  ? 'Комментарий кошуу'
                                  : 'Добавить комментарий',
                              prefixIcon:
                                  const Icon(Icons.chat_bubble_outline_rounded),
                              filled: true,
                              fillColor: colors.page,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton.filled(
                            tooltip: text.isKy ? 'Жөнөтүү' : 'Отправить',
                            onPressed:
                                canSubmitComment ? submitComment : null,
                            icon: sending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,''',
    "comment composer",
)
replace_once(
    comments,
    r'''class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });
  final PublicRequestComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KoomAvatar(
            label: comment.authorName,
            radius: 18,
            imageBytes: comment.authorAvatarBytes,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorName,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  comment.body,
                  style: TextStyle(color: colors.textStrong, height: 1.3),
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}''',
    r'''class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
  });
  final PublicRequestComment comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final authorName = comment.authorName.trim().isEmpty
        ? (text.isKy ? 'Колдонуучу' : 'Пользователь')
        : comment.authorName.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KoomAvatar(
            label: authorName,
            radius: 18,
            imageBytes: comment.authorAvatarBytes,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 9, 11),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        compactTime(comment.createdAt.toLocal()),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (canDelete)
                        PopupMenuButton<String>(
                          tooltip: text.isKy ? 'Меню' : 'Меню',
                          padding: EdgeInsets.zero,
                          iconSize: 19,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: colors.textMuted,
                          ),
                          onSelected: (value) {
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline_rounded),
                                  const SizedBox(width: 10),
                                  Text(text.isKy ? 'Өчүрүү' : 'Удалить'),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.body,
                    style: TextStyle(
                      color: colors.textStrong,
                      height: 1.38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}''',
    "comment bubble",
)

print("UI fixes applied successfully")
