import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'models.dart';

class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.groupId, required this.payload, this.message});

  final String type;
  final String groupId;
  final Map<String, dynamic> payload;
  final ChatMessage? message;

  String get requestId => payload['request_id'] as String? ?? '';

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map<String, dynamic> ? rawPayload : <String, dynamic>{};
    ChatMessage? message;
    if (json['type'] == 'message.created' && rawPayload is Map<String, dynamic>) {
      message = ChatMessage.fromJson(rawPayload);
    }
    return RealtimeEvent(
      type: json['type'] as String? ?? 'unknown',
      groupId: json['group_id'] as String? ?? '',
      payload: payload,
      message: message,
    );
  }
}

class RealtimeClient {
  RealtimeClient({required this.api});

  final ApiClient api;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  Future<void> connectToGroup(String groupId) async {
    await disconnect();

    final wsToken = await api.issueWebSocketToken();
    if (wsToken.isEmpty) return;

    final apiUri = Uri.parse(api.baseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = apiUri.replace(
      scheme: scheme,
      path: '/api/groups/$groupId/ws',
      queryParameters: {'token': wsToken},
    );

    _channel = WebSocketChannel.connect(wsUri);
    _subscription = _channel!.stream.listen(
      (raw) {
        try {
          final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(RealtimeEvent.fromJson(decoded));
        } catch (_) {
          // Ignore malformed realtime events.
        }
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}
