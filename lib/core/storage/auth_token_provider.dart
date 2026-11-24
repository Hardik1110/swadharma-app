import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_storage.dart';

/// The current bearer token (null when signed out). Single source of truth
/// for the HTTP client and the realtime socket.
final authTokenProvider =
    NotifierProvider<AuthTokenNotifier, String?>(AuthTokenNotifier.new);

class AuthTokenNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(sessionStorageProvider).token;

  Future<void> set(String token) async {
    await ref.read(sessionStorageProvider).saveToken(token);
    state = token;
  }

  Future<void> clear() async {
    await ref.read(sessionStorageProvider).clear();
    state = null;
  }
}
