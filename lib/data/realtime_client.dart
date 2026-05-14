import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'models.dart';
import 'session_store.dart';

class RealtimeEvent {
  const RealtimeEvent({required this.type, required this.groupId, this.message});

  final String type;
  final String groupId;
  final ChatMessage? message;

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    ChatMessage? message;
    if (json['type'] == 'message.created' && json['payload'] is Map<String, dynamic>) {
      message = ChatMessage.fromJson(json['payload'] as Map<String, dynamic>);
    }
    return RealtimeEvent(
      type: json['type'] as String? ?? 'unknown',
      groupId: json['group_id'] as String? ?? '',
      message: message,
    );
  }
}

class RealtimeClient {
  RealtimeClient({required this.baseUrl, required this.sessionStore});

  final String baseUrl;
  final SessionStore sessionStore;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  Future<void> connectToGroup(String groupId) async {
    await disconnect();
    final session = await sessionStore.read();
    if (session == null) return;

    final apiUri = Uri.parse(baseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = apiUri.replace(
      scheme: scheme,
      path: '/api/groups/$groupId/ws',
      queryParameters: {'token': session.accessToken},
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
