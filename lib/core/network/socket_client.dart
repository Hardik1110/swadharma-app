import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketStatus { disconnected, connecting, connected }

class SocketEvent {
  const SocketEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;
}

typedef ChannelFactory = WebSocketChannel Function(Uri uri);

/// Long-lived WebSocket with automatic reconnect (exponential backoff),
/// heartbeat and a broadcast stream of decoded events.
class SocketClient {
  SocketClient({ChannelFactory? channelFactory})
      : _factory = channelFactory ?? WebSocketChannel.connect;

  final ChannelFactory _factory;
  final _events = StreamController<SocketEvent>.broadcast();
  final status = ValueNotifier(SocketStatus.disconnected);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _heartbeat;
  Uri? _uri;
  int _attempt = 0;
  bool _disposed = false;

  Stream<SocketEvent> get events => _events.stream;
  bool get isConnected => status.value == SocketStatus.connected;

  /// Connects (or reconnects) to [uri]. No-op if already using it.
  void connect(Uri uri) {
    if (_uri == uri && status.value != SocketStatus.disconnected) return;
    _uri = uri;
    _attempt = 0;
    _open();
  }

  void disconnect() {
    _uri = null;
    _close();
    status.value = SocketStatus.disconnected;
  }

  /// Returns false when not connected; callers can fall back to REST.
  bool send(String type, Map<String, dynamic> data) {
    final ch = _channel;
    if (ch == null || !isConnected) return false;
    ch.sink.add(jsonEncode({'type': type, 'data': data}));
    return true;
  }

  Future<void> _open() async {
    final uri = _uri;
    if (uri == null || _disposed) return;
    _close();
    status.value = SocketStatus.connecting;
    final ch = _factory(uri);
    _channel = ch;
    try {
      await ch.ready;
    } catch (e) {
      debugPrint('socket connect failed: $e');
      if (_channel == ch) _scheduleReconnect();
      return;
    }
    if (_channel != ch) return; // superseded
    _attempt = 0;
    status.value = SocketStatus.connected;
    _sub = ch.stream.listen(
      _onData,
      onDone: () => _onClosed(ch),
      onError: (_) => _onClosed(ch),
      cancelOnError: true,
    );
    _heartbeat = Timer.periodic(
        const Duration(seconds: 25), (_) => send('ping', const {}));
  }

  void _onData(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final data = msg['data'];
      _events.add(SocketEvent(
        msg['type'] as String,
        data is Map<String, dynamic> ? data : const {},
      ));
    } catch (e) {
      debugPrint('bad socket message: $e');
    }
  }

  void _onClosed(WebSocketChannel ch) {
    if (_channel != ch) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _close();
    if (_uri == null || _disposed) {
      status.value = SocketStatus.disconnected;
      return;
    }
    status.value = SocketStatus.connecting;
    final delay = Duration(
        milliseconds: min(15000, 500 * pow(2, _attempt++).toInt()) +
            Random().nextInt(400));
    _reconnectTimer = Timer(delay, _open);
  }

  void _close() {
    _reconnectTimer?.cancel();
    _heartbeat?.cancel();
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Injects an event as if it came from the server (tests only).
  @visibleForTesting
  void debugEmit(SocketEvent event) => _events.add(event);

  void dispose() {
    _disposed = true;
    _uri = null;
    _close();
    _events.close();
    status.dispose();
  }
}
