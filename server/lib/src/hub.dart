import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Registry of live WebSocket connections, keyed by consumer and astrologer.
class Hub {
  final _users = <String, Set<WebSocketChannel>>{};
  final _astrologers = <String, Set<WebSocketChannel>>{};

  void addUser(String userId, WebSocketChannel ch) =>
      _users.putIfAbsent(userId, () => {}).add(ch);

  /// Returns true when this was the user's last connection.
  bool removeUser(String userId, WebSocketChannel ch) {
    final set = _users[userId];
    set?.remove(ch);
    if (set == null || set.isEmpty) {
      _users.remove(userId);
      return true;
    }
    return false;
  }

  bool isUserConnected(String userId) => _users[userId]?.isNotEmpty ?? false;

  void addAstrologer(String id, WebSocketChannel ch) =>
      _astrologers.putIfAbsent(id, () => {}).add(ch);

  bool removeAstrologer(String id, WebSocketChannel ch) {
    final set = _astrologers[id];
    set?.remove(ch);
    if (set == null || set.isEmpty) {
      _astrologers.remove(id);
      return true;
    }
    return false;
  }

  /// A human is driving this astrologer from the web console.
  bool hasConsole(String astrologerId) =>
      _astrologers[astrologerId]?.isNotEmpty ?? false;

  void toUser(String userId, String type, Object? data) =>
      _send(_users[userId], type, data);

  void toAstrologer(String astrologerId, String type, Object? data) =>
      _send(_astrologers[astrologerId], type, data);

  void broadcast(String type, Object? data) {
    for (final set in [..._users.values, ..._astrologers.values]) {
      _send(set, type, data);
    }
  }

  static void send(WebSocketChannel ch, String type, Object? data) =>
      ch.sink.add(jsonEncode({'type': type, 'data': data}));

  void _send(Set<WebSocketChannel>? set, String type, Object? data) {
    if (set == null) return;
    final payload = jsonEncode({'type': type, 'data': data});
    for (final ch in set) {
      ch.sink.add(payload);
    }
  }
}
