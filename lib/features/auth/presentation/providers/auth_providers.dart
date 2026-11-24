import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/auth_token_provider.dart';
import '../../data/auth_repository_impl.dart';
import '../../domain/user.dart';

/// Current session. Loading = restoring at startup; data(null) = signed out.
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final repo = ref.read(authRepositoryProvider);
    final cached = repo.cachedUser();
    if (cached == null) return null;
    // Refresh in the background once build has completed; the cached copy
    // lets the app start offline.
    Future(_refresh);
    return cached;
  }

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    try {
      final user = await ref.read(authRepositoryProvider).fetchMe();
      if (ref.mounted && state.value != null) state = AsyncData(user);
    } on AppException catch (e) {
      if (ref.mounted && e.isUnauthorized) await sessionExpired();
    }
  }

  void setUser(User user) => state = AsyncData(user);

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  /// Token rejected by the server: drop the local session.
  Future<void> sessionExpired() async {
    if (state.value == null) return;
    await ref.read(authTokenProvider.notifier).clear();
    state = const AsyncData(null);
  }
}
