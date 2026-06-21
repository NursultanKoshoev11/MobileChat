import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/public_request.dart';
import '../../data/public_requests_api.dart';
import '../../services/group_realtime_service.dart';
import '../../shared/ui_helpers.dart';
import '../groups/group_sheets.dart';
import '../statistics/group_statistics_screen.dart';
import 'moderation_screen.dart';
import 'public_request_media_screens.dart';
import 'public_request_media_widgets.dart';
import 'public_requests_widgets.dart';

class PublicRequestsScreen extends StatefulWidget {
  const PublicRequestsScreen({
    super.key,
    required this.api,
    required this.user,
    required this.group,
  });

  final ApiClient api;
  final UserProfile user;
  final ChatGroup group;

  @override
  State<PublicRequestsScreen> createState() => _PublicRequestsScreenState();
}

class _PublicRequestsScreenState extends State<PublicRequestsScreen> {
  late final PublicRequestsApi requestsApi;
  late final GroupRealtimeService realtime;
  late Future<List<PublicRequest>> requestsFuture;
  late Future<int> moderationCountFuture;
  Timer? _refreshDebounce;
  String? ensuredInviteCode;

  bool get canModerate =>
      widget.group.myRole == 'owner' || widget.group.myRole == 'admin';
  bool get canInvite => widget.group.canInvite;
  bool get canChangeRoles => widget.group.ownerId == widget.user.id;
  bool get canMuteComments => canModerate;

  @override
  void initState() {
    super.initState();
    requestsApi = PublicRequestsApi(
      baseUrl: widget.api.baseUrl,
      sessionStore: widget.api.sessionStore,
    );
    realtime = GroupRealtimeService(api: widget.api, groupId: widget.group.id);
    requestsFuture = loadRequests();
    moderationCountFuture = loadModerationCount();
    realtime.connect(onEvent: _handleRealtimeEvent);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    realtime.close();
    super.dispose();
  }

  void _handleRealtimeEvent(GroupRealtimeEvent event) {
    if (!mounted || event.groupId != widget.group.id) return;
    if (event.type.startsWith('public_request.') ||
        event.type.startsWith('content_moderation.')) {
      _scheduleRealtimeRefresh();
    }
  }

