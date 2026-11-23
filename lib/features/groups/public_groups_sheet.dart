import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

class PublicGroupsSheet extends StatefulWidget {
  const PublicGroupsSheet({
    super.key,
    required this.api,
    required this.joinedGroups,
  });

  final ApiClient api;
  final List<ChatGroup> joinedGroups;

  @override
  State<PublicGroupsSheet> createState() => _PublicGroupsSheetState();
}

class _PublicGroupsSheetState extends State<PublicGroupsSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<ChatGroup> _groups = const <ChatGroup>[];
  final Set<String> _joiningGroupIds = <String>{};
  Object? _error;
  bool _loading = true;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_scheduleSearch);
    unawaited(_search());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_scheduleSearch)
      ..dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_search());
    });
  }

  Future<void> _search() async {
    final generation = ++_requestGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final groups = await widget.api.searchPublicGroups(
        _searchController.text.trim(),
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _groups = groups;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openOrJoin(ChatGroup group) async {
    ChatGroup? existing;
    for (final item in widget.joinedGroups) {
      if (item.id == group.id) {
        existing = item;
        break;
      }
    }
    if (existing != null) {
      Navigator.of(context).pop(existing);
      return;
    }

    if (!_joiningGroupIds.add(group.id)) return;
    setState(() {});
    try {
      await widget.api.joinPublicGroup(group.id);
      final joinedGroups = await widget.api.fetchGroups();
      ChatGroup? joined;
      for (final item in joinedGroups) {
        if (item.id == group.id) {
          joined = item;
          break;
        }
      }
      if (joined == null) {
        throw StateError('Группа не появилась в списке после вступления.');
      }
      if (mounted) Navigator.of(context).pop(joined);
    } catch (error) {
      if (mounted) showAppSnack(context, error.toString());
    } finally {
      _joiningGroupIds.remove(group.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final joinedIds = widget.joinedGroups.map((group) => group.id).toSet();

    return SafeArea(
      top: false,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.isKy ? 'Ачык топтор' : 'Открытые группы',
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      text.isKy
                          ? 'Коомчулукту таап, кошулуңуз.'
                          : 'Найдите сообщество и вступите в него.',
                      style: TextStyle(color: colors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: text.isKy ? 'Топту издөө' : 'Поиск групп',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: text.isKy ? 'Тазалоо' : 'Очистить',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildResults(text.isKy, colors, joinedIds)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(bool isKy, KoomColors colors, Set<String> joinedIds) {
    if (_loading && _groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 36, color: colors.textMuted),
              const SizedBox(height: 10),
              Text(
                isKy
                    ? 'Топторду жүктөө мүмкүн болгон жок.'
                    : 'Не удалось загрузить группы.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textStrong),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => unawaited(_search()),
                child: Text(isKy ? 'Кайра аракет кылуу' : 'Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (_groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isKy ? 'Ачык топтор табылган жок.' : 'Открытые группы не найдены.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: _groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final group = _groups[index];
            final joined = joinedIds.contains(group.id);
            final joining = _joiningGroupIds.contains(group.id);
            return KoomCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              showShadow: false,
              child: Row(
                children: [
                  KoomAvatar(
                    label: group.title,
                    radius: 23,
                    imageBytes: group.avatarBytes,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (group.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            group.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          isKy
                              ? '${group.memberCount} мүчө'
                              : '${group.memberCount} участников',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: joining ? null : () => _openOrJoin(group),
                    child: joining
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            joined
                                ? (isKy ? 'Ачуу' : 'Открыть')
                                : (isKy ? 'Кошулуу' : 'Вступить'),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_loading && _groups.isNotEmpty)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}
