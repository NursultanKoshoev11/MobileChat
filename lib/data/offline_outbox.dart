import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class OfflinePublicRequestDraft {
  const OfflinePublicRequestDraft({
    required this.id,
    required this.groupId,
    required this.requestType,
    required this.interactionMode,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String requestType;
  final String interactionMode;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'request_type': requestType,
        'interaction_mode': interactionMode,
        'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };

  factory OfflinePublicRequestDraft.fromJson(Map<dynamic, dynamic> json) {
    return OfflinePublicRequestDraft(
      id: json['id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      requestType: json['request_type'] as String? ?? '',
      interactionMode: json['interaction_mode'] as String? ?? 'discussion',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class OfflineOutbox {
  OfflineOutbox._();
  static final OfflineOutbox instance = OfflineOutbox._();
  static const _boxName = 'offline_public_request_outbox';
  bool _initialized = false;

  Future<Box> _box() async {
    if (!_initialized) {
      final dir = await getApplicationSupportDirectory();
      Hive.init(dir.path);
      _initialized = true;
    }
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  Future<void> enqueuePublicRequest(OfflinePublicRequestDraft draft) async {
    final box = await _box();
    await box.put(draft.id, draft.toJson());
  }

  Future<void> flushPublicRequests(Future<void> Function(OfflinePublicRequestDraft draft) sender) async {
    final box = await _box();
    final keys = box.keys.toList(growable: false);
    for (final key in keys) {
      final raw = box.get(key);
      if (raw is! Map) {
        await box.delete(key);
        continue;
      }
      final draft = OfflinePublicRequestDraft.fromJson(raw);
      await sender(draft);
      await box.delete(key);
    }
  }
}
