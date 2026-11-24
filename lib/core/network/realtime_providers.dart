import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/auth_token_provider.dart';
import 'socket_client.dart';

/// App-wide realtime connection; connects whenever a token is present.
final socketClientProvider = Provider<SocketClient>((ref) {
  final client = SocketClient();
  ref.onDispose(client.dispose);
  ref.listen<String?>(authTokenProvider, (_, token) {
    if (token == null) {
      client.disconnect();
    } else {
      client.connect(Env.webSocketUri(token));
    }
  }, fireImmediately: true);
  return client;
});

final socketStatusProvider =
    NotifierProvider<SocketStatusNotifier, SocketStatus>(SocketStatusNotifier.new);

class SocketStatusNotifier extends Notifier<SocketStatus> {
  @override
  SocketStatus build() {
    final ValueListenable<SocketStatus> status =
        ref.watch(socketClientProvider).status;
    void listener() => state = status.value;
    status.addListener(listener);
    ref.onDispose(() => status.removeListener(listener));
    return status.value;
  }
}
