import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/realtime_providers.dart';
import '../../../../core/network/socket_client.dart';
import '../../../../core/storage/auth_token_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet.dart';

/// The signed-in user's wallet. The balance follows `wallet.updated` pushes
/// from the server, so it is live during a consultation.
final walletProvider =
    AsyncNotifierProvider<WalletNotifier, Wallet>(WalletNotifier.new);

class WalletNotifier extends AsyncNotifier<Wallet> {
  Timer? _refetch;

  @override
  Future<Wallet> build() async {
    final token = ref.watch(authTokenProvider);
    // Astrologers earn instead of spend: they have no wallet.
    final astrologer = ref.watch(authProvider.select((u) => u.value?.isAstrologer ?? false));
    if (token == null || astrologer) return Wallet.empty;

    final socket = ref.watch(socketClientProvider);
    final sub = socket.events.listen((e) {
      if (e.type != 'wallet.updated') return;
      final balance = (e.data['balance'] as num?)?.toInt();
      final current = state.value;
      if (balance != null && current != null) {
        state = AsyncData(current.copyWith(balance: balance));
      }
      // Pick up the new ledger entry shortly after (debounced: a busy
      // session can push one update per minute).
      _refetch?.cancel();
      _refetch = Timer(const Duration(milliseconds: 600), _silentRefresh);
    });
    ref.listen(socketStatusProvider, (prev, next) {
      if (next == SocketStatus.connected && prev != SocketStatus.connected) {
        _silentRefresh();
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _refetch?.cancel();
    });

    return ref.read(walletRepositoryProvider).load();
  }

  Future<void> refresh() async {
    final wallet = await ref.read(walletRepositoryProvider).load();
    if (ref.mounted) state = AsyncData(wallet);
  }

  Future<void> _silentRefresh() async {
    try {
      await refresh();
    } catch (_) {
      // Keep showing what we have; the next push or reconnect retries.
    }
  }

  /// Throws [AppException] on validation or network errors.
  Future<void> topUp(int amount) async {
    final wallet = await ref.read(walletRepositoryProvider).topUp(amount);
    if (ref.mounted) state = AsyncData(wallet);
  }
}
