import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wraps the /ws live-notification feed. ApiFileSystemRepository listens
/// to [events] to know when to re-fetch watchFolder()/watchDeletedItems()
/// streams — there's no Firestore-style native snapshot listener on this
/// provider, so this is what replaces it.
class ApiWebSocketClient {
  ApiWebSocketClient({
    required String baseUrl,
    required Future<String?> Function() getIdToken,
  }) : _baseUrl = baseUrl,
       _getIdToken = getIdToken;

  final String _baseUrl;
  final Future<String?> Function() _getIdToken;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  bool _disposed = false;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<void> connect() async {
    if (_channel != null || _disposed) return;
    final token = await _getIdToken();
    final wsBase = _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$wsBase/ws?token=$token'));
    _sub = _channel!.stream.listen(
      (raw) {
        try {
          _eventController.add(
            jsonDecode(raw as String) as Map<String, dynamic>,
          );
        } catch (_) {
          // malformed frame — ignore, don't take the socket down over it
        }
      },
      onDone: _reconnectAfterDelay,
      onError: (_) => _reconnectAfterDelay(),
    );
  }

  void _reconnectAfterDelay() {
    _channel = null;
    _sub?.cancel();
    if (_disposed) return;
    Future.delayed(const Duration(seconds: 3), connect);
  }

  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