  void _scheduleRealtimeRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) refresh(silent: true);
    });
  }

  Future<List<PublicRequest>> loadRequests() async {
    final requests = await requestsApi.listRequests(widget.group.id);
    return List<PublicRequest>.from(requests)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<int> loadModerationCount() async {
    if (!canModerate) return 0;
    try {
      return await requestsApi.countModerationItems(widget.group.id);
    } catch (_) {
      return 0;
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final next = loadRequests();
    final nextModerationCount = loadModerationCount();
    if (mounted) {
      setState(() {
        requestsFuture = next;
        moderationCountFuture = nextModerationCount;
      });
    }
    await Future.wait([next, nextModerationCount]);
  }

  Future<void> openStatistics() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupStatisticsScreen(api: requestsApi, group: widget.group),
      ),
    );
    await refresh();
  }

  Future<void> createRequest() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => CreatePublicRequestMediaSheet(
        api: requestsApi,
        groupId: widget.group.id,
      ),
    );
    if (created == true) {
      await refresh();
      if (mounted) {
        showAppSnack(context, AppLanguageScope.textOf(context).postPublished);
      }
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
    } catch (error) {
      if (mounted) showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }

  Future<void> updateStatus(PublicRequest request, String status) async {
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

  Future<void> openDetails(PublicRequest request) async {
    if (request.interactionMode != 'discussion') return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicRequestDetailsScreen(
          api: requestsApi,
          request: request,
          canModerate: canModerate,
          currentUserId: widget.user.id,
          onStatusChanged:
              canModerate ? (status) => updateStatus(request, status) : null,
        ),
      ),
    );
    await refresh();
  }

  Future<void> openModerationQueue() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GroupModerationScreen(
          api: requestsApi,
          group: widget.group,
        ),
      ),
    );
    await refresh();
  }

  String get groupAccessCode =>
      formatGroupInviteCode(ensuredInviteCode ?? widget.group.inviteCode ?? '');

  Future<void> showGroupAccess() async {
    var code = groupAccessCode;
    if (code.isEmpty) {
      try {
        final group = await requestsApi.ensureGroupInviteCode(widget.group.id);
        if (!mounted) return;
        setState(() => ensuredInviteCode = group.inviteCode);
        code = formatGroupInviteCode(group.inviteCode ?? '');
      } catch (error) {
        if (mounted) showAppSnack(context, localizedMessage(context, error.toString()));
        return;
      }
    }
    if (code.isEmpty) {
      final text = AppLanguageScope.textOf(context);
      showAppSnack(
        context,
        text.isKy
            ? 'Топтун чакыруу коду азырынча түзүлгөн эмес.'
            : 'Код приглашения группы пока не создан.',
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => GroupAccessSheet(groupTitle: widget.group.title, code: code),
    );
  }

  Future<void> inviteByPhone() async {
    if (!canInvite) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (_) => InviteByPhoneSheet(api: widget.api, group: widget.group),
    );
  }

  Future<void> changeRoleByPhone() async {
    if (!canChangeRoles) return;
    final text = AppLanguageScope.textOf(context);
    final phoneController = TextEditingController(text: '+996');
    var loading = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> changeRole(String role) async {
            final phone = phoneController.text.trim();
            if (phone.isEmpty || loading) return;
            setSheetState(() => loading = true);
            try {
              await requestsApi.updateGroupMemberRoleByPhone(
                groupId: widget.group.id,
                phone: phone,
                role: role,
              );
              if (!context.mounted) return;
              Navigator.pop(sheetContext);
              showAppSnack(context, role == 'admin' ? text.adminAssigned : text.adminRemoved);
            } catch (error) {
              if (context.mounted) {
                showAppSnack(context, localizedMessage(context, error.toString()));
              }
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text.manageAdmins,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(text.manageAdminsDescription),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: text.mobileNumber,
                    hintText: '+996700123456',
                    prefixIcon: const Icon(Icons.phone_iphone_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: loading ? null : () => changeRole('admin'),
                  icon: const Icon(Icons.admin_panel_settings_rounded),
                  label: Text(loading ? text.pleaseWait : text.makeAdmin),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: loading ? null : () => changeRole('member'),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text(text.removeAdmin),
                ),
              ],
            ),
          );
        },
      ),
    );
    phoneController.dispose();
  }

  Future<void> muteCommentsByPhone() async {
    if (!canMuteComments) return;
    final rootContext = context;
    final text = AppLanguageScope.textOf(context);
    final reasonController = TextEditingController();
    final membersFuture = requestsApi.listGroupMembers(widget.group.id);
    var durationMinutes = 60;
    var loading = false;
    String? selectedUserId;
    String? errorText;
    String? successText;

    String durationLabel(int minutes) {
      switch (minutes) {
        case 60:
          return text.oneHour;
        case 180:
          return text.threeHours;
        case 360:
          return text.sixHours;
        case 720:
          return text.twelveHours;
        case 1440:
          return text.oneDay;
        case 10080:
          return text.sevenDays;
        case 43200:
          return text.thirtyDays;
        case 0:
          return text.forever;
        default:
          return '$minutes min';
      }
    }

    bool canSelectMember(GroupMember member) {
      if (member.userId == widget.user.id) return false;
      if (member.role == 'owner') return false;
      if (widget.group.ownerId == widget.user.id) return true;
      return member.role == 'member';
    }

    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(rootContext).cardColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void showResult({String? error, String? success}) {
            setSheetState(() {
              errorText = error;
              successText = success;
            });
            if (rootContext.mounted) {
              showAppSnack(rootContext, error ?? success ?? '');
            }
          }

          Future<void> mute() async {
            final userId = selectedUserId;
            if (userId == null || userId.isEmpty || loading) return;
            setSheetState(() {
              loading = true;
              errorText = null;
              successText = null;
            });
            try {
              await requestsApi.setCommentMute(
                groupId: widget.group.id,
                userId: userId,
                durationMinutes: durationMinutes,
                reason: reasonController.text.trim(),
              );
              showResult(success: text.mutedDone);
            } catch (error) {
              showResult(error: localizedMessage(rootContext, error.toString()));
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          Future<void> unmute() async {
            final userId = selectedUserId;
            if (userId == null || userId.isEmpty || loading) return;
            setSheetState(() {
              loading = true;
              errorText = null;
              successText = null;
            });
            try {
              await requestsApi.clearCommentMute(groupId: widget.group.id, userId: userId);
              showResult(success: text.unmutedDone);
            } catch (error) {
              showResult(error: localizedMessage(rootContext, error.toString()));
            } finally {
              if (context.mounted) setSheetState(() => loading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 22,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.blockComments,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(text.blockCommentsDescription),
                  const SizedBox(height: 14),
                  FutureBuilder<List<GroupMember>>(
                    future: membersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final members = (snapshot.data ?? const <GroupMember>[])
                          .where(canSelectMember)
                          .toList();
                      if (members.isEmpty) {
                        return Text(
                          text.isKy
                              ? 'Бөгөттөй турган катышуучу жок.'
                              : 'Нет участников, которых можно заблокировать.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      }
                      selectedUserId ??= members.first.userId;
                      return DropdownButtonFormField<String>(
                        value: selectedUserId,
                        decoration: InputDecoration(
                          labelText: text.mobileNumber,
                          prefixIcon: const Icon(Icons.people_outline_rounded),
                        ),
                        items: members
                            .map(
                              (member) => DropdownMenuItem<String>(
                                value: member.userId,
                                child: Text('${member.displayName} · ${member.phone ?? ''} · ${member.role}'),
                              ),
                            )
                            .toList(),
                        onChanged: loading ? null : (value) => setSheetState(() => selectedUserId = value),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: durationMinutes,
                    decoration: InputDecoration(
                      labelText: text.blockDuration,
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                    items: const [60, 180, 360, 720, 1440, 10080, 43200, 0]
                        .map(
                          (minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text(durationLabel(minutes)),
                          ),
                        )
                        .toList(),
                    onChanged: loading ? null : (value) => setSheetState(() => durationMinutes = value ?? 60),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: text.blockReason,
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (successText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      successText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: loading || selectedUserId == null ? null : mute,
                    icon: const Icon(Icons.block_rounded),
                    label: Text(loading ? text.pleaseWait : text.blockCommentsButton),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: loading || selectedUserId == null ? null : unmute,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(text.unblockCommentsButton),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    reasonController.dispose();
  }

  PopupMenuItem<String> groupMenuItem({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ]),
    );
  }

  Future<void> handleGroupMenuAction(String value) async {
    switch (value) {
      case 'statistics':
        await openStatistics();
        break;
      case 'access':
        await showGroupAccess();
        break;
      case 'admins':
        await changeRoleByPhone();
        break;
      case 'mute':
        await muteCommentsByPhone();
        break;
      case 'invite':
        await inviteByPhone();
        break;
      case 'moderation':
        await openModerationQueue();
        break;
      case 'settings':
        if (mounted) await showAppSettingsSheet(context);
        break;
    }
  }

  Widget groupMenuButton(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return FutureBuilder<int>(
      future: moderationCountFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final reviewLabel = count > 0
            ? (text.isKy
                ? 'Текшерүүдөгү материалдар ($count)'
                : 'Материалы на проверке ($count)')
            : (text.isKy ? 'Текшерүүдөгү материалдар' : 'Материалы на проверке');
        return PopupMenuButton<String>(
          tooltip: text.isKy ? 'Меню' : 'Меню',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            handleGroupMenuAction(value);
          },
          itemBuilder: (_) => [
            groupMenuItem(
              value: 'statistics',
              icon: Icons.analytics_outlined,
              label: text.statistics,
            ),
            groupMenuItem(
              value: 'access',
              icon: Icons.qr_code_rounded,
              label: text.codeAndQr,
            ),
            if (canChangeRoles)
              groupMenuItem(
                value: 'admins',
                icon: Icons.admin_panel_settings_outlined,
                label: text.manageAdmins,
              ),
            if (canMuteComments)
              groupMenuItem(
                value: 'mute',
                icon: Icons.block_rounded,
                label: text.blockComments,
              ),
            if (canInvite)
              groupMenuItem(
                value: 'invite',
                icon: Icons.person_add_alt_1_rounded,
                label: text.inviteByPhone,
              ),
            if (canModerate)
              groupMenuItem(
                value: 'moderation',
                icon: Icons.fact_check_outlined,
                label: reviewLabel,
              ),
            groupMenuItem(
              value: 'settings',
              icon: Icons.settings_rounded,
              label: text.settings,
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.title),
        actions: [
          groupMenuButton(context),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createRequest,
        icon: const Icon(Icons.add_rounded),
        label: Text(text.newPost),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<PublicRequest>>(
          future: requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [ErrorBanner(message: snapshot.error.toString())],
              );
            }
            final requests = snapshot.data ?? const <PublicRequest>[];
            if (requests.isEmpty) return EmptyPostsView(onCreate: createRequest);
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: requests.length,
              itemBuilder: (_, index) {
                final request = requests[index];
                return MediaPublicRequestCard(
                  request: request,
                  canModerate: canModerate,
                  onVote: (voteType) => vote(request, voteType),
                  onTap: () => openDetails(request),
                  onStatus: (status) => updateStatus(request, status),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
